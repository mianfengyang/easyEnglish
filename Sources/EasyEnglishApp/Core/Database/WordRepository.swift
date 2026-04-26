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
        guard let conn = db.connection else { throw DatabaseError.notInitialized }
        let query = db.words
            .filter(db.isLearned == true && db.nextReviewAt <= Date())
            .order(db.nextReviewAt.asc)
            .limit(count)
        return try conn.prepare(query).map { mapRowToWord($0) }
    }
    
    // 混合加载：新单词 + 复习单词（SM-2算法调度）
    func getMixedWords(count: Int, newWordRatio: Double = 0.7) async throws -> [Word] {
        guard let conn = db.connection else { throw DatabaseError.notInitialized }
        
        let newCount = Int(Double(count) * newWordRatio)
        let reviewCount = count - newCount
        
        // 获取新单词
        var words: [Word] = []
        let newSql = "SELECT * FROM words WHERE is_learned IS NULL OR is_learned = 0 ORDER BY RANDOM() LIMIT \(newCount)"
        words.append(contentsOf: try await fetchWords(sql: newSql))
        
        // 如果需要复习单词
        if reviewCount > 0 {
            let reviewSql = "SELECT * FROM words WHERE is_learned = 1 AND next_review_at <= datetime('now') ORDER BY next_review_at ASC LIMIT \(reviewCount)"
            let reviewWords = try await fetchWords(sql: reviewSql)
            words.append(contentsOf: reviewWords)
        }
        
        // 打乱顺序
        return words.shuffled()
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

        // 使用 ISO8601 格式的日期字符串进行查询
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startDateStr = dateFormatter.string(from: startOfDay)
        let endDateStr = dateFormatter.string(from: startOfDay.addingTimeInterval(86400))
        
        // 1) 先尝试从 daily_stats 缓存表读取（若存在）
        do {
            let dailyExists = try conn.scalar("SELECT count(*) FROM sqlite_master WHERE type='table' AND name='daily_stats'") as? Int64 ?? 0
            if dailyExists > 0 {
                let dailyStatsTable = Table("daily_stats")
                let dsDate = Expression<Date>("date")
                let dsNew = Expression<Int64>("new_words")
                let dsRev = Expression<Int64>("reviews")
                let dsRate = Expression<Double>("correct_rate")
                if let row = try conn.pluck(dailyStatsTable.select(dsDate, dsNew, dsRev, dsRate).order(dsDate.desc).limit(1)) {
                    let date = row[dsDate]
                    let newW: Int64 = row[dsNew]
                    let rev: Int64 = row[dsRev]
                    let rate: Double = row[dsRate]
                    return DailyStats(date: date, newWords: newW, reviews: rev, correctRate: rate)
                }
            }
        } catch {
            // 忽略缓存读取错误，回退计算
        }

        // 2) 回退到基于 Words 表的统计计算
        // 新学单词：当天学习的单词（is_learned=1 且 learned_at=今天）
        let newSql = "SELECT COUNT(*) FROM words WHERE is_learned = 1 AND learned_at >= '\(startDateStr)' AND learned_at < '\(endDateStr)'"
        var newWords = try conn.scalar(newSql) as? Int64 ?? 0
        
        // 复习单词：当天复习的单词（之前已学习，今天又复习了）
        // 即 learned_at < 今天 且 last_reviewed_at = 今天
        let reviewSql = "SELECT COUNT(*) FROM words WHERE is_learned = 1 AND learned_at < '\(startDateStr)' AND last_reviewed_at >= '\(startDateStr)' AND last_reviewed_at < '\(endDateStr)'"
        var reviews = try conn.scalar(reviewSql) as? Int64 ?? 0
        
        // 如果当天没有学习，显示历史累计（新学=已学习总数，复习=0）
        let totalLearned = try conn.scalar("SELECT COUNT(*) FROM words WHERE is_learned = 1") as? Int64 ?? 0
        if newWords == 0 { newWords = totalLearned }
        if reviews == 0 { reviews = 0 }
        
        // 正确率：当天复习的单词的正确率
        let rateSql = """
            SELECT AVG(CASE WHEN review_count > 0 THEN CAST(correct_count AS REAL) / review_count ELSE NULL END)
            FROM words WHERE is_learned = 1 AND review_count > 0 AND last_reviewed_at >= '\(startDateStr)' AND last_reviewed_at < '\(endDateStr)'
        """
        var correctRate = (try conn.scalar(rateSql) as? Double ?? 0.0) * 100.0
        
        // 如果当天没有复习数据，显示全局正确率
        if correctRate == 0 {
            let globalRateSql = """
                SELECT AVG(CASE WHEN review_count > 0 THEN CAST(correct_count AS REAL) / review_count ELSE NULL END)
                FROM words WHERE is_learned = 1 AND review_count > 0
            """
            correctRate = (try conn.scalar(globalRateSql) as? Double ?? 0.0) * 100.0
        }
        
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
        let secondsPerDay: TimeInterval = 86400
        if reps <= 1 {
            let intervalInSeconds: TimeInterval = (reps == 0) ? 3600 : 86400
            return Date().addingTimeInterval(intervalInSeconds)
        } else {
            return Date().addingTimeInterval(Double(interval) * secondsPerDay)
        }
    }
}
