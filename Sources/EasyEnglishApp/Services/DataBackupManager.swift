import Foundation
import SQLite

/// 数据备份管理器
/// 
/// ⚠️ **注意：此功能当前未被使用**
/// 
/// 功能：
/// - 导出学习进度到 JSON
/// - 从 JSON 导入学习进度
/// - 创建 SQLite 数据库备份
/// - 恢复数据库备份
/// 
/// TODO:
/// - 在 SettingsView 中添加备份/恢复 UI
/// - 集成到主应用流程
/// - 添加自动备份功能
final class DataBackupManager {
    static let shared = DataBackupManager()
    
    private let fileManager = FileManager.default
    private let backupDirectory: String
    
    private init() {
        // 备份目录：~/Library/Application Support/EasyEnglish/backups/
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        let easyEnglishDir = appSupport + "/EasyEnglish"
        self.backupDirectory = easyEnglishDir + "/backups"
        
        // 确保备份目录存在
        try? fileManager.createDirectory(atPath: backupDirectory, withIntermediateDirectories: true, attributes: nil)
        Logger.info("备份目录：\(backupDirectory)")
    }
    
    // MARK: - JSON 导出/导入
    
    /// 导出学习进度到 JSON
    /// - Returns: 备份文件路径
    func exportLearningProgress() throws -> String {
        Logger.info("开始导出学习进度...")
        
        guard let db = WordDatabaseManager.shared.getDatabaseConnection() else {
            throw NSError(domain: "BackupError", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据库未初始化"])
        }
        
        // 查询所有已学习的单词
        let words = try db.prepare(WordDatabaseManager.shared.words.filter(WordDatabaseManager.shared.isLearned == true))
        
        var progressData: [[String: Any]] = []
        for word in words {
            let record: [String: Any] = [
                "id": word[WordDatabaseManager.shared.id].uuidString,
                "text": word[WordDatabaseManager.shared.text],
                "isLearned": word[WordDatabaseManager.shared.isLearned] ?? false,
                "learnedAt": word[WordDatabaseManager.shared.learnedAt]?.ISO8601Format() ?? "",
                "masteryLevel": word[WordDatabaseManager.shared.masteryLevel] ?? 0,
                "reviewCount": word[WordDatabaseManager.shared.reviewCount] ?? 0,
                "correctCount": word[WordDatabaseManager.shared.correctCount] ?? 0,
                "incorrectCount": word[WordDatabaseManager.shared.incorrectCount] ?? 0,
                "ef": word[WordDatabaseManager.shared.ef] ?? 2.5,
                "interval": word[WordDatabaseManager.shared.interval] ?? 0,
                "reps": word[WordDatabaseManager.shared.reps] ?? 0,
                "nextReview": word[WordDatabaseManager.shared.nextReviewAt]?.ISO8601Format() ?? ""
            ]
            progressData.append(record)
        }
        
        // 生成文件名
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "learning_progress_\(timestamp).json"
        let filePath = backupDirectory + "/" + filename
        
        // 序列化到 JSON
        let jsonData = try JSONSerialization.data(withJSONObject: progressData, options: .prettyPrinted)
        try jsonData.write(to: URL(fileURLWithPath: filePath))
        
        Logger.success("导出完成：\(filePath) (共 \(progressData.count) 个单词)")
        return filePath
    }
    
    /// 从 JSON 导入学习进度
    /// - Parameter filePath: JSON 文件路径
    func importLearningProgress(from filePath: String) throws {
        Logger.info("开始导入学习进度：\(filePath)")
        
        guard let db = WordDatabaseManager.shared.getDatabaseConnection() else {
            throw NSError(domain: "BackupError", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据库未初始化"])
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        let jsonData = try Data(contentsOf: fileURL)
        let progressData = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
        
        var importedCount = 0
        var updatedCount = 0
        
        for record in progressData {
            guard let uuidString = record["id"] as? String,
                  let uuid = UUID(uuidString: uuidString) else {
                Logger.warning("跳过无效记录：\(record)")
                continue
            }
            
            // 检查单词是否存在
            let query = try db.prepare(WordDatabaseManager.shared.words.filter(WordDatabaseManager.shared.id == uuid))
            if query.makeIterator().next() != nil {
                // 更新现有记录
                let updateQuery = WordDatabaseManager.shared.words.filter(WordDatabaseManager.shared.id == uuid).update(
                    WordDatabaseManager.shared.isLearned <- ((record["isLearned"] as? Bool) ?? false),
                    WordDatabaseManager.shared.masteryLevel <- ((record["masteryLevel"] as? Int64) ?? 0),
                    WordDatabaseManager.shared.reviewCount <- ((record["reviewCount"] as? Int64) ?? 0),
                    WordDatabaseManager.shared.correctCount <- ((record["correctCount"] as? Int64) ?? 0),
                    WordDatabaseManager.shared.incorrectCount <- ((record["incorrectCount"] as? Int64) ?? 0),
                    WordDatabaseManager.shared.ef <- ((record["ef"] as? Double) ?? 2.5),
                    WordDatabaseManager.shared.interval <- ((record["interval"] as? Int64) ?? 0),
                    WordDatabaseManager.shared.reps <- ((record["reps"] as? Int64) ?? 0)
                )
                try db.run(updateQuery)
                updatedCount += 1
            } else {
                importedCount += 1
            }
        }
        
        Logger.success("导入完成：更新 \(updatedCount) 个单词，新增 \(importedCount) 个单词")
    }
    
    // MARK: - SQLite 数据库备份/恢复
    
    /// 创建 SQLite 数据库备份
    /// - Returns: 备份文件路径
    func createDatabaseBackup() throws -> String {
        Logger.info("开始创建数据库备份...")
        
        let dbPath = WordDatabaseManager.shared.databasePath
        
        guard fileManager.fileExists(atPath: dbPath) else {
            throw NSError(domain: "BackupError", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据库文件不存在"])
        }
        
        // 生成文件名
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "wordlist_backup_\(timestamp).sqlite"
        let backupPath = backupDirectory + "/" + filename
        
        // 复制文件
        try fileManager.copyItem(atPath: dbPath, toPath: backupPath)
        
        // 获取文件大小
        let attrs = try fileManager.attributesOfItem(atPath: backupPath)
        let size = attrs[.size] as? Int64 ?? 0
        
        Logger.success("数据库备份完成：\(backupPath) (\(size / 1024 / 1024)MB)")
        return backupPath
    }
    
    /// 恢复数据库备份
    /// - Parameter backupPath: 备份文件路径
    func restoreDatabase(from backupPath: String) throws {
        Logger.info("开始恢复数据库：\(backupPath)")
        
        guard fileManager.fileExists(atPath: backupPath) else {
            throw NSError(domain: "BackupError", code: -1, userInfo: [NSLocalizedDescriptionKey: "备份文件不存在"])
        }
        
        let dbPath = WordDatabaseManager.shared.databasePath
        
        // 关闭当前数据库连接
        WordDatabaseManager.shared.resetConnection()
        
        // 删除当前数据库
        if fileManager.fileExists(atPath: dbPath) {
            try fileManager.removeItem(atPath: dbPath)
        }
        
        // 复制备份文件
        try fileManager.copyItem(atPath: backupPath, toPath: dbPath)
        
        // 重新初始化数据库
        try WordDatabaseManager.shared.initializeDatabase()
        
        Logger.success("数据库恢复完成")
    }
    
    // MARK: - 备份管理
    
    /// 列出所有备份
    func listBackups() throws -> [BackupInfo] {
        guard fileManager.fileExists(atPath: backupDirectory) else {
            return []
        }
        
        let files = try fileManager.contentsOfDirectory(atPath: backupDirectory)
        var backups: [BackupInfo] = []
        
        for file in files {
            let path = backupDirectory + "/" + file
            let attrs = try fileManager.attributesOfItem(atPath: path)
            let date = attrs[.creationDate] as? Date ?? Date()
            let size = attrs[.size] as? Int64 ?? 0
            
            let type: BackupType
            if file.hasSuffix(".json") {
                type = .learningProgress
            } else if file.hasSuffix(".sqlite") {
                type = .database
            } else {
                continue
            }
            
            backups.append(BackupInfo(
                filename: file,
                path: path,
                type: type,
                date: date,
                size: size
            ))
        }
        
        // 按日期排序
        backups.sort { $0.date > $1.date }
        return backups
    }
    
    /// 删除备份
    /// - Parameter backup: 备份信息
    func deleteBackup(_ backup: BackupInfo) throws {
        try fileManager.removeItem(atPath: backup.path)
        Logger.info("已删除备份：\(backup.filename)")
    }
    
    /// 清理旧备份（保留最近 N 个）
    /// - Parameter keepCount: 保留数量
    func cleanupOldBackups(keepCount: Int = 10) throws {
        let backups = try listBackups()
        
        if backups.count > keepCount {
            let toDelete = Array(backups.suffix(from: keepCount))
            for backup in toDelete {
                try deleteBackup(backup)
            }
            Logger.info("清理完成：删除 \(toDelete.count) 个旧备份")
        }
    }
}

// MARK: - 数据模型

struct BackupInfo {
    let filename: String
    let path: String
    let type: BackupType
    let date: Date
    let size: Int64
    
    var sizeFormatted: String {
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return "\(size / 1024) KB"
        } else {
            return String(format: "%.2f MB", Double(size) / 1024 / 1024)
        }
    }
}

enum BackupType {
    case learningProgress
    case database
    
    var displayName: String {
        switch self {
        case .learningProgress: return "学习进度"
        case .database: return "数据库"
        }
    }
}

// MARK: - 辅助扩展

private extension Date {
    func ISO8601Format() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
