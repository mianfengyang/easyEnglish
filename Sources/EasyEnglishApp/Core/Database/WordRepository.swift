import Foundation
import SQLite

final class WordRepository: WordRepositoryProtocol {
    private let db: DatabaseManager
    
    init(db: DatabaseManager = .shared) {
        self.db = db
    }
    
    func getNewWords(count: Int) async throws -> [Word] {
        guard db.connection != nil else { throw DatabaseError.notInitialized }
        let sql = "SELECT * FROM words WHERE is_learned IS NULL OR is_learned = 0 ORDER BY RANDOM() LIMIT \(count)"
        return try await fetchWords(sql: sql)
    }

    func getRandomWords(count: Int) async throws -> [Word] {
        guard db.connection != nil else { throw DatabaseError.notInitialized }
        let sql = "SELECT * FROM words ORDER BY RANDOM() LIMIT \(count)"
        return try await fetchWords(sql: sql)
    }
    
    func getReviewWords(count: Int) async throws -> [Word] {
        guard db.connection != nil else { throw DatabaseError.notInitialized }
        let sql = "SELECT * FROM words WHERE is_learned = 1 AND next_review_at <= datetime('now') ORDER BY next_review_at ASC LIMIT \(count)"
        return try await fetchWords(sql: sql)
    }
    
    // 混合加载：新单词 + 复习单词（SM-2算法调度）
    func getMixedWords(count: Int, newWordRatio: Double = 0.7) async throws -> MixedWordsResult {
        guard db.connection != nil else { throw DatabaseError.notInitialized }

        let newQuota = Int(Double(count) * newWordRatio)
        let reviewQuota = count - newQuota

        // 获取新单词
        var words: [Word] = []
        var actualNewCount = 0
        let newSql = "SELECT * FROM words WHERE is_learned IS NULL OR is_learned = 0 ORDER BY RANDOM() LIMIT \(newQuota)"
        let newWords = try await fetchWords(sql: newSql)
        actualNewCount = newWords.count
        words.append(contentsOf: newWords)

        // 获取复习单词
        var actualReviewCount = 0
        if reviewQuota > 0 {
            let reviewSql = "SELECT * FROM words WHERE is_learned = 1 AND next_review_at <= datetime('now') ORDER BY next_review_at ASC LIMIT \(reviewQuota)"
            let reviewWords = try await fetchWords(sql: reviewSql)
            actualReviewCount = reviewWords.count
            words.append(contentsOf: reviewWords)
        }

        // 如果混合加载没拿到单词，回退到随机词
        if words.isEmpty {
            words = try await getRandomWords(count: count)
        }

        // 记录学习会话拆分（实际加载的新词/复习词数量）
        let startOfDay = Calendar.current.startOfDay(for: Date())
        saveSessionStats(date: startOfDay, mixedCount: words.count, newCount: actualNewCount, reviewCount: actualReviewCount)

        // 打乱顺序
        return MixedWordsResult(words: words.shuffled(), newCount: actualNewCount, reviewCount: actualReviewCount)
    }

    func getMixedWordsByDay(day: Date, count: Int, newWordRatio: Double = 0.7) async throws -> MixedWordsResult {
        guard db.connection != nil else { throw DatabaseError.notInitialized }

        let newCount = Int(Double(count) * newWordRatio)
        let reviewCount = count - newCount
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dayStart = Calendar.current.startOfDay(for: day)
        let dayStartStr = dateFormatter.string(from: dayStart)
        let dayEndStr = dateFormatter.string(from: dayStart + 86400)

        var words: [Word] = []
        let newSql = "SELECT * FROM words WHERE is_learned IS NULL OR is_learned = 0 ORDER BY RANDOM() LIMIT \(newCount)"
        words.append(contentsOf: try await fetchWords(sql: newSql))

        var actualReviewCount = 0
        if reviewCount > 0 {
            let reviewSql = "SELECT * FROM words WHERE is_learned = 1 AND next_review_at <= '\(dayEndStr)' AND next_review_at > '\(dayStartStr)' ORDER BY next_review_at ASC LIMIT \(reviewCount)"
            let reviewWords = try await fetchWords(sql: reviewSql)
            actualReviewCount = reviewWords.count
            words.append(contentsOf: reviewWords)
        }

        return MixedWordsResult(words: words.shuffled(), newCount: newCount, reviewCount: actualReviewCount)
    }

