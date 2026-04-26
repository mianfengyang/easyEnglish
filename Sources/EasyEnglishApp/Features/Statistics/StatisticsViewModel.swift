import Foundation
import Combine

@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published var dailyStats: DailyStats?
    @Published var masteryDistribution: [MasteryDistribution] = []
    @Published var weeklyTrend: [WeeklyTrend] = []
    @Published var masteryTrend: MasteryTrend?
    @Published var recentWords: [Word] = []
    @Published var totalWords: Int = 0
    @Published var learnedWords: Int64 = 0
    @Published var isLoading: Bool = false
    
    private let repository: WordRepositoryProtocol
    
    var progressPercent: Double {
        guard totalWords > 0 else { return 0 }
        return Double(learnedWords) / Double(totalWords) * 100
    }
    
    init(repository: WordRepositoryProtocol) {
        self.repository = repository
    }
    
    func loadStats() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let daily = repository.getDailyStats()
            async let mastery = repository.getMasteryDistribution()
            async let trend = repository.getWeeklyTrend(weeks: 8)
            async let masteryTrend = repository.getMasteryTrend()
            async let recent = repository.getRecentWords(limit: 20)
            async let total = repository.getTotalCount()
            async let learned = repository.getLearnedCount()
            
            dailyStats = try await daily
            masteryDistribution = try await mastery
            weeklyTrend = try await trend
            self.masteryTrend = try await masteryTrend
            recentWords = try await recent
            totalWords = try await total
            learnedWords = try await learned
        } catch {
            Logger.error("加载统计数据失败: \(error)")
            dailyStats = DailyStats(date: Date(), newWords: 0, reviews: 0, correctRate: 0.0)
        }
    }
}
