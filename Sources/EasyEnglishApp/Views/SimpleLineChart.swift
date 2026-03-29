import SwiftUI

struct SimpleLineChart: View {
    var values: [Double]
    var lineColor: Color = .blue

    var body: some View {
        GeometryReader { geo in
            if values.isEmpty {
                Text("无数据").foregroundColor(.secondary)
            } else {
                let w = geo.size.width
                let h = geo.size.height
                let maxV = values.max() ?? 1
                let minV = values.min() ?? 0
                let range = maxV - minV == 0 ? 1 : maxV - minV

                Path { path in
                    for (i, v) in values.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(max(1, values.count - 1))
                        let y = h - ((CGFloat(v - minV) / CGFloat(range)) * h)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(lineColor, lineWidth: 2)
            }
        }
    }
}

struct SimpleLineChart_Previews: PreviewProvider {
    static var previews: some View {
        SimpleLineChart(values: [1,3,2,5,4,6]).frame(height: 120).padding()
    }
}
