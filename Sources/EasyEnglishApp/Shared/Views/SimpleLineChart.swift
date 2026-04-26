import SwiftUI
import Charts

struct SimpleLineChart: View {
    let data: [WeeklyTrend]
    
    var body: some View {
        if #available(macOS 13.0, *) {
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    LineMark(
                        x: .value("Week", index),
                        y: .value("Mastery", item.avgMastery)
                    )
                    .foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.2))
                    
                    PointMark(
                        x: .value("Week", index),
                        y: .value("Mastery", item.avgMastery)
                    )
                    .foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.2))
                }
            }
            .chartYScale(domain: 0...5)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("L\(intValue)")
                        }
                    }
                }
            }
        } else {
            legacyChartView
        }
    }
    
    private var legacyChartView: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let maxValue: Double = 5.0
            let points = data.enumerated().map { (index, item) -> CGPoint in
                let x = width * CGFloat(index) / CGFloat(max(1, data.count - 1))
                let y = height * (1 - CGFloat(item.avgMastery / maxValue))
                return CGPoint(x: x, y: y)
            }
            
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(Color(red: 1.0, green: 0.6, blue: 0.2), lineWidth: 2)
            
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                Circle()
                    .fill(Color(red: 1.0, green: 0.6, blue: 0.2))
                    .frame(width: 8, height: 8)
                    .position(point)
            }
        }
    }
}