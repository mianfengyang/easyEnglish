import Foundation

final class ReviewScheduler {
    static let shared = ReviewScheduler()
    
    private init() {}
    
    func getDueWords(from repository: WordRepositoryProtocol, count: Int) async throws -> [Word] {
        try await repository.getReviewWords(count: count)
    }
    
    func calculateNextReview(quality: Int, currentState: Word) -> Word {
        let result = SM2Algorithm.shared.calculate(
            reps: Int(currentState.reps),
            interval: Int(currentState.interval),
            ef: currentState.ef,
            quality: quality
        )
        
        var updated = currentState
        updated.reps = Int64(result.reps)
        updated.interval = Int64(result.interval)
        updated.ef = result.ef
        updated.nextReviewAt = result.nextReviewDate
        updated.lastReviewedAt = Date()
        updated.reviewCount += 1
        
        let isCorrect = quality >= 3
        updated.correctCount += isCorrect ? 1 : 0
        updated.incorrectCount += isCorrect ? 0 : 1
        
        if isCorrect {
            updated.masteryLevel = min(5, currentState.masteryLevel + 1)
        } else {
            updated.masteryLevel = max(0, currentState.masteryLevel - 1)
        }
        
        return updated
    }
}