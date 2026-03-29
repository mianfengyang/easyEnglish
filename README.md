# EasyEnglish macOS App

一个基于 SwiftUI + SQLite 的 macOS 英语学习应用，使用 SM-2 间隔重复算法。

## 核心特性

- **SQLite 预编译数据库** - 启动速度 < 1 秒
- **SM-2 SRS 算法** - 科学的间隔重复学习
- **统一日志系统** - 基于 os.log 的结构化日志
- **错误恢复机制** - 数据库操作自动重试
- **完整测试覆盖** - 单元测试 + 集成测试
- **智能拼写复习** - 实时字母高亮反馈 ⭐ NEW
- **词根详情视图** - 单词词根分析 ⭐ NEW
- **数据备份功能** - 自动数据备份 ⭐ NEW
- **词根信息更新** - 从网络获取最新词根信息 ⭐ NEW

## 项目结构

```
EasyEnglish/
├── Sources/EasyEnglishApp/
│   ├── EasyEnglishApp.swift    (App 入口)
│   ├── Services/
│   │   ├── Logger.swift        (统一日志系统)
│   │   ├── WordDatabaseManager.swift
│   │   ├── TTSManager.swift
│   │   ├── SettingsStore.swift
│   │   ├── DataBackupManager.swift  (数据备份) ⭐
│   │   ├── LearningService.swift    (学习服务) ⭐
│   │   └── PathManager.swift        (路径管理) ⭐
│   ├── Controllers/
│   │   └── DataController.swift
│   ├── Models/
│   │   └── WordData.swift      (单词数据模型) ⭐
│   ├── Views/
│   │   ├── Transitions/         (页面过渡) ⭐
│   │   │   └── PageTransitionView.swift
│   │   ├── ContentView.swift    (主视图)
│   │   ├── ReviewSpellingView.swift  (拼写复习) ⭐
│   │   ├── WordRootsDetailView.swift (词根详情) ⭐
│   │   ├── WordDetailView.swift      (单词详情) ⭐
│   │   ├── SpellingTestView.swift     (拼写测试) ⭐
│   │   ├── WordCardView.swift   (单词卡片)
│   │   ├── StatsView.swift      (统计视图)
│   │   ├── SettingsView.swift   (设置视图)
│   │   ├── SearchView.swift     (搜索视图)
│   │   ├── ChartsLineView.swift       (图表视图) ⭐
│   │   └── SimpleLineChart.swift      (简单图表) ⭐
│   ├── SRS/
│   │   └── SM2.swift
│   └── Resources/
│       ├── cet4.apkg.json
│       └── wordlist.sqlite
├── Tests/EasyEnglishTests/
│   ├── SM2Tests.swift
│   ├── DatabaseTests.swift
│   ├── LoggerTests.swift
│   ├── LearningServiceTests.swift     ⭐
│   └── LearningSessionManagerTests.swift ⭐
├── scripts/
│   ├── import_database.swift    (数据库导入)
│   └── update_roots.swift       (词根更新) ⭐
├── Data/wordlists/
│   ├── cet4.apkg.json
│   ├── wordlist.sqlite
│   └── roots_cache.json         (词根缓存) ⭐
├── Package.swift
├── .gitignore
├── build_app.sh                 (构建脚本) ⭐
├── cet4.apkg.json               (词库文件)
└── README.md
```

---

## 🚀 功能更新（v3.0）

### ✅ 已完成的新功能

#### **智能拼写复习**

**功能特点：**
- ✅ 实时字母高亮反馈（正确绿色，错误红色）
- ✅ 透明单词背景，增强视觉效果
- ✅ 自动焦点管理，进入界面即可输入
- ✅ 错误发音提示，增强记忆效果

**技术实现：**
- 隐藏的 `TextField` 捕获键盘输入
- 状态驱动的颜色变化
- 自动焦点管理和恢复机制

#### **词根详情视图**

**功能特点：**
- ✅ 显示单词的词根、词缀分析
- ✅ 支持从网络更新最新词根信息
- ✅ 优雅的动画过渡效果
- ✅ 与学习界面风格一致

**技术实现：**
- `WordRootsDetailView` 专门处理词根展示
- 网络 API 集成获取词根信息
- 本地缓存机制提高性能

#### **数据备份功能**

**功能特点：**
- ✅ 自动备份学习数据
- ✅ 支持手动备份和恢复
- ✅ 备份文件管理
- ✅ 数据安全性保障

**技术实现：**
- `DataBackupManager` 处理备份逻辑
- 定时自动备份机制
- 增量备份策略减少文件大小

#### **词根信息更新**

**功能特点：**
- ✅ 从网络自动获取词根信息
- ✅ 支持批量更新单词词根
- ✅ 智能错误处理和重试机制
- ✅ 缓存机制减少网络请求

**技术实现：**
- `update_roots.swift` 脚本
- 多 API 数据源整合
- 并发处理提高效率

---

## 🔧 代码质量优化（v2.1）

### 统一日志系统

**优化前：**
- ❌ 使用 `print` 调试，难以过滤
- ❌ 无结构化日志格式
- ❌ 无法在生产环境禁用调试日志

