import Foundation

// MARK: - 数据库实体模型

/// 单词数据库实体 - 与 SQLite 表结构对应
/// 
/// 用于数据库操作，包含所有持久化字段
struct WordEntity {
    // MARK: - 基本信息
    
    let id: UUID
    let text: String
    let ipa: String?
    let meanings: String?
    let examples: String?
    let chineseExamples: String?
    let roots: String?
    
    // MARK: - 学习进度
    
    let isLearned: Bool?
    let learnedAt: Date?
    let masteryLevel: Int64?
    let reviewCount: Int64?
    let correctCount: Int64?
    let incorrectCount: Int64?
    let lastReviewedAt: Date?
    let nextReviewAt: Date?
    let ef: Double?
    let interval: Int64?
    let reps: Int64?
}

// MARK: - UI 显示模型

/// 单词显示模型 - 用于 UI 层展示
/// 
/// 由 WordEntity 转换而来，提供计算属性和默认值
struct WordData: Identifiable, Equatable {
    // MARK: - 基本信息
    
    let id: UUID
    let text: String
    let ipa: String?
    let meanings: String?
    let examples: String?
    let chineseExamples: String?
    let roots: String?
    
    // MARK: - 学习进度
    
    var isLearned: Bool = false
    var learnedAt: Date?
    var masteryLevel: Int64 = 0
    var reviewCount: Int64 = 0
    var correctCount: Int64 = 0
    var incorrectCount: Int64 = 0
    var ef: Double = 2.5
    var interval: Int64 = 0
    var reps: Int64 = 0
    var nextReview: Date = Date()
    
    // MARK: - 初始化方法
    
    /// 从 WordEntity 创建 WordData（提供默认值处理 NULL）
    init(entity: WordEntity) {
        self.id = entity.id
        self.text = entity.text
        self.ipa = entity.ipa
        self.meanings = entity.meanings
        self.examples = entity.examples
        self.chineseExamples = entity.chineseExamples
        self.roots = entity.roots
        
        self.isLearned = entity.isLearned ?? false
        self.learnedAt = entity.learnedAt
        self.masteryLevel = entity.masteryLevel ?? 0
        self.reviewCount = entity.reviewCount ?? 0
        self.correctCount = entity.correctCount ?? 0
        self.incorrectCount = entity.incorrectCount ?? 0
        self.ef = entity.ef ?? 2.5
        self.interval = entity.interval ?? 0
        self.reps = entity.reps ?? 0
        self.nextReview = entity.nextReviewAt ?? Date()
    }
    
    /// 直接创建（用于测试或临时数据）
    init(
        id: UUID = UUID(),
        text: String,
        ipa: String? = nil,
        meanings: String? = nil,
        examples: String? = nil,
        chineseExamples: String? = nil,
        roots: String? = nil,
        isLearned: Bool = false,
        learnedAt: Date? = nil,
        masteryLevel: Int64 = 0,
        reviewCount: Int64 = 0,
        correctCount: Int64 = 0,
        incorrectCount: Int64 = 0,
        ef: Double = 2.5,
        interval: Int64 = 0,
        reps: Int64 = 0,
        nextReview: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.ipa = ipa
        self.meanings = meanings
        self.examples = examples
        self.chineseExamples = chineseExamples
        self.roots = roots
        self.isLearned = isLearned
        self.learnedAt = learnedAt
        self.masteryLevel = masteryLevel
        self.reviewCount = reviewCount
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
        self.ef = ef
        self.interval = interval
        self.reps = reps
        self.nextReview = nextReview
    }
    
    // MARK: - 计算属性
    
    /// 掌握程度百分比 (0-100)
    var masteryPercent: Int {
        return Int(masteryLevel * 20)
    }
    
    /// 正确率
    var accuracyRate: Double {
        guard reviewCount > 0 else { return 0 }
        return Double(correctCount) / Double(reviewCount) * 100
    }
}
