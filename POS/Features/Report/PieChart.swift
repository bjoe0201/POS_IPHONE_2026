import SwiftUI

/// 純 Path 繪製的圓餅圖，對應 Android ReportScreen.PieChart。
struct PieChart: View {
    let values: [Double]
    let colors: [Color]

    var body: some View {
        GeometryReader { geo in
            let diameter = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = diameter / 2
            let total = values.reduce(0) { $0 + max($1, 0) }

            if total <= 0 {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: diameter, height: diameter)
                    .position(center)
            } else {
                ForEach(Array(slices(total: total).enumerated()), id: \.offset) { idx, slice in
                    PieSlice(center: center, radius: radius, start: slice.start, end: slice.end)
                        .fill(colors[idx % max(colors.count, 1)])
                }
            }
        }
    }

    private func slices(total: Double) -> [(start: Angle, end: Angle)] {
        var result: [(Angle, Angle)] = []
        var startDeg = -90.0
        for v in values where v > 0 {
            let sweep = v / total * 360
            result.append((.degrees(startDeg), .degrees(startDeg + sweep)))
            startDeg += sweep
        }
        return result
    }
}

private struct PieSlice: Shape {
    let center: CGPoint
    let radius: CGFloat
    let start: Angle
    let end: Angle

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}
