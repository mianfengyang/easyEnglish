import Foundation

struct SM2Result {
    let reps: Int
    let interval: Int
    let ef: Double
    let nextReviewDate: Date?
}

final class SM2Algorithm {
    static let shared = SM2Algorithm()
    
    private let minEF = 1.3
    private let initialEF = 2.5
    private let qualityThreshold = 3
    private let firstInterval = 1
    private let secondInterval = 6
    
    private init() {}
    
    func calculate(
        reps: Int,
        interval: Int,
        ef: Double,
        quality: Int
    ) -> SM2Result {
        let q = max(0, min(5, quality))
        
        var newReps = reps
        var newInterval = interval
        var newEF = ef
        
        if q < qualityThreshold {
            newReps = 0
            newInterval = firstInterval
        } else {
            newReps += 1
            switch newReps {
            case 1:
                newInterval = firstInterval
            case 2:
                newInterval = secondInterval
            default:
                newInterval = Int(round(Double(newInterval) * newEF))
            }
        }
        
        newEF = calculateNewEF(currentEF: ef, quality: q)
        let nextDate = Calendar.current.date(byAdding: .day, value: newInterval, to: Date())
        
        return SM2Result(
            reps: newReps,
            interval: newInterval,
            ef: newEF,
            nextReviewDate: nextDate
        )
    }
    
    private func calculateNewEF(currentEF: Double, quality: Int) -> Double {
        let delta = 0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02)
        return max(minEF, currentEF + delta)
    }
}