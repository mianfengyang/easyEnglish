import Foundation
import SQLite

final class DatabaseManager: @unchecked Sendable {
    static let shared = DatabaseManager()
    
    private var db: Connection?
    private var dbPath: String
    private let lock = NSLock()
    
    private init() {
        self.dbPath = PathManager.shared.currentDatabasePath
        setupConnection()
    }
    
    private func setupConnection() {
        do {
            self.db = try Connection(self.dbPath, readonly: false)
        } catch {
            Logger.warning("无法以可写模式打开数据库，尝试只读模式：\(error)")
            do {
                self.db = try Connection(self.dbPath, readonly: true)
            } catch {
                Logger.error("数据库初始化失败：\(error)")
            }
        }
    }
    
    var connection: Connection? {
        lock.lock()
        defer { lock.unlock() }
        return db
    }
    
    var path: String { dbPath }
    
    func switchToDatabase(at path: String, readonly: Bool = false) throws {
        Logger.info("切换数据库到：\(path) (readonly: \(readonly))")
        lock.lock()
        defer { lock.unlock() }
        db = try Connection(path, readonly: readonly)
        self.dbPath = path
        Logger.success("数据库切换成功")
    }
    
    func resetConnection() {
        lock.lock()
        defer { lock.unlock() }
        db = nil
    }
    
    func syncConnection() throws {
        lock.lock()
        defer { lock.unlock() }
        db = try Connection(self.dbPath, readonly: false)
    }
    
    func initializeIfNeeded() throws {
        guard let conn = connection, !conn.readonly else { return }
        Logger.info("DatabaseManager: 开始初始化数据库结构...")
        
        do {
        try conn.run(words.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(text, unique: true)
                t.column(ipa)
                t.column(meanings)
                t.column(examples)
                t.column(chineseExamples)
                t.column(roots)
                t.column(isLearned)
                t.column(learnedAt)
                t.column(masteryLevel)
                t.column(reviewCount)
                t.column(correctCount)
                t.column(incorrectCount)
                t.column(lastReviewedAt)
                t.column(nextReviewAt)
                t.column(ef)
                t.column(interval)
                t.column(reps)
            })
            
            try conn.run(databaseStats.create(ifNotExists: true) { t in
                t.column(idStat, primaryKey: true)
                t.column(databaseName)
                t.column(totalWords)
                t.column(learnedWords)
                t.column(unlearnedWords)
                t.column(lastUpdated)
            })
            
            try conn.run(words.createIndex(text, unique: true, ifNotExists: true))
            Logger.success("数据库初始化完成")
        } catch {
            Logger.error("数据库初始化失败: \(error)")
            throw error
        }

        // 初始化日统计表；若已存在则忽略
        do {
            let dailyStats = Table("daily_stats")
            let dsDate = Expression<Date>("date")
            let dsNewWords = Expression<Int64>("new_words")
            let dsReviews = Expression<Int64>("reviews")
            let dsCorrectRate = Expression<Double>("correct_rate")
            try conn.run(dailyStats.create(ifNotExists: true) { t in
                t.column(dsDate, primaryKey: true)
                t.column(dsNewWords)
                t.column(dsReviews)
                t.column(dsCorrectRate)
            })
        } catch {
            // 可能表已存在或其它错误，忽略避免阻塞启动
            Logger.warning("Daily stats table init skipped: \(error)")
        }
    }
    
    // MARK: - Table Definitions
    
    let words = Table("words")
    let id = Expression<UUID>("id")
    let text = Expression<String>("text")
    let ipa = Expression<String?>("ipa")
    let meanings = Expression<String?>("meanings")
    let examples = Expression<String?>("examples")
    let chineseExamples = Expression<String?>("chineseExamples")
    let roots = Expression<String?>("roots")
    let isLearned = Expression<Bool?>("is_learned")
    let learnedAt = Expression<Date?>("learned_at")
    let masteryLevel = Expression<Int64?>("mastery_level")
    let reviewCount = Expression<Int64?>("review_count")
    let correctCount = Expression<Int64?>("correct_count")
    let incorrectCount = Expression<Int64?>("incorrect_count")
    let lastReviewedAt = Expression<Date?>("last_reviewed_at")
    let nextReviewAt = Expression<Date?>("next_review_at")
    let ef = Expression<Double?>("ef")
    let interval = Expression<Int64?>("interval")
    let reps = Expression<Int64?>("reps")
    
    let databaseStats = Table("database_stats")
    let idStat = Expression<Int64>("id")
    let databaseName = Expression<String>("database_name")
    let totalWords = Expression<Int64>("total_words")
    let learnedWords = Expression<Int64>("learned_words")
    let unlearnedWords = Expression<Int64>("unlearned_words")
    let lastUpdated = Expression<Date>("last_updated")
}