**优化后：**
- ✅ 基于 `os.log` 的统一日志系统
- ✅ 支持 6 种日志级别（debug, info, warning, error, success, performance）
- ✅ DEBUG 模式下自动过滤 debug 日志
- ✅ 性能测量工具 `Logger.measure`

### 错误恢复机制

**优化前：**
- ❌ 数据库连接失败直接崩溃
- ❌ 无重试机制
- ❌ 错误信息不清晰

**优化后：**
- ✅ 数据库操作自动重试（最多 3 次）
- ✅ 结构化错误日志
- ✅ 清晰的错误提示

### 测试覆盖

**新增测试：**
- ✅ `LoggerTests.swift` - 日志系统测试
- ✅ `DatabaseTests.swift` - SQLite 数据库操作测试
- ✅ `SM2Tests.swift` - SM-2 算法测试
- ✅ `LearningServiceTests.swift` - 学习服务测试 ⭐
- ✅ `LearningSessionManagerTests.swift` - 学习会话管理测试 ⭐

---

## 📦 安装与使用

### 1. 安装依赖

```bash
cd /Users/mfyang/project/easyEnglish
swift package resolve
```

### 2. 构建应用

**方法一：通过 Xcode（推荐）**

1. 用 Xcode 打开项目
2. 选择 `EasyEnglish` scheme
3. 点击运行按钮 (⌘R)
4. 查看调试控制台输出日志

**方法二：命令行方式**

```bash
# 构建应用
swift build

# 运行应用
open .build/debug/EasyEnglish.app
```

**方法三：使用构建脚本**

```bash
# 运行构建脚本
./build_app.sh

# 运行构建好的应用
open .build/release/EasyEnglish.app
```

### 3. 首次启动（初始化数据库）

**首次启动过程：**
1. 自动创建 SQLite 数据库 (~15MB)
2. 从 `cet4.apkg.json` 导入 4028 个单词
3. 耗时约 5-10 秒

### 4. 后续启动

```bash
open .build/debug/EasyEnglish.app
```

**启动时间：< 1 秒** ⚡

---

## 🧪 运行测试

```bash
# 运行所有测试
swift test

# 运行特定测试
swift test --filter LoggerTests
swift test --filter DatabaseTests
```

---

## 🔍 调试与日志

### 在 Xcode 中查看日志

1. 运行应用后，打开 **Debug Console**（⇧⌘Y）
2. 查看关键日志输出：
   - ℹ️ 信息日志
   - ✅ 成功日志
   - ⚠️ 警告日志
   - ❌ 错误日志
   - ⚡ 性能日志

### 日志级别

| 级别 | Emoji | 用途 |
|------|-------|------|
| debug | 🔵 | 调试信息（仅 DEBUG 模式） |
| info | ℹ️ | 一般信息 |
| warning | ⚠️ | 警告，不影响运行 |
| error | ❌ | 错误，需要处理 |
| success | ✅ | 操作成功 |
| performance | ⚡ | 性能测量 |

---

## 📊 性能对比

| 场景 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 首次启动 | ~4-6 秒 | ~5-10 秒* | - |
| 后续启动 | ~4-6 秒 | **< 1 秒** | **10x+** |
| 内存占用 | ~200MB | ~50MB | 4x |

*首次启动包含导入时间，仅需执行一次

---

## 🔧 技术细节

### 数据库位置
```
~/Library/Application Support/EasyEnglish/wordlist.sqlite
```

### 数据库结构
```sql
CREATE TABLE words (
    id UUID PRIMARY KEY,
    text TEXT UNIQUE,
    ipa TEXT,
    meanings TEXT,
    examples TEXT,
    chineseExamples TEXT,
    roots TEXT,
    is_learned BOOLEAN,
    mastery_level INTEGER,
    review_count INTEGER,
    correct_count INTEGER,
    incorrect_count INTEGER,
    ef DOUBLE,
    interval INTEGER,
    reps INTEGER,
    next_review_at TIMESTAMP
);

CREATE INDEX idx_words_text ON words(text);
```

### 关键代码

**Logger.swift:**
- `Logger.info()` - 信息日志
- `Logger.error()` - 错误日志（带 error 对象）
- `Logger.measure()` - 性能测量

**WordDatabaseManager.swift:**
- `initializeDatabase()` - 初始化数据库连接（带重试）
- `getNewUnlearnedWordsData()` - 获取未学习单词（优化查询）
- `updateWordLearningStatus()` - 更新学习状态

---

## 🎯 下一步优化建议

### 已完成 ✅
1. ~~统一日志系统~~
2. ~~错误恢复机制~~
3. ~~数据库测试覆盖~~
4. ~~统一数据层（移除 Core Data，只用 SQLite）~~
5. ~~数据备份/导出功能~~

### 待完成 📋
6. 支持多词库切换
7. iCloud 同步
8. 性能 profiling
9. 代码重构/文档化

---

**最后更新**: 2026 年 3 月 21 日  
**版本**: v3.0 - 智能学习功能增强版
