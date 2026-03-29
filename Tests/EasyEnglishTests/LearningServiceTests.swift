import XCTest
@testable import EasyEnglish

/// 学习服务测试 - 验证 SM2 算法集成和统计计算逻辑
final class LearningServiceTests: XCTestCase {
    
    var service: LearningService!
    
    override func setUp() {
        super.setUp()
        service = LearningService.shared
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    // MARK: - 默认统计测试
    
    func testGetDefaultStats() {
        // Given
        let defaultStats = service.getDefaultStats()
        
        // Then
        XCTAssertFalse(defaultStats.isLearned)
        XCTAssertEqual(defaultStats.masteryLevel, 0)
        XCTAssertEqual(defaultStats.reviewCount, 0)
        XCTAssertEqual(defaultStats.correctCount, 0)
        XCTAssertEqual(defaultStats.incorrectCount, 0)
        XCTAssertEqual(defaultStats.ef, 2.5)
        XCTAssertEqual(defaultStats.interval, 0)
        XCTAssertEqual(defaultStats.reps, 0)
    }
    
    // MARK: - 学习统计计算测试
    
    func testCalculateNewLearningStats_Success() {
        // Given
        let currentStats = WordLearningStats(
            isLearned: false,
            learnedAt: nil,
            masteryLevel: 0,
            reviewCount: 0,
            correctCount: 0,
            incorrectCount: 0,
            lastReviewedAt: nil,
            nextReviewAt: Date(),
            ef: 2.5,
            interval: 0,
            reps: 0
        )
        let quality = 5  // 完美回忆
        
        // When
        let newStats = service.calculateNewLearningStats(currentStats: currentStats, quality: quality)
        
        // Then
        XCTAssertTrue(newStats.isLearned)
        XCTAssertEqual(newStats.reviewCount, 1)
        XCTAssertEqual(newStats.correctCount, 1)
        XCTAssertEqual(newStats.incorrectCount, 0)
        XCTAssertEqual(newStats.masteryLevel, 1)
        XCTAssertEqual(newStats.reps, 1)
        XCTAssertEqual(newStats.interval, 1)  // 第一次复习间隔为 1 天
    }
    
    func testCalculateNewLearningStats_Failure() {
        // Given
        let currentStats = WordLearningStats(
            isLearned: false,
            learnedAt: nil,
            masteryLevel: 0,
            reviewCount: 0,
            correctCount: 0,
            incorrectCount: 0,
            lastReviewedAt: nil,
            nextReviewAt: Date(),
            ef: 2.5,
            interval: 0,
            reps: 0
        )
        let quality = 0  // 完全忘记
        
        // When
        let newStats = service.calculateNewLearningStats(currentStats: currentStats, quality: quality)
        
        // Then
        XCTAssertTrue(newStats.isLearned)
        XCTAssertEqual(newStats.reviewCount, 1)
        XCTAssertEqual(newStats.correctCount, 0)
        XCTAssertEqual(newStats.incorrectCount, 1)
        XCTAssertEqual(newStats.masteryLevel, 0)  // 重置为 0
        XCTAssertEqual(newStats.reps, 0)  // 重置为 0
        XCTAssertEqual(newStats.interval, 1)  // 重新从 1 天开始
    }
    
    func testCalculateNewLearningStats_MasteryLevelIncrease() {
        // Given
        var currentStats = WordLearningStats(
            isLearned: true,
            learnedAt: Date(),
            masteryLevel: 3,
            reviewCount: 5,
            correctCount: 4,
            incorrectCount: 1,
            lastReviewedAt: Date(),
            nextReviewAt: Date(),
            ef: 2.5,
            interval: 6,
            reps: 3
        )
        
        // When - 连续正确
        for _ in 0..<3 {
            currentStats = service.calculateNewLearningStats(currentStats: currentStats, quality: 5)
        }
        
        // Then
        XCTAssertEqual(currentStats.masteryLevel, 5)  // 达到最大值
    }
    
    func testCalculateNewLearningStats_MasteryLevelDecrease() {
        // Given
        var currentStats = WordLearningStats(
            isLearned: true,
            learnedAt: Date(),
            masteryLevel: 3,
            reviewCount: 5,
            correctCount: 4,
            incorrectCount: 1,
            lastReviewedAt: Date(),
            nextReviewAt: Date(),
            ef: 2.5,
            interval: 6,
            reps: 3
        )
        
        // When - 错误回忆
        currentStats = service.calculateNewLearningStats(currentStats: currentStats, quality: 0)
        
        // Then
        XCTAssertEqual(currentStats.masteryLevel, 2)  // 降低 1 级
    }
    
    // MARK: - 复习统计计算测试
    
    func testCalculateNewReviewStats_Correct() {
        // Given
        let currentStats = WordLearningStats(
            isLearned: true,
            learnedAt: Date(),
            masteryLevel: 2,
            reviewCount: 3,
            correctCount: 2,
            incorrectCount: 1,
            lastReviewedAt: Date(),
            nextReviewAt: Date(),
            ef: 2.5,
            interval: 6,
            reps: 2
        )
        
        // When
        let newStats = service.calculateNewReviewStats(currentStats: currentStats, correct: true)
        
        // Then
        XCTAssertEqual(newStats.reviewCount, 4)
        XCTAssertEqual(newStats.correctCount, 3)
        XCTAssertEqual(newStats.incorrectCount, 1)
        XCTAssertEqual(newStats.masteryLevel, 3)
    }
    
    func testCalculateNewReviewStats_Incorrect() {
        // Given
        let currentStats = WordLearningStats(
            isLearned: true,
            learnedAt: Date(),
            masteryLevel: 2,
            reviewCount: 3,
            correctCount: 2,
            incorrectCount: 1,
            lastReviewedAt: Date(),
            nextReviewAt: Date(),
            ef: 2.5,
            interval: 6,
            reps: 2
        )
        
        // When
        let newStats = service.calculateNewReviewStats(currentStats: currentStats, correct: false)
        
        // Then
        XCTAssertEqual(newStats.reviewCount, 4)
        XCTAssertEqual(newStats.correctCount, 2)
        XCTAssertEqual(newStats.incorrectCount, 2)
        XCTAssertEqual(newStats.masteryLevel, 1)
    }
    
    // MARK: - SM2 算法集成测试
    
    func testSM2Algorithm_Integration() {
        // Given
        let currentStats = WordLearningStats(
            isLearned: false,
            learnedAt: nil,
            masteryLevel: 0,
            reviewCount: 0,
            correctCount: 0,
            incorrectCount: 0,
            lastReviewedAt: nil,
            nextReviewAt: Date(),
            ef: 2.5,
            interval: 0,
            reps: 0
        )
        
        // When - 第一次正确回忆
        let stats1 = service.calculateNewLearningStats(currentStats: currentStats, quality: 5)
        
        // Then
        XCTAssertEqual(stats1.reps, 1)
        XCTAssertEqual(stats1.interval, 1)
        XCTAssertGreaterThan(stats1.ef, 2.5)  // EF 应该增加
        
        // When - 第二次正确回忆
        let stats2 = service.calculateNewLearningStats(currentStats: stats1, quality: 5)
        
        // Then
        XCTAssertEqual(stats2.reps, 2)
        XCTAssertEqual(stats2.interval, 6)  // 第二次间隔固定为 6 天
        
        // When - 第三次正确回忆
        let stats3 = service.calculateNewLearningStats(currentStats: stats2, quality: 5)
        
        // Then
        XCTAssertEqual(stats3.reps, 3)
        XCTAssertGreaterThan(stats3.interval, 6)  // 间隔应该大于 6 天
    }
    
    func testSM2Algorithm_ResetOnFailure() {
        // Given
        var currentStats = WordLearningStats(
            isLearned: true,
            learnedAt: Date(),
            masteryLevel: 3,
            reviewCount: 10,
            correctCount: 8,
            incorrectCount: 2,
            lastReviewedAt: Date(),
            nextReviewAt: Date(),
            ef: 2.8,
            interval: 30,
            reps: 5
        )
        
        // When - 回忆失败
        currentStats = service.calculateNewLearningStats(currentStats: currentStats, quality: 0)
        
        // Then
        XCTAssertEqual(currentStats.reps, 0)  // 重置
        XCTAssertEqual(currentStats.interval, 1)  // 重置为 1 天
        XCTAssertLessThan(currentStats.ef, 2.8)  // EF 降低
    }
    
    // MARK: - 边界条件测试
    
    func testQualityThreshold() {
        // Given
        let currentStats = service.getDefaultStats()
        
        // When & Then - quality >= 3 视为正确
        var result = service.calculateNewLearningStats(currentStats: currentStats, quality: 3)
        XCTAssertEqual(result.correctCount, 1)
        
        result = service.calculateNewLearningStats(currentStats: currentStats, quality: 4)
        XCTAssertEqual(result.correctCount, 1)
        
        result = service.calculateNewLearningStats(currentStats: currentStats, quality: 5)
        XCTAssertEqual(result.correctCount, 1)
        
        // quality < 3 视为错误
        result = service.calculateNewLearningStats(currentStats: currentStats, quality: 2)
        XCTAssertEqual(result.incorrectCount, 1)
        
        result = service.calculateNewLearningStats(currentStats: currentStats, quality: 0)
        XCTAssertEqual(result.incorrectCount, 1)
    }
}
