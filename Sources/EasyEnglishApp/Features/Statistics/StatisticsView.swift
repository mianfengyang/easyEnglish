import SwiftUI

struct StatisticsView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    var onRestartLearning: () -> Void
    var onLearnMore: (Int) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                actionsSection
                todayStatsSection
                masterySection
                trendSection
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
    
    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日学习")
                .font(.system(size: 14, weight: .semibold))
            
            HStack(spacing: 16) {
                StatCard(title: "新学单词", value: "\(viewModel.dailyStats?.newWords ?? 0)", icon: "sparkles", color: Theme.success)
                StatCard(title: "复习单词", value: "\(viewModel.dailyStats?.reviews ?? 0)", icon: "arrow.clockwise", color: Theme.primary)
                StatCard(title: "正确率", value: String(format: "%.1f%%", viewModel.dailyStats?.correctRate ?? 0), icon: "target", color: Theme.secondary)
                StatCard(title: "已学/总计", value: "\(viewModel.learnedWords)/\(viewModel.totalWords)", icon: "chart.bar.fill", color: Theme.primary)
            }
        }
        .cardStyle()
    }
    
    private var masterySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("掌握度分布")
                .font(.system(size: 14, weight: .semibold))
            
            if viewModel.masteryDistribution.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无数据")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else {
                HStack(spacing: 12) {
                    ForEach(viewModel.masteryDistribution, id: \.level) { item in
                        MasteryBar(level: item.level, count: item.count, total: Int(viewModel.learnedWords))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .cardStyle()
    }
    
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("学习趋势")
                .font(.system(size: 14, weight: .semibold))
            
            if let trend = viewModel.masteryTrend {
                MasteryTrendChart(
                    masteredCount: trend.masteredCount,
                    forgettingCount: trend.forgettingCount
                )
                .frame(height: 160)
                
                if trend.forgettingCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("有 \(trend.forgettingCount) 个单词快要忘记了，建议复习")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Spacer()
                    Text("暂无数据")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 16)
            }
        }
        .cardStyle()
    }
    
    private var actionsSection: some View {
        HStack(spacing: 16) {
            AccentButton("再学一遍", icon: "arrow.counterclockwise") {
                onRestartLearning()
            }
            SecondaryActionButton("多学一些", icon: "plus") {
                onLearnMore(20)
            }
        }
    }
}