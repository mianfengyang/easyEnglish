import Foundation
import SQLite

final class DataBackupManager {
    static let shared = DataBackupManager()
    
    private let fileManager = FileManager.default
    private let backupDirectory: String
    private let db = DatabaseManager.shared
    
    private init() {
        let appSupport = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        let easyEnglishDir = appSupport + "/EasyEnglish"
        self.backupDirectory = easyEnglishDir + "/backups"
        try? fileManager.createDirectory(atPath: backupDirectory, withIntermediateDirectories: true, attributes: nil)
        Logger.info("备份目录：\(backupDirectory)")
    }
    
    func exportLearningProgress() throws -> String {
        Logger.info("开始导出学习进度...")
        
        guard let conn = db.connection else {
            throw NSError(domain: "BackupError", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据库未初始化"])
        }
        
        let words = try conn.prepare(db.words.filter(db.isLearned == true))
        
        var progressData: [[String: Any]] = []
        for word in words {
            let record: [String: Any] = [
                "id": word[db.id].uuidString,
                "text": word[db.text],
                "isLearned": word[db.isLearned] ?? false,
                "learnedAt": word[db.learnedAt]?.ISO8601Format() ?? "",
                "masteryLevel": word[db.masteryLevel] ?? 0,
                "reviewCount": word[db.reviewCount] ?? 0,
                "correctCount": word[db.correctCount] ?? 0,
                "incorrectCount": word[db.incorrectCount] ?? 0,
                "ef": word[db.ef] ?? 2.5,
                "interval": word[db.interval] ?? 0,
                "reps": word[db.reps] ?? 0,
                "nextReview": word[db.nextReviewAt]?.ISO8601Format() ?? ""
            ]
            progressData.append(record)
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "learning_progress_\(timestamp).json"
        let filePath = backupDirectory + "/" + filename
        
        let jsonData = try JSONSerialization.data(withJSONObject: progressData, options: .prettyPrinted)
        try jsonData.write(to: URL(fileURLWithPath: filePath))
        
        Logger.success("导出完成：\(filePath) (共 \(progressData.count) 个单词)")
        return filePath
    }
    
    func importLearningProgress(from filePath: String) throws {
        Logger.info("开始导入学习进度：\(filePath)")
        
        guard let conn = db.connection else {
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
            
            let query = try conn.prepare(db.words.filter(db.id == uuid))
            if query.makeIterator().next() != nil {
                let updateQuery = db.words.filter(db.id == uuid).update(
                    db.isLearned <- ((record["isLearned"] as? Bool) ?? false),
                    db.masteryLevel <- ((record["masteryLevel"] as? Int64) ?? 0),
                    db.reviewCount <- ((record["reviewCount"] as? Int64) ?? 0),
                    db.correctCount <- ((record["correctCount"] as? Int64) ?? 0),
                    db.incorrectCount <- ((record["incorrectCount"] as? Int64) ?? 0),
                    db.ef <- ((record["ef"] as? Double) ?? 2.5),
                    db.interval <- ((record["interval"] as? Int64) ?? 0),
                    db.reps <- ((record["reps"] as? Int64) ?? 0)
                )
                try conn.run(updateQuery)
                updatedCount += 1
            } else {
                importedCount += 1
            }
        }
        
        Logger.success("导入完成：更新 \(updatedCount) 个单词，新增 \(importedCount) 个单词")
    }
    
    func createDatabaseBackup() throws -> String {
        Logger.info("开始创建数据库备份...")
        
        let dbPath = db.path
        
        guard fileManager.fileExists(atPath: dbPath) else {
            throw NSError(domain: "BackupError", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据库文件不存在"])
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "wordlist_backup_\(timestamp).sqlite"
        let backupPath = backupDirectory + "/" + filename
        
        try fileManager.copyItem(atPath: dbPath, toPath: backupPath)
        
        let attrs = try fileManager.attributesOfItem(atPath: backupPath)
        let size = attrs[.size] as? Int64 ?? 0
        
        Logger.success("数据库备份完成：\(backupPath) (\(size / 1024 / 1024)MB)")
        return backupPath
    }
    
    func restoreDatabase(from backupPath: String) throws {
        Logger.info("开始恢复数据库：\(backupPath)")
        
        guard fileManager.fileExists(atPath: backupPath) else {
            throw NSError(domain: "BackupError", code: -1, userInfo: [NSLocalizedDescriptionKey: "备份文件不存在"])
        }
        
        let dbPath = db.path
        
        db.resetConnection()
        
        if fileManager.fileExists(atPath: dbPath) {
            try fileManager.removeItem(atPath: dbPath)
        }
        
        try fileManager.copyItem(atPath: backupPath, toPath: dbPath)
        
        try db.syncConnection()
        
        Logger.success("数据库恢复完成")
    }
    
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
            
            backups.append(BackupInfo(filename: file, path: path, type: type, date: date, size: size))
        }
        
        backups.sort { $0.date > $1.date }
        return backups
    }
    
    func deleteBackup(_ backup: BackupInfo) throws {
        try fileManager.removeItem(atPath: backup.path)
        Logger.info("已删除备份：\(backup.filename)")
    }
    
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

private extension Date {
    func ISO8601Format() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}