    private func saveSessionStats(date: Date, mixedCount: Int, newCount: Int, reviewCount: Int) {
        guard let conn = db.connection else { return }
        
        // 表可能不存在（旧数据库），先尝试建表
        _ = try? conn.run("CREATE TABLE IF NOT EXISTS learning_session_stats (" +
            "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
            "session_date DATE, mixed_count INTEGER, " +
            "new_count INTEGER, review_count INTEGER)")
        
        // 用 datetime('now') 格式存入日期，与 SQLite 内置日期格式保持一致
        // 这样 save 和查询时都使用相同格式，避免 sqlite.swift 的 Date 序列化问题
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: date)
        do {
            try conn.run("INSERT INTO learning_session_stats (session_date, mixed_count, new_count, review_count) " +
                "VALUES ('\(dateStr)', \(mixedCount), \(newCount), \(reviewCount))")
        } catch {
            Logger.warning("保存学习会话统计失败: \(error)")
        }
    }
    
    func getWord(byId id: UUID) async throws -> Word? {
        guard let conn = db.connection else { throw DatabaseError.notInitialized }
        guard let row = try conn.pluck(db.words.filter(db.id == id)) else { return nil }
        return mapRowToWord(row)
    }
    
    func getWord(byText text: String) async throws -> Word? {
        guard let conn = db.connection else { throw DatabaseError.notInitialized }
        guard let row = try conn.pluck(db.words.filter(db.text == text)) else { return nil }
        return mapRowToWord(row)
    }
    
    func searchWords(query: String) async throws -> [Word] {
        guard let conn = db.connection else { throw DatabaseError.notInitialized }
        let dbQuery = db.words
            .filter(db.text.like("%\(query)%") || db.meanings.like("%\(query)%"))
            .limit(50)
        return try conn.prepare(dbQuery).map { mapRowToWord($0) }
    }
    
    func updateLearningStatus(wordText: String, quality: Int) async throws {
        guard let conn = db.connection else { throw DatabaseError.notInitialized }
        
        guard let currentRow = try conn.pluck(db.words.filter(db.text == wordText)) else {
            throw DatabaseError.wordNotFound(wordText)
        }
        
        let currentReps = currentRow[db.reps] ?? 0
        let currentInterval = currentRow[db.interval] ?? 0
        let currentEf = currentRow[db.ef] ?? 2.5
        let wasLearned = currentRow[db.isLearned] ?? false
        
        let isCorrect = quality >= 3
        let newReps = isCorrect ? (currentReps + 1) : 0
        var newInterval: Int64 = 0
        if isCorrect {
            switch newReps {
            case 1: newInterval = 1
            case 2: newInterval = 3
            default: newInterval = Int64(Double(currentInterval) * currentEf)
            }
        } else { newInterval = 1 }
        
        let newEf = max(1.3, currentEf + (isCorrect ? 0.1 : -0.2))
        let nextReviewDate = calculateNextReviewDate(interval: newInterval, reps: newReps)
        
        let currentMastery = currentRow[db.masteryLevel] ?? 0
        let newMastery = isCorrect ? min(5, currentMastery + 1) : max(0, currentMastery - 1)
        
        let currentReviewCount = currentRow[db.reviewCount] ?? 0
        let currentCorrectCount = currentRow[db.correctCount] ?? 0
        let currentIncorrectCount = currentRow[db.incorrectCount] ?? 0
        
        // 更新：如果是新单词则设置learned_at，复习单词不更新
        var updates: [Setter] = [
            db.isLearned <- true,
            db.masteryLevel <- newMastery,
            db.reviewCount <- Int64(currentReviewCount + 1),
            db.correctCount <- Int64(isCorrect ? (currentCorrectCount + 1) : currentCorrectCount),
            db.incorrectCount <- Int64(isCorrect ? currentIncorrectCount : (currentIncorrectCount + 1)),
            db.lastReviewedAt <- Date(),
            db.nextReviewAt <- nextReviewDate,
            db.ef <- newEf,
            db.interval <- newInterval,
            db.reps <- newReps
        ]
        
        // 只有从未学过的单词才设置 learned_at
        if !wasLearned {
            updates.append(db.learnedAt <- Date())
        }
        
        try conn.run(db.words.filter(db.text == wordText).update(updates))
    }
    
    func getTotalCount() async throws -> Int {
        guard let conn = db.connection else { throw DatabaseError.notInitialized }
        return try conn.scalar(db.words.count)
    }
    
    func getLearnedCount() async throws -> Int64 {
        guard let conn = db.connection else { throw DatabaseError.notInitialized }
        let sql = "SELECT COUNT(*) FROM words WHERE learned_at IS NOT NULL OR review_count > 0 OR is_learned = 1"
        return try conn.scalar(sql) as? Int64 ?? 0
    }
    
    func getDailyStats() async throws -> DailyStats {
        guard let conn = db.connection else { throw DatabaseError.notInitialized }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startDateStr = dateFormatter.string(from: startOfDay)
        let endDateStr = dateFormatter.string(from: startOfDay.addingTimeInterval(86400))

        // 1) 新学单词：当天 learned_at 落在今天范围的单词数
        let newSql = "SELECT COUNT(*) FROM words WHERE is_learned = 1 AND learned_at >= '\(startDateStr)' AND learned_at < '\(endDateStr)'"
        let newWords = try conn.scalar(newSql) as? Int64 ?? 0

        // 2) 复习单词：从学习会话统计表累加所有会话的 review_count
        // 统一用 strftime 格式化日期进行比较，避免 sqlite.swift Date 序列化问题
        var reviews: Int64 = 0
        do {
            let sql = "SELECT SUM(review_count) FROM learning_session_stats " +
                "WHERE strftime('%Y-%m-%d', session_date) = strftime('%Y-%m-%d', 'now')"
            reviews = (try conn.scalar(sql) as? Int64) ?? 0
        } catch {
            Logger.warning("查询会话统计失败: \(error)")
        }

        // 3) 正确率：当天被复习过的单词的正确率（基于复习记录）
        let rateSql = """
            SELECT AVG(CASE WHEN review_count > 0 THEN CAST(correct_count AS REAL) / review_count ELSE NULL END)
            FROM words WHERE is_learned = 1 AND review_count > 0 AND last_reviewed_at >= '\(startDateStr)' AND last_reviewed_at < '\(endDateStr)'
        """
        let correctRate = (try conn.scalar(rateSql) as? Double ?? 0.0) * 100.0

        return DailyStats(date: Date(), newWords: newWords, reviews: reviews, correctRate: min(100.0, max(0.0, correctRate)))
    }
    
    func getMasteryDistribution() async throws -> [MasteryDistribution] {
        guard let conn = db.connection else { throw DatabaseError.notInitialized }
        
        let sql = "SELECT mastery_level, COUNT(*) as cnt FROM words GROUP BY mastery_level ORDER BY mastery_level ASC"
        var results: [MasteryDistribution] = []
        let rowIterator = try conn.prepareRowIterator(sql)
        while let row = rowIterator.next() {
            if let level = row[Expression<Int64?>("mastery_level")], let cnt = row[Expression<Int64?>("cnt")] {
                results.append(MasteryDistribution(level: Int(level), count: cnt))
            }
        }
        
        // 确保返回 level 0-5 的所有档位，缺失的用 count=0 补齐
        while results.count < 6 {
            results.append(MasteryDistribution(level: results.count, count: 0))
        }
        
        return results.sorted { $0.level < $1.level }
    }
    
    func getWeeklyTrend(weeks: Int) async throws -> [WeeklyTrend] {
        guard let conn = db.connection else { throw DatabaseError.notInitialized }
        
        // 使用 ISO8601 格式的日期字符串
        let startDate = Calendar.current.date(byAdding: .day, value: -(weeks * 7), to: Date()) ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startDateStr = dateFormatter.string(from: startDate)
        
        let sql = """
            SELECT strftime('%Y-%m-%d', last_reviewed_at) as review_date,
                   COUNT(*) as total_reviews,
                   AVG(mastery_level) as avg_mastery
            FROM words
            WHERE last_reviewed_at IS NOT NULL AND is_learned = 1
              AND last_reviewed_at >= '\(startDateStr)'
            GROUP BY strftime('%Y-%m-%d', last_reviewed_at)
            ORDER BY review_date ASC
        """
        
        var results: [WeeklyTrend] = []
        let rowIterator = try conn.prepareRowIterator(sql)
        
        while let row = rowIterator.next() {
            guard let dateStr = row[Expression<String?>("review_date")] else { continue }
            
            var avgMastery: Double = 0.0
            if let m = row[Expression<Double?>("avg_mastery")] {
                avgMastery = m
            }
            
            // dateStr 格式为 "2024-01-15"，手动解析
            let components = dateStr.split(separator: "-")
            guard components.count == 3,
                  let year = Int(components[0]),
                  let month = Int(components[1]),
                  let day = Int(components[2]) else { continue }
            
            var dateComponents = DateComponents()
            dateComponents.year = year
            dateComponents.month = month
            dateComponents.day = day
            if let parsedDate = Calendar.current.date(from: dateComponents) {
                results.append(WeeklyTrend(date: parsedDate, avgMastery: min(5.0, max(0.0, avgMastery))))
            }
        }
        
        return results
    }
    
    // 获取熟练掌握和快要忘记的统计
    func getMasteryTrend() async throws -> MasteryTrend {
        guard let conn = db.connection else { throw DatabaseError.notInitialized }
        
        // 熟练掌握：mastery_level >= 4
        let masteredSql = "SELECT COUNT(*) FROM words WHERE is_learned = 1 AND mastery_level >= 4"
        let masteredCount = try conn.scalar(masteredSql) as? Int64 ?? 0
        
        // 快要忘记：3天内需要复习的 (next_review_at <= 3天后)
        let threeDaysLater = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let endDateStr = dateFormatter.string(from: threeDaysLater)
        
        let forgettingSql = "SELECT COUNT(*) FROM words WHERE is_learned = 1 AND next_review_at <= '\(endDateStr)' AND next_review_at > datetime('now')"
        let forgettingCount = try conn.scalar(forgettingSql) as? Int64 ?? 0
        
        return MasteryTrend(masteredCount: masteredCount, forgettingCount: forgettingCount)
    }
    
    func getRecentWords(limit: Int) async throws -> [Word] {
        guard let conn = db.connection else { throw DatabaseError.notInitialized }
        
        let query = db.words.filter(db.isLearned == true)
            .order(db.lastReviewedAt.desc)
            .limit(limit)
        return try conn.prepare(query).map { mapRowToWord($0) }
    }
    
    // MARK: - Private Helpers
    
    private func fetchWords(sql: String) async throws -> [Word] {
        guard let conn = db.connection else { throw DatabaseError.notInitialized }
        var results: [Word] = []
        let rowIterator = try conn.prepareRowIterator(sql)
        while let row = rowIterator.next() {
            results.append(mapRowToWordData(row))
        }
        return results
    }
    
    private func mapRowToWord(_ row: Row) -> Word {
        Word(
            id: row[db.id],
            text: row[db.text],
            ipa: row[db.ipa],
            meanings: row[db.meanings],
            examples: row[db.examples],
            chineseExamples: row[db.chineseExamples],
            roots: row[db.roots],
            isLearned: row[db.isLearned] ?? false,
            learnedAt: row[db.learnedAt],
            masteryLevel: row[db.masteryLevel] ?? 0,
            reviewCount: row[db.reviewCount] ?? 0,
            correctCount: row[db.correctCount] ?? 0,
            incorrectCount: row[db.incorrectCount] ?? 0,
            lastReviewedAt: row[db.lastReviewedAt],
            nextReviewAt: row[db.nextReviewAt],
            ef: row[db.ef] ?? 2.5,
            interval: row[db.interval] ?? 0,
            reps: row[db.reps] ?? 0
        )
    }
    
    private func mapRowToWordData(_ row: Row) -> Word {
        Word(
            id: row[db.id],
            text: row[db.text],
            ipa: row[db.ipa],
            meanings: row[db.meanings],
            examples: row[db.examples],
            chineseExamples: row[db.chineseExamples],
            roots: row[db.roots],
            isLearned: row[db.isLearned] ?? false,
            learnedAt: row[db.learnedAt],
            masteryLevel: row[db.masteryLevel] ?? 0,
            reviewCount: row[db.reviewCount] ?? 0,
            correctCount: row[db.correctCount] ?? 0,
            incorrectCount: row[db.incorrectCount] ?? 0,
            lastReviewedAt: row[db.lastReviewedAt],
            nextReviewAt: row[db.nextReviewAt],
            ef: row[db.ef] ?? 2.5,
            interval: row[db.interval] ?? 0,
            reps: row[db.reps] ?? 0
        )
    }
    
    private func calculateNextReviewDate(interval: Int64, reps: Int64) -> Date {
        // 新学完的词立即进入复习池（当天即可复习）
        return Date()
    }
}
