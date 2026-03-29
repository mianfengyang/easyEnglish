import SwiftUI

#if canImport(Charts)
import Charts

struct ChartsLineView: View {
    struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    var points: [Point]
    var lineColor: Color = .accentColor

    var body: some View {
        Chart {
            ForEach(points) { p in
                LineMark(x: .value("Date", p.date), y: .value("Value", p.value))
            }
        }
        .chartYScale(domain: .automatic)
    }
}

#else

// Fallback to SimpleLineChart when Charts is unavailable
struct ChartsLineView: View {
    var points: [ChartsLineView.Point] = []
    var lineColor: Color = .blue

    var body: some View {
        let values = points.map { $0.value }
        SimpleLineChart(values: values, lineColor: lineColor)
    }
}

extension ChartsLineView {
    struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
}

#endif

struct ChartsLineView_Previews: PreviewProvider {
    static var previews: some View {
        let now = Date()
        let pts = (0..<7).map { ChartsLineView.Point(date: Calendar.current.date(byAdding: .day, value: $0, to: now)!, value: Double($0)) }
        ChartsLineView(points: pts).frame(height: 120).padding()
    }
}
