import SwiftUI
import Charts

struct MasteryTrendChart: View {
    let masteredCount: Int64
    let forgettingCount: Int64
    
    @Environment(\.colorScheme) var colorScheme
    
    var masteredColor: Color { colorScheme == .dark ? .green : .green.opacity(0.8) }
    var forgettingColor: Color { colorScheme == .dark ? .orange : .orange.opacity(0.8) }
    var cardBackground: Color { colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95) }
    
    var body: some View {
        VStack(spacing: 12) {
            if #available(macOS 13.0, *) {
                Chart {
                    BarMark(
                        x: .value("Category", "熟练掌握"),
                        y: .value("Count", masteredCount)
                    )
                    .foregroundStyle(masteredColor)
                    
                    BarMark(
                        x: .value("Category", "快要忘记"),
                        y: .value("Count", forgettingCount)
                    )
                    .foregroundStyle(forgettingColor)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                            }
                        }
                    }
                }
            } else {
                legacyChartView
            }
            
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(masteredColor)
                        .frame(width: 10, height: 10)
                    Text("熟练掌握 (\(masteredCount))")
                        .font(.caption)
                }
                HStack(spacing: 6) {
                    Circle()
                        .fill(forgettingColor)
                        .frame(width: 10, height: 10)
                    Text("快要忘记 (\(forgettingCount))")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
    }
    
    private var legacyChartView: some View {
        GeometryReader { geometry in
            let maxValue = max(max(masteredCount, forgettingCount), 1)
            let barWidth: CGFloat = 60
            let spacing: CGFloat = 40
            let totalWidth = barWidth * 2 + spacing
            let startX = (geometry.size.width - totalWidth) / 2
            
            VStack {
                Spacer()
                
                HStack(spacing: spacing) {
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(masteredColor)
                            .frame(width: barWidth, height: geometry.size.height * CGFloat(masteredCount) / CGFloat(maxValue))
                        Text("\(masteredCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(forgettingColor)
                            .frame(width: barWidth, height: geometry.size.height * CGFloat(forgettingCount) / CGFloat(maxValue))
                        Text("\(forgettingCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: spacing) {
                    Text("熟练掌握")
                        .frame(width: barWidth)
                        .font(.caption2)
                    Text("快要忘记")
                        .frame(width: barWidth)
                        .font(.caption2)
                }
            }
            .offset(x: startX)
        }
    }
}