import Foundation
import SQLite

/// SQLite 数据库管理器 - 用于预编译词库数据
final class WordDatabaseManager {
    static let shared = WordDatabaseManager()
    
    private var db: Connection?
    private let dbPath: String
    private let basePath: String
    
    /// 获取数据库路径（公开接口）
    var databasePath: String {
        return dbPath
    }
    
    /// 重置数据库连接（用于备份恢复场景）
    func resetConnection() {
        db = nil
    }
    
    /// 获取数据库连接（用于备份等高级操作）
    func getDatabaseConnection() -> Connection? {
        return db
    }

    /// 重试配置
    private let maxRetryCount = 3
    private let retryDelayMilliseconds: Int = 500

    // 表定义 (internal)
    internal let words = Table("words")
    internal let id = Expression<UUID>("id")
    internal let text = Expression<String>("text")
    internal let ipa = Expression<String?>("ipa")
    internal let meanings = Expression<String?>("meanings")
    internal let examples = Expression<String?>("examples")
    internal let chineseExamples = Expression<String?>("chineseExamples")
    internal let roots = Expression<String?>("roots")
    
    // 学习统计字段 (internal) - 使用可选类型处理 NULL 值
    internal let isLearned = Expression<Bool?>("is_learned")
    internal let learnedAt = Expression<Date?>("learned_at")
    internal let masteryLevel = Expression<Int64?>("mastery_level")
    internal let reviewCount = Expression<Int64?>("review_count")
    internal let correctCount = Expression<Int64?>("correct_count")
    internal let incorrectCount = Expression<Int64?>("incorrect_count")
    internal let lastReviewedAt = Expression<Date?>("last_reviewed_at")
    internal let nextReviewAt = Expression<Date?>("next_review_at")
    internal let ef = Expression<Double?>("ef")
    internal let interval = Expression<Int64?>("interval")
    internal let reps = Expression<Int64?>("reps")

    // 数据库统计信息表 (internal)
    internal let databaseStats = Table("database_stats")
    internal let idStat = Expression<Int64>("id")
    internal let databaseName = Expression<String>("database_name")
    internal let totalWords = Expression<Int64>("total_words")
    internal let learnedWords = Expression<Int64>("learned_words")
    internal let unlearnedWords = Expression<Int64>("unlearned_words")
    internal let lastUpdated = Expression<Date>("last_updated")

