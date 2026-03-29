import Foundation

/// 学习服务 - 管理学习逻辑和 SM-2 调度
/// 
/// 职责：
/// - 计算单词学习状态更新
/// - SM-2 算法调度
/// - 学习统计计算
/// 
/// 不包含数据库操作，只返回计算结果
final class LearningService {
    
    // MARK: - 单例
    
    static let shared = LearningService()
    
    private init() {}
    
    // MARK: - 公共 API
    
    /// 计算单词学习后的新状态
    /// - Parameters:
    ///   - currentStats: 当前学习统计
    ///   - quality: 回忆质量 (0-5)
    /// - Returns: 新的学习统计
    func calculateNewLearningStats(
        currentStats: WordLearningStats,
        quality: Int
    ) -> WordLearningStats {
        let correct = quality >= 3
        
        // 更新计数
        let newReviewCount = currentStats.reviewCount + 1
        let newCorrectCount = correct ? currentStats.correctCount + 1 : currentStats.correctCount
        let newIncorrectCount = correct ? currentStats.incorrectCount : currentStats.incorrectCount + 1
        
        // SM-2 算法计算
        let (newReps, newInterval, newEf, nextReviewDateOptional) = SM2.schedule(
            reps: Int(currentStats.reps),
            interval: Int(currentStats.interval),
            ef: currentStats.ef,
            quality: quality
        )
        
        let nextReviewDate = nextReviewDateOptional ?? Date()
        
        // 计算掌握程度 (0-5)
        var newMasteryLevel = currentStats.masteryLevel
        if correct {
            newMasteryLevel = min(5, currentStats.masteryLevel + 1)
        } else {
            newMasteryLevel = max(0, currentStats.masteryLevel - 1)
        }
        
        return WordLearningStats(
            isLearned: true,
            learnedAt: Date(),
            masteryLevel: newMasteryLevel,
            reviewCount: newReviewCount,
            correctCount: newCorrectCount,
            incorrectCount: newIncorrectCount,
            lastReviewedAt: Date(),
            nextReviewAt: nextReviewDate,
            ef: newEf,
            interval: Int64(newInterval),
            reps: Int64(newReps)
        )
    }
    
    /// 计算复习后的新状态
    /// - Parameters:
    ///   - currentStats: 当前学习统计
    ///   - correct: 是否正确
    /// - Returns: 新的学习统计
    func calculateNewReviewStats(
        currentStats: WordLearningStats,
        correct: Bool
    ) -> WordLearningStats {
        let quality = correct ? 5 : 0
        
        return calculateNewLearningStats(
            currentStats: currentStats,
            quality: quality
        )
    }
    
    /// 获取默认的学习统计（新单词）
    func getDefaultStats() -> WordLearningStats {
        return WordLearningStats(
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
    }
}

// MARK: - 数据模型

/// 单词学习统计 - 用于计算和传输
struct WordLearningStats {
    var isLearned: Bool
    var learnedAt: Date?
    var masteryLevel: Int64
    var reviewCount: Int64
    var correctCount: Int64
    var incorrectCount: Int64
    var lastReviewedAt: Date?
    var nextReviewAt: Date
    var ef: Double
    var interval: Int64
    var reps: Int64
}
