import Foundation

enum AppPage: String, CaseIterable {
    case learning
    case spelling
    case dictation
    case statistics
    
    var title: String {
        switch self {
        case .learning: return "学习"
        case .spelling: return "拼写"
        case .dictation: return "听写"
        case .statistics: return "统计"
        }
    }
    
    var icon: String {
        switch self {
        case .learning: return "book.fill"
        case .spelling: return "keyboard"
        case .dictation: return "ear"
        case .statistics: return "chart.bar.fill"
        }
    }
}

struct DailyStats: Equatable {
    let date: Date
    let newWords: Int64
    let reviews: Int64
    let correctRate: Double
}

struct MasteryDistribution: Equatable {
    let level: Int
    let count: Int64
}

struct WeeklyTrend: Equatable {
    let date: Date
    let avgMastery: Double
}

struct MasteryTrend: Equatable {
    let masteredCount: Int64   // 熟练掌握 (mastery >= 4)
    let forgettingCount: Int64  // 快要忘记 (next_review_at <= 3天内)
}