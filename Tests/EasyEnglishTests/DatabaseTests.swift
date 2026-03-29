import XCTest
import SQLite
@testable import EasyEnglish

/// SQLite 数据库操作单元测试
final class DatabaseTests: XCTestCase {
    
    var testDBPath: String!
    var db: Connection!
    
    // 表列定义
    lazy var words = Table("words")
    lazy var id = Expression<UUID>("id")
    lazy var text = Expression<String>("text")
    lazy var ipa = Expression<String?>("ipa")
    lazy var meanings = Expression<String?>("meanings")
    lazy var examples = Expression<String?>("examples")
    lazy var chineseExamples = Expression<String?>("chineseExamples")
    lazy var roots = Expression<String?>("roots")
    lazy var isLearned = Expression<Bool?>("is_learned")
    lazy var learnedAt = Expression<Date?>("learned_at")
    lazy var masteryLevel = Expression<Int64>("mastery_level")
    lazy var reviewCount = Expression<Int64>("review_count")
    lazy var correctCount = Expression<Int64>("correct_count")
    lazy var incorrectCount = Expression<Int64>("incorrect_count")
    lazy var lastReviewedAt = Expression<Date?>("last_reviewed_at")
    lazy var nextReviewAt = Expression<Date?>("next_review_at")
    lazy var ef = Expression<Double>("ef")
    lazy var interval = Expression<Int64>("interval")
    lazy var reps = Expression<Int64>("reps")
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 创建临时测试数据库
        testDBPath = NSTemporaryDirectory() + "test_wordlist_\(UUID().uuidString).sqlite"
        
        // 清理旧文件
        try? FileManager.default.removeItem(atPath: testDBPath)
        
