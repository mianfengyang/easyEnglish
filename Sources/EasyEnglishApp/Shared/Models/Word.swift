import Foundation

protocol WordEntity {
    var id: UUID { get }
    var text: String { get }
    var ipa: String? { get }
    var meanings: String? { get }
    var examples: String? { get }
    var chineseExamples: String? { get }
    var roots: String? { get }
}

protocol WordLearningState {
    var isLearned: Bool { get }
    var learnedAt: Date? { get }
    var masteryLevel: Int64 { get }
    var reviewCount: Int64 { get }
    var correctCount: Int64 { get }
    var incorrectCount: Int64 { get }
    var lastReviewedAt: Date? { get }
    var nextReviewAt: Date? { get }
    var ef: Double { get }
    var interval: Int64 { get }
    var reps: Int64 { get }
}

struct Word: WordEntity, WordLearningState, Identifiable, Equatable {
    let id: UUID
    let text: String
    let ipa: String?
    let meanings: String?
    let examples: String?
    let chineseExamples: String?
    let roots: String?
    
    var isLearned: Bool = false
    var learnedAt: Date?
    var masteryLevel: Int64 = 0
    var reviewCount: Int64 = 0
    var correctCount: Int64 = 0
    var incorrectCount: Int64 = 0
    var lastReviewedAt: Date?
    var nextReviewAt: Date?
    var ef: Double = 2.5
    var interval: Int64 = 0
    var reps: Int64 = 0
    
    var masteryPercent: Int { Int(masteryLevel * 20) }
    
    var accuracyRate: Double {
        guard reviewCount > 0 else { return 0 }
        return Double(correctCount) / Double(reviewCount) * 100
    }
    
    init(from entity: WordEntityType, learning: WordLearningStateType? = nil) {
        self.id = entity.id
        self.text = entity.text
        self.ipa = entity.ipa
        self.meanings = entity.meanings
        self.examples = entity.examples
        self.chineseExamples = entity.chineseExamples
        self.roots = entity.roots
        
        self.isLearned = learning?.isLearned ?? false
        self.learnedAt = learning?.learnedAt
        self.masteryLevel = learning?.masteryLevel ?? 0
        self.reviewCount = learning?.reviewCount ?? 0
        self.correctCount = learning?.correctCount ?? 0
        self.incorrectCount = learning?.incorrectCount ?? 0
        self.lastReviewedAt = learning?.lastReviewedAt
        self.nextReviewAt = learning?.nextReviewAt
        self.ef = learning?.ef ?? 2.5
        self.interval = learning?.interval ?? 0
        self.reps = learning?.reps ?? 0
    }
    
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
        lastReviewedAt: Date? = nil,
        nextReviewAt: Date? = nil,
        ef: Double = 2.5,
        interval: Int64 = 0,
        reps: Int64 = 0
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
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewAt = nextReviewAt
        self.ef = ef
        self.interval = interval
        self.reps = reps
    }
}

typealias WordEntityType = WordEntity
typealias WordLearningStateType = WordLearningState