    private init() {
        // 使用 PathManager 获取路径
        self.basePath = PathManager.shared.wordlistsDirectory
        self.dbPath = PathManager.shared.currentDatabasePath
        
        Logger.info("数据库路径：\(dbPath)")
        
        // 验证数据库文件是否存在
        if !PathManager.shared.databaseExists {
            Logger.error("数据库文件不存在：\(dbPath)")
            Logger.warning("请运行导入工具：swift run import_database")
        } else {
            Logger.success("数据库文件存在")
            
            // 显示数据库大小
            if let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath),
               let size = attrs[.size] as? Int64 {
                Logger.info("数据库大小：\(size / 1024 / 1024)MB")
            }
        }
    }
    
    /// 初始化数据库连接和表结构（带重试机制）
    func initializeDatabase() throws {
        Logger.info("开始初始化数据库连接...")
        
        var lastError: Error?
        
        for attempt in 1...maxRetryCount {
            do {
                db = try Connection(dbPath, readonly: false)
                Logger.success("数据库连接成功（尝试 \(attempt)/\(maxRetryCount)）")
                break
            } catch {
                lastError = error
                Logger.warning("数据库连接失败（尝试 \(attempt)/\(maxRetryCount)）: \(error.localizedDescription)")
                if attempt < maxRetryCount {
                    // 同步等待
                    Thread.sleep(forTimeInterval: TimeInterval(retryDelayMilliseconds) / 1000.0)
                }
            }
        }
        
        if db == nil {
            throw lastError ?? NSError(domain: "DBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据库连接失败"])
        }
        
        // 检查表是否存在
        let tableExists = try checkTableExists(tableName: "words")
        
        if !tableExists {
            Logger.info("Creating words table...")
            try createWordsTable()
            Logger.success("Words table created")
        } else {
            Logger.success("Words table already exists")
            
            // 验证数据库是否有数据
            let count = try db!.scalar(words.count)
            Logger.info("数据库中单词数：\(count)")
        }
    }
    
    /// 检查表是否存在
    private func checkTableExists(tableName: String) throws -> Bool {
        guard let conn = db else { return false }
        
        let query = "SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?"
        let result = try conn.scalar(query, tableName) as? Int ?? 0
        return result > 0
    }

    /// 创建 words 表
    private func createWordsTable() throws {
        try db!.run(words.create { t in
            t.column(id, primaryKey: true)
            t.column(text, unique: true)
            t.column(ipa)
            t.column(meanings)
            t.column(examples)
            t.column(chineseExamples)
            t.column(roots)
        })
        
        // 创建索引加速查询
        try db!.run(words.createIndex(text, unique: true))
        try db!.run(words.createIndex(text))
    }
    
    /// 随机获取指定数量的单词（返回 WordData）
    func getRandomWordsData(count: Int) throws -> [WordData] {
        guard let conn = db else {
            let error = NSError(domain: "DBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not initialized"])
            Logger.error("Database not initialized", error: error)
            throw error
        }
        
        Logger.debug("Getting \(count) random words data")
        
        var wordsArray: [WordData] = []
        
        do {
            let query = words.order(Expression<Int>.random()).limit(count)
            
            for result in try conn.prepare(query) {
                let wordData = WordData(
                    id: result[id],
                    text: result[text],
                    ipa: result[ipa],
                    meanings: result[meanings],
                    examples: result[examples],
                    chineseExamples: result[chineseExamples],
                    roots: result[roots]
                )
                wordsArray.append(wordData)
            }
            
            Logger.success("Retrieved \(wordsArray.count) random words data")
            return wordsArray
        } catch {
            Logger.error("Failed to get random words data", error: error)
            throw error
        }
    }
    
    /// 获取未学习过的新单词（返回 WordData）
    func getNewUnlearnedWordsData(count: Int) throws -> [WordData] {
        guard let conn = db else {
            let error = NSError(domain: "DBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not initialized"])
            Logger.error("Database not initialized", error: error)
            throw error
        }
        
        Logger.debug("getNewUnlearnedWordsData 开始执行，请求数量：\(count)")
        
        let allWordsQuery = words.order(text)
        var newWords: [(UUID, String, String?, String?, String?, String?, String?)] = []
        
        Logger.debug("开始遍历 SQLite 数据库...")
        let sqliteStartTime = CFAbsoluteTimeGetCurrent()
        var totalWordsChecked = 0
        var skippedCount = 0
        
        for result in try conn.prepare(allWordsQuery) {
            totalWordsChecked += 1
            let text = result[text]
            
            if text.isEmpty {
                Logger.warning("发现空文本单词，ID: \(result[id])")
                continue
            }
            
            // 检查是否已学习（NULL 视为未学习）
            let isLearned = result[isLearned] ?? false
            if !isLearned {
                newWords.append((
                    result[id],
                    text,
                    result[ipa],
                    result[meanings],
                    result[examples],
                    result[chineseExamples],
                    result[roots]
                ))
            } else {
                skippedCount += 1
            }
            
            #if DEBUG
            if totalWordsChecked % 1000 == 0 {
                Logger.debug("已检查 \(totalWordsChecked) 个单词，找到 \(newWords.count) 个新单词")
            }
            #endif
        }
        
        Logger.performance("SQLite 遍历完成", duration: CFAbsoluteTimeGetCurrent() - sqliteStartTime)
        Logger.debug("总共检查了 \(totalWordsChecked) 个单词，其中 \(skippedCount) 个已学习，\(newWords.count) 个为新单词")
        
        if newWords.isEmpty {
            Logger.warning("没有可用的新单词")
            return []
        }
        
        // 随机选择
        let shuffled = newWords.shuffled()
        let selected = Array(shuffled.prefix(count))
        Logger.debug("选择了 \(selected.count) 个新单词")
        
        // 创建 WordData 对象
        var wordsArray: [WordData] = []
        for (id, text, ipa, meanings, examples, chineseExamples, roots) in selected {
            let wordData = WordData(
                id: id,
                text: text,
                ipa: ipa,
                meanings: meanings,
                examples: examples,
                chineseExamples: chineseExamples,
                roots: roots
            )
            wordsArray.append(wordData)
        }
        
        Logger.success("创建了 \(wordsArray.count) 个 WordData 对象")
        return wordsArray
    }

    /// 根据 ID 获取单个单词的完整数据（返回 WordData）
    func getWordDataById(id: UUID) throws -> WordData? {
        guard let conn = db else {
            let error = NSError(domain: "DBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not initialized"])
            Logger.error("Database not initialized", error: error)
            throw error
        }
        
        let query = words.filter(self.id == id).limit(1)
        guard let result = try conn.prepare(query).makeIterator().next() else {
            return nil
        }
        
        return WordData(
            id: result[self.id],
            text: result[text],
            ipa: result[ipa],
            meanings: result[meanings],
            examples: result[examples],
            chineseExamples: result[chineseExamples],
            roots: result[roots],
            isLearned: result[isLearned] ?? false,
            learnedAt: result[learnedAt],
            masteryLevel: result[masteryLevel] ?? 0,
            reviewCount: result[reviewCount] ?? 0,
            correctCount: result[correctCount] ?? 0,
            incorrectCount: result[incorrectCount] ?? 0,
            ef: result[ef] ?? 2.5,
            interval: result[interval] ?? 0,
            reps: result[reps] ?? 0,
            nextReview: result[nextReviewAt] ?? Date()
        )
    }
    
    /// 根据文本搜索单词（支持模糊匹配，返回 WordData）
    func getWordDataBySearch(text: String) throws -> WordData? {
        guard let conn = db else {
            let error = NSError(domain: "DBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not initialized"])
            Logger.error("Database not initialized", error: error)
            throw error
        }
        
        // 精确匹配（不区分大小写）
        let exactQuery = words.filter(self.text == text).limit(1)
        if let result = try conn.prepare(exactQuery).makeIterator().next() {
            Logger.info("✅ 精确匹配到单词：\(text)")
            return WordData(
                id: result[self.id],
                text: result[self.text],
                ipa: result[self.ipa],
                meanings: result[self.meanings],
                examples: result[self.examples],
                chineseExamples: result[self.chineseExamples],
                roots: result[self.roots],
                isLearned: result[self.isLearned] ?? false,
                learnedAt: result[self.learnedAt],
                masteryLevel: result[self.masteryLevel] ?? 0,
                reviewCount: result[self.reviewCount] ?? 0,
                correctCount: result[self.correctCount] ?? 0,
                incorrectCount: result[self.incorrectCount] ?? 0,
                ef: result[self.ef] ?? 2.5,
                interval: result[self.interval] ?? 0,
                reps: result[self.reps] ?? 0,
                nextReview: result[self.nextReviewAt] ?? Date()
            )
        }
        
        // 如果没有精确匹配，尝试前缀匹配（不区分大小写）
        let prefixQuery = words.filter(self.text.like(text + "%")).limit(5)
        var prefixResults: [WordData] = []
        for result in try conn.prepare(prefixQuery) {
            let wordData = WordData(
                id: result[self.id],
                text: result[self.text],
                ipa: result[self.ipa],
                meanings: result[self.meanings],
                examples: result[self.examples],
                chineseExamples: result[self.chineseExamples],
                roots: result[self.roots],
                isLearned: result[self.isLearned] ?? false,
                learnedAt: result[self.learnedAt],
                masteryLevel: result[self.masteryLevel] ?? 0,
                reviewCount: result[self.reviewCount] ?? 0,
                correctCount: result[self.correctCount] ?? 0,
                incorrectCount: result[self.incorrectCount] ?? 0,
                ef: result[self.ef] ?? 2.5,
                interval: result[self.interval] ?? 0,
                reps: result[self.reps] ?? 0,
                nextReview: result[self.nextReviewAt] ?? Date()
            )
            prefixResults.append(wordData)
        }
        
        if !prefixResults.isEmpty {
            Logger.info("🔍 前缀匹配到 \(prefixResults.count) 个单词，返回第一个：\(prefixResults[0].text)")
            return prefixResults.first
        }
        
        // 如果还没有，尝试包含匹配（不区分大小写）
        let containsQuery = words.filter(self.text.like("%" + text + "%")).limit(5)
        var containsResults: [WordData] = []
        for result in try conn.prepare(containsQuery) {
            let wordData = WordData(
                id: result[self.id],
                text: result[self.text],
                ipa: result[self.ipa],
                meanings: result[self.meanings],
                examples: result[self.examples],
                chineseExamples: result[self.chineseExamples],
                roots: result[self.roots],
                isLearned: result[self.isLearned] ?? false,
                learnedAt: result[self.learnedAt],
                masteryLevel: result[self.masteryLevel] ?? 0,
                reviewCount: result[self.reviewCount] ?? 0,
                correctCount: result[self.correctCount] ?? 0,
                incorrectCount: result[self.incorrectCount] ?? 0,
                ef: result[self.ef] ?? 2.5,
                interval: result[self.interval] ?? 0,
                reps: result[self.reps] ?? 0,
                nextReview: result[self.nextReviewAt] ?? Date()
            )
            containsResults.append(wordData)
        }
        
        if !containsResults.isEmpty {
            Logger.info("🔍 包含匹配到 \(containsResults.count) 个单词，返回第一个：\(containsResults[0].text)")
            return containsResults.first
        }
        
        Logger.warning("⚠️ 未找到匹配的单词：\(text)")
        return nil
    }

    /// 搜索单词（返回多个结果）
    func searchWords(text: String, limit: Int = 20) throws -> [WordData] {
        guard let conn = db else {
            let error = NSError(domain: "DBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not initialized"])
            Logger.error("Database not initialized", error: error)
            throw error
        }

        var results: [WordData] = []
        let lowercasedText = text.lowercased()

        // 1. 精确匹配（不区分大小写）
        let exactQuery = words.filter(self.text.lowercaseString == lowercasedText).limit(1)
        for result in try conn.prepare(exactQuery) {
            results.append(createWordData(from: result))
        }

        // 2. 前缀匹配（不区分大小写）
        let prefixQuery = words.filter(self.text.lowercaseString.like(lowercasedText + "%")).limit(limit)
        for result in try conn.prepare(prefixQuery) {
            let wordData = createWordData(from: result)
            if !results.contains(where: { $0.text == wordData.text }) {
                results.append(wordData)
            }
        }

        // 3. 包含匹配（不区分大小写）
        let containsQuery = words.filter(self.text.lowercaseString.like("%" + lowercasedText + "%")).limit(limit)
        for result in try conn.prepare(containsQuery) {
            let wordData = createWordData(from: result)
            if !results.contains(where: { $0.text == wordData.text }) {
                results.append(wordData)
            }
        }

        Logger.info("🔍 搜索 '\(text)' 找到 \(results.count) 个结果")
        return Array(results.prefix(limit))
    }

    /// 辅助方法：从数据库结果创建 WordData
    private func createWordData(from result: Row) -> WordData {
        return WordData(
            id: result[self.id],
            text: result[self.text],
            ipa: result[self.ipa],
            meanings: result[self.meanings],
            examples: result[self.examples],
            chineseExamples: result[self.chineseExamples],
            roots: result[self.roots],
            isLearned: result[self.isLearned] ?? false,
            learnedAt: result[self.learnedAt],
            masteryLevel: result[self.masteryLevel] ?? 0,
            reviewCount: result[self.reviewCount] ?? 0,
            correctCount: result[self.correctCount] ?? 0,
            incorrectCount: result[self.incorrectCount] ?? 0,
            ef: result[self.ef] ?? 2.5,
            interval: result[self.interval] ?? 0,
            reps: result[self.reps] ?? 0,
            nextReview: result[self.nextReviewAt] ?? Date()
        )
    }

    /// 获取总单词数
    func getTotalWordCount() throws -> Int {
        guard let conn = db else { return 0 }
        return try conn.scalar(words.count)
    }
    
    // MARK: - 数据库统计信息
    
    /// 获取数据库统计信息
    func getDatabaseStats() throws -> (databaseName: String, totalWords: Int64, learnedWords: Int64, unlearnedWords: Int64, lastUpdated: Date)? {
        guard let conn = db else { return nil }
        
        do {
            let query = try conn.prepare(databaseStats.filter(idStat == 1))
            if let stat = query.makeIterator().next() {
                return (
                    databaseName: stat[databaseName],
                    totalWords: stat[totalWords],
                    learnedWords: stat[learnedWords],
                    unlearnedWords: stat[unlearnedWords],
                    lastUpdated: stat[lastUpdated]
                )
            }
        } catch {
            Logger.warning("Failed to get database stats: \(error)")
        }
        
        return nil
    }
    
    /// 更新已学习单词数量
    func updateLearnedWordsCount(learnedCount: Int64) throws {
        guard let conn = db else {
            let error = NSError(domain: "DBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not initialized"])
            Logger.error("Database not initialized", error: error)
            throw error
        }
        
        // 检查是否存在统计记录
        let statsQuery = try conn.prepare(databaseStats.filter(idStat == 1))
        var hasStats = false
        for _ in statsQuery {
            hasStats = true
            break
        }
        
        if hasStats {
            // 更新现有记录
            let totalCount = try getTotalWordCount()
            let unlearnedCount = Int64(totalCount) - learnedCount
            let updateQuery = databaseStats.filter(idStat == 1).update(
                learnedWords <- learnedCount,
                unlearnedWords <- unlearnedCount,
                lastUpdated <- Date()
            )
            try conn.run(updateQuery)
        } else {
            // 插入新记录
            let totalCount = try getTotalWordCount()
            let unlearnedCount = Int64(totalCount) - learnedCount
            let insertQuery = databaseStats.insert(
                idStat <- 1,
                databaseName <- "CET-4 词库",
                totalWords <- Int64(totalCount),
                learnedWords <- learnedCount,
                unlearnedWords <- unlearnedCount,
                lastUpdated <- Date()
            )
            try conn.run(insertQuery)
        }
        
        Logger.success("Updated stats: learned=\(learnedCount)")
    }

    // MARK: - 学习统计更新
    
    /// 更新单词的学习状态（直接写入 SQLite）
    func updateWordLearningStatus(text: String, quality: Int, attemptType: String) throws {
        guard let conn = db else {
            let error = NSError(domain: "DBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not initialized"])
            Logger.error("Database not initialized", error: error)
            throw error
        }
        
        Logger.debug("开始更新单词 \(text) 的学习状态，quality: \(quality)")
        
        // 先查询当前值
        let query = try conn.prepare(words.filter(self.text == text))
        let iterator = query.makeIterator()
        guard let currentWord = iterator.next() else {
            let error = NSError(domain: "DBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Word not found: \(text)"])
            Logger.error("Word not found: \(text)", error: error)
            throw error
        }
        
        // 从数据库读取当前值，使用 ?? 0 处理 NULL 值（符合记忆规范）
        let currentReviewCount = currentWord[reviewCount] ?? 0
        let currentCorrectCount = currentWord[correctCount] ?? 0
        let currentIncorrectCount = currentWord[incorrectCount] ?? 0
        let currentMasteryLevel = currentWord[masteryLevel] ?? 0
        let currentEf = currentWord[ef] ?? 2.5  // SM2 默认 EF 值
        let currentInterval = currentWord[interval] ?? 0
        let currentReps = currentWord[reps] ?? 0
        
        Logger.debug("单词 \(text) 当前状态：review=\(currentReviewCount), correct=\(currentCorrectCount), incorrect=\(currentIncorrectCount), mastery=\(currentMasteryLevel), ef=\(currentEf), interval=\(currentInterval), reps=\(currentReps)")
        
        // 使用 LearningService 计算新的学习状态
        let currentStats = WordLearningStats(
            isLearned: currentWord[isLearned] ?? false,
            learnedAt: currentWord[learnedAt],
            masteryLevel: currentMasteryLevel,
            reviewCount: currentReviewCount,
            correctCount: currentCorrectCount,
            incorrectCount: currentIncorrectCount,
            lastReviewedAt: currentWord[lastReviewedAt],
            nextReviewAt: currentWord[nextReviewAt] ?? Date(),
            ef: currentEf,
            interval: currentInterval,
            reps: currentReps
        )
        
        let newStats = LearningService.shared.calculateNewLearningStats(
            currentStats: currentStats,
            quality: quality
        )
        
        // 更新数据库
        let updateQuery = words.filter(self.text == text).update(
            isLearned <- true,
            learnedAt <- Date(),
            masteryLevel <- newStats.masteryLevel,
            reviewCount <- newStats.reviewCount,
            correctCount <- newStats.correctCount,
            incorrectCount <- newStats.incorrectCount,
            lastReviewedAt <- Date(),
            nextReviewAt <- newStats.nextReviewAt,
            ef <- newStats.ef,
            interval <- newStats.interval,
            reps <- newStats.reps
        )
        
        try conn.run(updateQuery)
        Logger.success("成功更新单词 \(text) 的学习状态")
    }
    
    /// 更新单词的复习统计
    func updateWordReviewStats(text: String, correct: Bool) throws {
        guard let conn = db else {
            let error = NSError(domain: "DBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not initialized"])
            Logger.error("Database not initialized", error: error)
            throw error
        }
        
        // 先查询当前值
        let query = try conn.prepare(words.filter(self.text == text))
        let iterator = query.makeIterator()
        guard let currentWord = iterator.next() else {
            let error = NSError(domain: "DBError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Word not found: \(text)"])
            Logger.error("Word not found: \(text)", error: error)
            throw error
        }
        
        // 从数据库读取当前值，使用 ?? 0 处理 NULL 值（符合记忆规范）
        let currentReviewCount = currentWord[reviewCount] ?? 0
        let currentCorrectCount = currentWord[correctCount] ?? 0
        let currentIncorrectCount = currentWord[incorrectCount] ?? 0
        let currentMasteryLevel = currentWord[masteryLevel] ?? 0
        let currentEf = currentWord[ef] ?? 2.5  // SM2 默认 EF 值
        let currentInterval = currentWord[interval] ?? 0
        let currentReps = currentWord[reps] ?? 0
        
        Logger.debug("单词 \(text) 当前状态：review=\(currentReviewCount), correct=\(currentCorrectCount), incorrect=\(currentIncorrectCount), mastery=\(currentMasteryLevel), ef=\(currentEf), interval=\(currentInterval), reps=\(currentReps)")
        
        // 使用 LearningService 计算新的复习状态
        let currentStats = WordLearningStats(
            isLearned: currentWord[isLearned] ?? false,
            learnedAt: currentWord[learnedAt],
            masteryLevel: currentMasteryLevel,
            reviewCount: currentReviewCount,
            correctCount: currentCorrectCount,
            incorrectCount: currentIncorrectCount,
            lastReviewedAt: currentWord[lastReviewedAt],
            nextReviewAt: currentWord[nextReviewAt] ?? Date(),
            ef: currentEf,
            interval: currentInterval,
            reps: currentReps
        )
        
        let newStats = LearningService.shared.calculateNewReviewStats(
            currentStats: currentStats,
            correct: correct
        )
        
        let updateQuery = words.filter(self.text == text).update(
            self.reviewCount <- newStats.reviewCount,
            self.correctCount <- newStats.correctCount,
            self.incorrectCount <- newStats.incorrectCount,
            self.masteryLevel <- newStats.masteryLevel,
            self.ef <- newStats.ef,
            self.interval <- newStats.interval,
            self.reps <- newStats.reps,
            self.lastReviewedAt <- Date(),
            self.nextReviewAt <- newStats.nextReviewAt
        )
        try conn.run(updateQuery)
        Logger.success("成功更新单词 \(text) 的复习统计")
    }
    
    /// 获取单词的学习统计信息
    func getWordLearningStats(text: String) throws -> (
        isLearned: Bool?,
        learnedAt: Date?,
        masteryLevel: Int64?,
        reviewCount: Int64?,
        correctCount: Int64?,
        incorrectCount: Int64?,
        lastReviewedAt: Date?,
        nextReviewAt: Date?,
        ef: Double?,
        interval: Int64?,
        reps: Int64?
    )? {
        guard let conn = db else { return nil }
        
        let query = try conn.prepare(words.filter(self.text == text))
        let iterator = query.makeIterator()
        guard let currentWord = iterator.next() else {
            return nil
        }
        
        return (
            isLearned: currentWord[isLearned],
            learnedAt: currentWord[learnedAt],
            masteryLevel: currentWord[masteryLevel],
            reviewCount: currentWord[reviewCount],
            correctCount: currentWord[correctCount],
            incorrectCount: currentWord[incorrectCount],
            lastReviewedAt: currentWord[lastReviewedAt],
            nextReviewAt: currentWord[nextReviewAt],
            ef: currentWord[ef],
            interval: currentWord[interval],
            reps: currentWord[reps]
        )
    }
    
}
