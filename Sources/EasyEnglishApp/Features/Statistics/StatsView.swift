import SwiftUI

struct StatsView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    var onRestartLearning: () -> Void
    var onLearnMore: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("学习统计").font(.title2).bold()
                Spacer()
                Button("关闭") { }
            }
            
            if viewModel.isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        todayStatsSection
                        progressSection
                        masteryDistributionSection
                    }
                }
                
                HStack(spacing: 16) {
                    PrimaryButton("重新开始学习", icon: "arrow.counterclockwise") {
                        onRestartLearning()
                    }
                    PrimaryButton("多学一些", icon: "plus") {
                        onLearnMore(20)
                    }
                }
                .padding(.top, 16)
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            Task { await viewModel.loadStats() }
        }
    }
    
    private var todayStatsSection: some View {
        GroupBox("今日学习") {
            HStack(spacing: 30) {
                if let stats = viewModel.dailyStats {
                    StatBox(title: "新学", value: "\(stats.newWords)")
                    StatBox(title: "复习", value: "\(stats.reviews)")
                    StatBox(title: "正确率", value: String(format: "%.1f%%", stats.correctRate))
                } else {
                    Text("暂无数据")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var progressSection: some View {
        GroupBox("学习进度") {
            VStack(spacing: 8) {
                ProgressBar(progress: viewModel.progressPercent)
                HStack {
                    Text("已学习：\(viewModel.learnedWords)")
                        .font(.caption)
                    Spacer()
                    Text("总单词：\(viewModel.totalWords)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var masteryDistributionSection: some View {
        GroupBox("掌握度分布") {
            if viewModel.masteryDistribution.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                HStack(spacing: 12) {
                    ForEach(viewModel.masteryDistribution, id: \.level) { item in
                        MasteryIndicator(level: item.level, count: item.count)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.2))
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.6, blue: 0.2),
                            Color(red: 0.95, green: 0.5, blue: 0.1)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geometry.size.width * CGFloat(progress / 100), height: 8)
            }
        }
        .frame(height: 8)
    }
}

struct MasteryIndicator: View {
    let level: Int
    let count: Int64
    
    var body: some View {
        VStack(spacing: 4) {
            Text("L\(level)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            RoundedRectangle(cornerRadius: 4)
                .fill(levelColor)
                .frame(width: 24, height: CGFloat(count) / 10 + 10)
            Text("\(count)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
    
    private var levelColor: Color {
        switch level {
        case 0: return .gray
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green.opacity(0.7)
        case 5: return .green
        default: return .gray
        }
    }
}