import XCTest
@testable import EasyEnglish
import SQLite

/// 学习会话管理器测试 - 验证会话加载和状态同步逻辑
final class LearningSessionManagerTests: XCTestCase {
    
    var sessionManager: LearningSessionManager!
    var testDatabasePath: String!
    
    override func setUp() {
        super.setUp()
        
        // 设置测试数据库
        testDatabasePath = NSTemporaryDirectory() + "test_wordlist.sqlite"
        
        // 清理旧数据库
        try? FileManager.default.removeItem(atPath: testDatabasePath)
        
        // 创建新数据库
        setupTestDatabase()
        
        // 初始化管理器
        sessionManager = LearningSessionManager.shared
    }
    
    override func tearDown() {
        sessionManager = nil
        
        // 清理测试数据库
        try? FileManager.default.removeItem(atPath: testDatabasePath)
        
        super.tearDown()
    }
    
    private func setupTestDatabase() {
        do {
            let db = try Connection(testDatabasePath)
            
            // 创建表
            let words = Table("words")
            let id = Expression<UUID>("id")
            let text = Expression<String>("text")
            let ipa = Expression<String?>("ipa")
            let meanings = Expression<String?>("meanings")
            
            try db.run(words.create { t in
                t.column(id, primaryKey: true)
                t.column(text, unique: true)
                t.column(ipa)
                t.column(meanings)
            })
            
            // 插入测试数据
            for i in 1...20 {
                let wordId = UUID()
                try db.run(words.insert(
                    id <- wordId,
                    text <- "word\(i)",
                    ipa <- "/wɜːrd\(i)/",
                    meanings <- "单词\(i) 的释义"
                ))
            }
            
            print("✅ 测试数据库创建成功，包含 20 个单词")
        } catch {
            XCTFail("创建测试数据库失败：\(error)")
        }
    }
    
    // MARK: - 会话加载测试
    
    func testLoadRandomSession_Success() {
        // Given
        let expectation = XCTestExpectation(description: "加载单词会话")
        
        // When
        sessionManager.loadRandomSession(count: 10)
        
        // Then
        XCTAssertEqual(sessionManager.sessionWords.count, 10)
        XCTAssertGreaterThan(sessionManager.sessionIndex, -1)
        XCTAssertFalse(sessionManager.isLoadingSession)
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testLoadRandomSession_EmptyDatabase() {
        // Given - 清空数据库
        clearTestDatabase()
        
        // When
        sessionManager.loadRandomSession(count: 10)
        
        // Then
        XCTAssertEqual(sessionManager.sessionWords.count, 0)
        XCTAssertEqual(sessionManager.sessionIndex, 0)
        XCTAssertFalse(sessionManager.isLoadingSession)
    }
    
    func testLoadRandomSession_LessThanRequested() {
        // Given - 数据库只有 5 个单词
        truncateTestDatabase(to: 5)
        
        // When
        sessionManager.loadRandomSession(count: 10)
        
        // Then
        XCTAssertEqual(sessionManager.sessionWords.count, 5)
        XCTAssertFalse(sessionManager.isLoadingSession)
    }
    
    // MARK: - 状态同步测试
    
    func testReview_UpdatesMemoryAndDatabase() {
        // Given
        sessionManager.loadRandomSession(count: 5)
        guard let firstWord = sessionManager.sessionWords.first else {
            XCTFail("没有加载到单词")
            return
        }
        
        XCTAssertFalse(firstWord.isLearned)
        
        // When - 更新学习状态
        sessionManager.review(word: firstWord, quality: 5, attemptType: "test")
        
        // Then - 验证内存中的状态
        if let updatedWord = sessionManager.sessionWords.first(where: { $0.id == firstWord.id }) {
            XCTAssertTrue(updatedWord.isLearned)
            XCTAssertNotNil(updatedWord.learnedAt)
        } else {
            XCTFail("未在 sessionWords 中找到更新的单词")
        }
        
        // And - 验证数据库中的状态
        verifyWordInDatabaseIsLearned(firstWord.text)
    }
    
    func testReview_MultipleWords() {
        // Given
        sessionManager.loadRandomSession(count: 5)
        let wordsToReview = Array(sessionManager.sessionWords.prefix(3))
        
        // When - 复习前 3 个单词
        for word in wordsToReview {
            sessionManager.review(word: word, quality: 4, attemptType: "test")
        }
        
        // Then
        let learnedCount = sessionManager.sessionWords.filter { $0.isLearned }.count
        XCTAssertEqual(learnedCount, 3)
    }
    
    func testSessionIndex_BoundaryConditions() {
        // Given
        sessionManager.loadRandomSession(count: 5)
        
        // When - 移动到最后一个
        sessionManager.sessionIndex = 4
        
        // Then
        XCTAssertEqual(sessionManager.sessionIndex, 4)
        
        // When - 超出边界
        sessionManager.sessionIndex = 10
        
        // Then - 应该被重置（在 currentWord 计算属性中）
        XCTAssertLessThanOrEqual(sessionManager.sessionIndex, sessionManager.sessionWords.count - 1)
    }
    
    // MARK: - 辅助方法
    
    private func clearTestDatabase() {
        do {
            let db = try Connection(testDatabasePath)
            let words = Table("words")
            try db.run(words.delete())
            print("✅ 测试数据库已清空")
        } catch {
            XCTFail("清空数据库失败：\(error)")
        }
    }
    
    private func truncateTestDatabase(to count: Int) {
        do {
            let db = try Connection(testDatabasePath)
            let words = Table("words")
            let id = Expression<UUID>("id")
            let text = Expression<String>("text")
            let ipa = Expression<String?>("ipa")
            let meanings = Expression<String?>("meanings")
            
            // 简单方式：删除所有后重新插入指定数量
            try db.run(words.delete())
            
            for i in 1...count {
                let wordId = UUID()
                try db.run(words.insert(
                    id <- wordId,
                    text <- "word\(i)",
                    ipa <- "/wɜːrd\(i)/",
                    meanings <- "单词\(i) 的释义"
                ))
            }
            
            print("✅ 测试数据库保留 \(count) 个单词")
        } catch {
            XCTFail("截断数据库失败：\(error)")
        }
    }
    
    private func verifyWordInDatabaseIsLearned(_ text: String) {
        do {
            let db = try Connection(testDatabasePath)
            let words = Table("words")
            let isLearned = Expression<Bool?>("is_learned")
            
            let query = words.filter(Expression<String>("text") == text)
            let result = try db.pluck(query)
            
            if let learned = result?[isLearned] {
                XCTAssertTrue(learned, "数据库中单词的 is_learned 应该为 true")
            } else {
                XCTFail("未找到单词或 is_learned 为 nil")
            }
        } catch {
            XCTFail("查询数据库失败：\(error)")
        }
    }
}
