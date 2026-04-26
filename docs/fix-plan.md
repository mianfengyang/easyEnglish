# EasyEnglish 修复方案文档

> 生成日期：2026-04-24
> 覆盖范围：线程安全、代码去重、数据安全（SQL注入 + 备份恢复）、错误处理

---

## 目录

1. [线程安全](#1-线程安全)
2. [代码去重与算法统一](#2-代码去重与算法统一)
3. [数据安全（SQL注入 + 备份恢复）](#3-数据安全sql注入--备份恢复)
4. [错误处理与用户体验](#4-错误处理与用户体验)

---

## 1. 线程安全

### 问题概述

`DatabaseManager` 使用 `@unchecked Sendable` 手动绕过 Swift 并发检查，虽然部分方法加了 `NSLock`，但很多关键路径没有保护。

### 影响范围

| 文件 | 行号 | 问题 |
|------|------|------|
| `Core/Database/DatabaseManager.swift` | 4-56 | `@unchecked Sendable`, 部分方法未加锁 |
| `Core/Database/WordRepository.swift` | 11-280 | 所有异步方法通过 `db.connection` 获取连接，但 connection getter 的锁与调用方不匹配 |

### 具体风险

1. **`switchToDatabase()`** — 无锁保护，并发调用可能导致 db 引用被覆盖
2. **`resetConnection()`** — 无锁保护，可能在另一个线程读取 connection 时将其置为 nil
3. **`connection` getter** — 虽然有锁，但调用方（如 `getReviewWords`）在获取 connection 后不再加锁，后续操作无保护

### 修复方案：使用 `actor` 封装数据库层

将 `DatabaseManager` 改造为 Swift actor，利用语言级别的并发安全保证：

```swift
// 修改前 (DatabaseManager.swift)
final class DatabaseManager: @unchecked Sendable {
    private var db: Connection?
    // ... 手动加锁，部分方法漏了

// 修改后 (DatabaseActor.swift)
actor DatabaseManager {
    private var db: Connection?

    func connection() -> Connection? { ... }  // actor隔离，天然线程安全
    func switchToDatabase(at path: String, readonly: Bool) throws { ... }  // actor隔离
    func initializeIfNeeded() throws { ... }   // actor隔离

    var path: String { dbPath }  // 只读属性，无并发问题
}

// WordRepository 调用方式不变（因为 actor 的异步方法通过 await 调用）
```

**涉及文件修改：**

| 文件 | 改动说明 |
|------|---------|
| `DatabaseManager.swift` | class → actor，移除所有手动加锁代码 |
| 所有调用 `DatabaseManager.shared` 的地方 | 在异步方法前加 `await`（actor 调用自动变为异步） |

**工作量评估：** 中等。需要修改 `WordRepository` 中约 15 处对 `db.connection` 的调用，加上 `await`。

---

## 2. 代码去重与算法统一

### 问题概述

SM-2 间隔重复算法在两个文件中分别实现，且细节不一致。

### 差异对比

| 场景 | SM2Algorithm.swift (正确) | WordRepository.updateLearningStatus (不一致!) |
|------|--------------------------|---------------------------------------------|
| 第1次复习间隔 | 1天 (`case 1: newInterval = firstInterval`) | 1小时/1天（`calculateNextReviewDate`）|
| 第2次复习间隔 | 6天 (`case 2: newInterval = secondInterval`) | **3天**（`case 2: newInterval = 3`）|
| EF 更新公式 | `max(minEF, currentEF + delta)` (标准SM-2) | 简化版：`max(1.3, currentEF + (isCorrect ? 0.1 : -0.2))` |

**第2次复习间隔不一致是最严重的问题** — 同一个单词在两个模块学习，复习周期会不同。

### 修复方案：统一到 `SM2Algorithm`

```swift
// WordRepository.updateLearningStatus() 修改前（第63-75行）
let isCorrect = quality >= 3
var newInterval: Int64 = 0
if isCorrect {
    switch newReps {
    case 1: newInterval = 1
    case 2: newInterval = 3   // ← 与 SM2Algorithm 不一致！
    default: ...
    }
} else { newInterval = 1 }

let newEf = max(1.3, currentEF + (isCorrect ? 0.1 : -0.2))

// 修改后
let result = SM2Algorithm.shared.calculate(
    reps: Int(currentReps),
    interval: Int(currentInterval),
    ef: currentEf,
    quality: quality
)

let newReps = Int64(result.reps)
let newInterval = Int64(result.interval)
let nextReviewDate = result.nextReviewDate ?? Date()

// 删除 calculateNextReviewDate() 方法（第273-281行），SM2Algorithm 已处理日期计算
```

**涉及文件修改：**

| 文件 | 改动说明 |
|------|---------|
| `WordRepository.swift` | `updateLearningStatus()` 改用 `SM2Algorithm.shared.calculate()`, 删除 `calculateNextReviewDate()` |
| `LearningViewModel.swift` | `review()` 方法中手动更新 sessionWords 的 interval/ef/reps 字段，需同步使用 `SM2Algorithm` |
| `SpellingViewModel.swift` | 同上，review 后更新数据库的 interval/ef/reps 字段需同步 |

**注意：** `LearningViewModel.review()` 和 `SpellingViewModel` 中在收到数据库更新后，需要手动刷新 sessionWords 的 SRS 字段。这部分逻辑也需要统一使用 `SM2Algorithm` 重新计算，保证 UI 显示与数据库一致。

---

## 3. 数据安全（SQL注入 + 备份恢复）

### 3.1 SQL 注入问题

#### 影响范围

| 文件 | 行号 | 注入点 |
|------|------|--------|
| `WordRepository.swift` | 13, 24 | `LIMIT \(count)` — count 来自用户设置，理论上可控但模式危险 |
| `WordRepository.swift` | 117-128 | `learned_at >= \(startOfDay.timeIntervalSinceReferenceDate)` — 时间戳直接拼接 |
| `WordRepository.swift` | 165-174 | `last_reviewed_at >= \(startDate.timeIntervalSinceReferenceDate)` — 同上 |

#### 修复方案：使用 SQLite.swift 参数化查询

```swift
// getNewWords() — 修改前（第13行）
let sql = "SELECT * FROM words WHERE is_learned IS NULL OR is_learned = 0 ORDER BY RANDOM() LIMIT \(count)"

// getNewWords() — 修改后
let query = db.words
    .filter(db.isLearned == nil || db.isLearned == false)
    .order(db.id)  // RANDOM() 性能差，改用其他方式（见下方优化）
    .limit(count)

// getDailyStats() — 修改前（第117行）
let newSql = "SELECT COUNT(*) FROM words WHERE is_learned = 1 AND learned_at >= \(startOfDay.timeIntervalSinceReferenceDate) ..."

// getDailyStats() — 修改后
let start = DateComponents(calendar: Calendar.current, year: Calendar.current.component(.year, from: startOfDay),
                           month: Calendar.current.component(.month, from: startOfDay),
                           day: Calendar.current.component(.day, from: startOfDay))
let query = db.words.filter(
    db.isLearned == true &&
    (db.learnedAt >= startOfDay)  // SQLite.swift 支持 Date 比较
).count

// getWeeklyTrend() — 同理修改（第165-174行）
```

**额外优化建议：** `ORDER BY RANDOM()` 在大量数据时性能极差（4028个单词尚可，但未来增长后会成为瓶颈）。可以改用：
- 预生成随机 ID 列表
- 或使用 SQLite 的 `WHERE rowid BETWEEN X AND Y` 近似随机

### 3.2 备份恢复竞态条件

#### 影响范围

| 文件 | 行号 | 问题 |
|------|------|------|
| `DataBackupManager.swift` | 123-143 | 先删除当前数据库再复制备份，中途失败则数据全丢 |

#### 修复方案：原子替换 + 预验证

```swift
func restoreDatabase(from backupPath: String) throws {
    Logger.info("开始恢复数据库：\(backupPath)")

    guard fileManager.fileExists(atPath: backupPath) else {
        throw NSError(domain: "BackupError", code: -1, userInfo: [NSLocalizedDescriptionKey: "备份文件不存在"])
    }

    // 1. 先验证备份文件大小合理（> 0）
    let backupAttrs = try fileManager.attributesOfItem(atPath: backupPath)
    guard (backupAttrs[.size] as? UInt64 ?? 0) > 1024 else {
        throw NSError(domain: "BackupError", code: -2, userInfo: [NSLocalizedDescriptionKey: "备份文件过小，可能已损坏"])
    }

    // 2. 复制到临时文件（不删除原数据库）
    let tempPath = backupDirectory + "/restore_temp_\(UUID().uuidString).sqlite"
    try fileManager.copyItem(atPath: backupPath, toPath: tempPath)

    // 3. 验证临时文件可以打开（尝试连接）
    do {
        let testConn = try Connection(tempPath, readonly: true)
        _ = try testConn.scalar(db.words.count)  // 验证表存在且可读
    } catch {
        try? fileManager.removeItem(atPath: tempPath)  // 验证失败，清理临时文件
        throw error
    }

    // 4. 原子替换：先关闭当前连接，再移动临时文件覆盖
    db.resetConnection()

    let dbPath = db.path
    if fileManager.fileExists(atPath: dbPath) {
        try fileManager.removeItem(atPath: dbPath)  // 此时已关闭连接，风险可控
    }

    try fileManager.moveItem(atPath: tempPath, toPath: dbPath)
    try db.syncConnection()

    Logger.success("数据库恢复完成")
}
```

---

## 4. 错误处理与用户体验

### 问题概述

多处 catch 到 error 后只记录日志，不向用户展示。用户在 UI 上看到的可能是"无响应"或"加载失败但没有原因"。

### 影响范围

| 文件 | 行号 | 问题描述 |
|------|------|---------|
| `LearningViewModel.swift` | 67-70, 89, 103-105 | catch 后只记录日志，sessionWords 置为空数组但 UI 不提示原因 |
| `SpellingViewModel.swift` | 105-107 | catch 后只记录日志，用户不知道为什么数据库操作失败 |
| `SearchView.swift` | 114-116 | catch 后只记录日志，搜索结果为空但无错误提示 |
| `MainContentView.swift` | 36-38, 91-94 | catch 后只记录日志，数据库切换失败用户无感知 |
| `DataBackupManager.swift` | 多处 | catch 后只记录日志，备份失败用户不知道 |

### 修复方案：通过 `@Published` 属性暴露错误状态

```swift
// LearningViewModel.swift — 添加错误状态属性
@Published var errorMessage: String? = nil

func loadSession(count: Int) async {
    isLoading = true
    errorMessage = nil  // 清除之前的错误
    defer { isLoading = false }

    do {
        var words = try await repository.getNewWords(count: count)
        if words.isEmpty {
            words = try await repository.getRandomWords(count: count)
        }
        sessionWords = words
        sessionIndex = 0
    } catch {
        errorMessage = "加载失败：\(error.localizedDescription)"  // ← 展示给用户
        sessionWords = []
    }
}

// LearningView.swift — UI 展示错误信息（在 emptyStateView 中）
private var emptyStateView: some View {
    VStack(spacing: 20) {
        Image(systemName: viewModel.errorMessage != nil ? "exclamationmark.triangle" : "book.closed")
            .font(.system(size: 48))
            .foregroundColor(Theme.primary.opacity(0.5))

        if let error = viewModel.errorMessage {
            Text(error)
                .font(.system(size: 13))
                .foregroundColor(.red)
        } else {
            Text("未加载到学习单词")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }

        AccentButton("重新加载 20 个单词", icon: "arrow.clockwise") {
            Task { await viewModel.loadSession(count: 20) }
        }
    }
}
```

**需要修改的文件清单：**

| 文件 | 改动说明 |
|------|---------|
| `LearningViewModel.swift` | 添加 `@Published var errorMessage: String?`, catch 中赋值 |
| `LearningView.swift` | emptyStateView 展示错误信息，添加"清除错误"按钮 |
| `SpellingViewModel.swift` | 同上 |
| `SearchView.swift` | 搜索失败时显示错误提示（在 searchResultsOverlay 中） |
| `StatisticsViewModel.swift` | loadStats() catch 后展示错误 |

---

## 5. 其他小问题（低优先级）

| # | 文件 | 行号 | 说明 |
|---|------|------|------|
| (a) `mapRowToWord` 和 `mapRowToWordData` 完全重复 | WordRepository.swift | 227-271 | 合并为一个方法，删除 `mapRowToWordData` |
| (b) SearchView 每次创建都 new WordRepository() | SearchView.swift | 10 | 通过依赖注入传入，与 LearningView 共享同一个 repository |
| (c) `getWeeklyTrend` 手动解析日期字符串 | WordRepository.swift | 187-200 | 改用 SQLite 的 `strftime` + DateComponents，或直接使用 SQLite.swift 的类型映射 |
| (d) TTSManager 语言代码处理粗糙 | TTSManager.swift | 59-73 | `"en"` 和 `"zh"` 两位代码在部分 macOS 版本上可能找不到语音，建议缓存时做可用性检查 |
| (e) `SettingsStore` 单例 + NotificationCenter 混合使用 | SettingsStore.swift | 23-78 | 可用 `@AppStorage` + SwiftUI `.onChange` 替代部分逻辑，减少 NotificationCenter 的使用 |
| (f) README.md 过时 | README.md | 全文 | README 中列出了大量已删除的文件（如 `DataController.swift`, `LearningService.swift` 等），需要更新 |

---

## 6. 修改影响范围总结

### 核心文件（必须修改）

| 文件 | 预估改动行数 |
|------|-------------|
| `DatabaseManager.swift` | ~50 行（class → actor，移除锁） |
| `WordRepository.swift` | ~100 行（调用方加 await，SQL 改为参数化） |
| `DataBackupManager.swift` | ~30 行（恢复逻辑重写） |

### 次要文件（需要同步修改）

| 文件 | 预估改动行数 |
|------|-------------|
| `LearningViewModel.swift` | ~20 行（错误处理 + SM-2 统一） |
| `SpellingViewModel.swift` | ~15 行（错误处理 + SM-2 统一） |
| `LearningView.swift` | ~15 行（UI 展示错误信息） |
| `SearchView.swift` | ~10 行（依赖注入 + 错误处理） |
| `SpellingView.swift` | ~10 行（错误处理） |

**总计：约 250 行代码修改，涉及 7-8 个文件。**

---

## 7. 建议实施顺序

```
Phase 1: 线程安全（最高风险）
├─ DatabaseManager class → actor 改造
└─ WordRepository 所有调用加 await

Phase 2: 代码去重（消除不一致）
├─ WordRepository.updateLearningStatus 改用 SM2Algorithm
└─ LearningViewModel / SpellingViewModel SRS 字段同步

Phase 3: 数据安全（防止数据丢失）
├─ SQL 查询改为参数化
└─ DataBackupManager.restoreDatabase 原子替换

Phase 4: 错误处理（改善用户体验）
├─ ViewModel 添加 errorMessage @Published
└─ View 展示错误信息

Phase 5: 小问题清理（低优先级）
├─ mapRowToWord 去重
├─ SearchView 依赖注入
└─ README.md 更新
```