        db = try Connection(testDBPath)
        try createTestTable()
        try seedTestData()
    }
    
    override func tearDown() async throws {
        // 清理测试数据库
        try? FileManager.default.removeItem(atPath: testDBPath)
        try await super.tearDown()
    }
    
    // MARK: - 测试表结构
    
    func testTableCreation() throws {
        let exists = try checkTableExists(tableName: "words")
        XCTAssertTrue(exists, "words 表应该存在")
    }
    
    func testTableSchema() throws {
        let count = try db.scalar(words.count)
        XCTAssertEqual(count, 10, "应该有 10 条测试数据")
    }
    
    // MARK: - 查询测试
    
    func testGetTotalWordCount() throws {
        let count = try db.scalar(words.count)
        XCTAssertEqual(count, 10, "总单词数应该是 10")
    }
    
    func testGetRandomWords() throws {
        let query = words.order(Expression<Int>.random()).limit(5)
        let results = try db.prepare(query)
        var count = 0
        for _ in results {
            count += 1
        }
        XCTAssertEqual(count, 5, "应该返回 5 个随机单词")
    }
    
    func testGetWordByText() throws {
        let word = try db.first(words.filter(text == "testword1"))
        XCTAssertNotNil(word, "应该能找到 testword1")
        XCTAssertEqual(word?[text], "testword1")
    }
    
    func testGetWordByUUID() throws {
        let testUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let word = try db.first(words.filter(id == testUUID))
        XCTAssertNotNil(word, "应该能通过 UUID 找到单词")
    }
    
    // MARK: - 学习状态测试
    
    func testUpdateLearningStatus() throws {
        let testUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        
        // 初始状态
        let word = try db.first(words.filter(id == testUUID))!
        let initialIsLearned = word[isLearned]
        XCTAssertNil(initialIsLearned, "初始 is_learned 应该是 NULL")
        
        // 更新学习状态
        let updateQuery = words.filter(id == testUUID).update(
            isLearned <- true,
            learnedAt <- Date(),
            masteryLevel <- 1,
            reviewCount <- 1,
            correctCount <- 1,
            incorrectCount <- 0
        )
        try db.run(updateQuery)
        
        // 验证更新
        let updatedWord = try db.first(words.filter(id == testUUID))!
        XCTAssertEqual(updatedWord[isLearned], true)
        XCTAssertEqual(updatedWord[masteryLevel], 1)
        XCTAssertEqual(updatedWord[reviewCount], 1)
    }
    
    func testSM2Calculation() throws {
        let testUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        
        // 初始 EF = 2.5, reps = 0, interval = 0
        try updateWordStats(id: testUUID, quality: 5)
        
        let word = try db.first(words.filter(id == testUUID))!
        XCTAssertEqual(word[reps], 1, "reps 应该为 1")
        XCTAssertEqual(word[interval], 1, "interval 应该为 1")
        XCTAssertGreaterThanOrEqual(word[ef], 2.5, "EF 应该增加")
    }
    
    func testMultipleReviews() throws {
        let testUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        
        // 连续 3 次正确回忆
        for _ in 0..<3 {
            try updateWordStats(id: testUUID, quality: 5)
        }
        
        let word = try db.first(words.filter(id == testUUID))!
        XCTAssertEqual(word[reps], 3, "reps 应该为 3")
        XCTAssertGreaterThan(word[interval], 1, "interval 应该增长")
    }
    
    func testFailureReset() throws {
        let testUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        
        // 先成功 2 次
        try updateWordStats(id: testUUID, quality: 5)
        try updateWordStats(id: testUUID, quality: 5)
        
        // 然后失败
        try updateWordStats(id: testUUID, quality: 0)
        
        let word = try db.first(words.filter(id == testUUID))!
        XCTAssertEqual(word[reps], 0, "失败应该重置 reps")
        XCTAssertEqual(word[interval], 1, "失败应该重置 interval")
    }
    
    // MARK: - 索引测试
    
    func testTextIndex() throws {
        // 创建索引
        try db.run(words.createIndex(text, unique: true))
        
        // 插入重复文本应该失败
        let duplicateUUID = UUID()
        let insert = words.insert(
            id <- duplicateUUID,
            text <- "testword1", // 重复
            ipa <- "/test/"
        )
        
        XCTAssertThrowsError(try db.run(insert), "插入重复文本应该抛出错误")
    }
    
    // MARK: - 性能测试
    
    func testBulkInsertPerformance() throws {
        let count = 1000
        let start = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<count {
            let uuid = UUID()
            let insert = words.insert(
                DatabaseTests.id <- uuid,
                DatabaseTests.text <- "bulkword\(i)",
                DatabaseTests.ipa <- "/test/"
            )
            try db.run(insert)
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - start
        print("批量插入 \(count) 条记录耗时：\(duration.formatted(.number.precision(.significantDigits(3)))) 秒")
        XCTAssertLessThan(duration, 10.0, "批量插入应该在 10 秒内完成")
    }
    
    func testTransactionPerformance() throws {
        let count = 1000
        let start = CFAbsoluteTimeGetCurrent()
        
        try db.transaction(.deferred) {
            for i in 0..<count {
                let uuid = UUID()
                let insert = words.insert(
                    DatabaseTests.id <- uuid,
                    DatabaseTests.text <- "txnword\(i)",
                    DatabaseTests.ipa <- "/test/"
                )
                try db.run(insert)
            }
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - start
        print("事务批量插入 \(count) 条记录耗时：\(duration.formatted(.number.precision(.significantDigits(3)))) 秒")
        XCTAssertLessThan(duration, 5.0, "事务批量插入应该在 5 秒内完成")
    }
    
    // MARK: - 辅助方法
    
    private func createTestTable() throws {
        try db.run(words.create { t in
            t.column(DatabaseTests.id, primaryKey: true)
            t.column(DatabaseTests.text, unique: true)
            t.column(DatabaseTests.ipa)
            t.column(DatabaseTests.meanings)
            t.column(DatabaseTests.examples)
            t.column(DatabaseTests.chineseExamples)
            t.column(DatabaseTests.roots)
            t.column(DatabaseTests.isLearned)
            t.column(DatabaseTests.learnedAt)
            t.column(DatabaseTests.masteryLevel)
            t.column(DatabaseTests.reviewCount)
            t.column(DatabaseTests.correctCount)
            t.column(DatabaseTests.incorrectCount)
            t.column(DatabaseTests.lastReviewedAt)
            t.column(DatabaseTests.nextReviewAt)
            t.column(DatabaseTests.ef)
            t.column(DatabaseTests.interval)
            t.column(DatabaseTests.reps)
        })
    }
    
    private func seedTestData() throws {
        for i in 1...10 {
            let uuid = UUID(uuidString: "00000000-0000-0000-0000-00000000000\(i)")!
            let insert = words.insert(
                id <- uuid,
                text <- "testword\(i)",
                ipa <- "/test\(i)/",
                meanings <- "测试含义\(i)",
                examples <- "Example \(i)",
                chineseExamples <- "例句\(i)",
                roots <- "词根\(i)",
                isLearned <- nil,
                masteryLevel <- 0,
                reviewCount <- 0,
                correctCount <- 0,
                incorrectCount <- 0,
                ef <- 2.5,
                interval <- 0,
                reps <- 0
            )
            try db.run(insert)
        }
    }
    
    private func updateWordStats(id: UUID, quality: Int) throws {
        let word = try db.first(words.filter(self.id == id))!
        
        let currentReps = word[reps]
        let currentInterval = word[interval]
        let currentEf = word[ef]
        
        let correct = quality >= 3
        let newReps = correct ? currentReps + 1 : 0
        let newInterval: Int64
        if correct {
            switch newReps {
            case 1: newInterval = 1
            case 2: newInterval = 6
            default: newInterval = Int64(Double(currentInterval) * currentEf)
            }
        } else {
            newInterval = 1
        }
        
        let newEf = max(1.3, currentEf + 0.1 - (correct ? 0.0 : 0.8) * (0.08 * (5 - Double(currentReps))))
        
        let updateQuery = words.filter(self.id == id).update(
            reps <- newReps,
            interval <- newInterval,
            ef <- newEf,
            reviewCount <- currentReps + 1,
            correctCount <- correct ? word[correctCount] + 1 : word[correctCount],
            incorrectCount <- correct ? word[incorrectCount] : word[incorrectCount] + 1
        )
        try db.run(updateQuery)
    }
    
    private func checkTableExists(tableName: String) throws -> Bool {
        let query = "SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?"
        let result = try db.scalar(query, tableName) as? Int ?? 0
        return result > 0
    }
}



// MARK: - 辅助扩展

private extension Double {
    func formatted(_ style: NumberFormatter.Style) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = style
        return formatter.string(from: self as NSNumber) ?? "\(self)"
    }
}

extension NumberFormatter {
    enum Style {
        case significantDigits(Int)
        
        func format(_ value: Double) -> String {
            let formatter = NumberFormatter()
            if case .significantDigits(let digits) = self {
                formatter.maximumSignificantDigits = digits
            }
            return formatter.string(from: value as NSNumber) ?? "\(value)"
        }
    }
}
