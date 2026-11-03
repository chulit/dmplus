import SwiftUI
import DMPlusKit

/// Filled speed graph for the progress window, drawn from SpeedHistory —
/// the same graph IDM shows under its download progress bar.
struct SpeedGraphView: View {
    let history: SpeedHistory

    var body: some View {
        Canvas { context, size in
            // Grid lines
            var grid = Path()
            for i in 1..<4 {
                let y = size.height * Double(i) / 4
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(.secondary.opacity(0.25)), lineWidth: 0.5)

            let points = history.normalized
            guard points.count > 1 else { return }
            let stepX = size.width / Double(history.capacity - 1)
            let startX = size.width - stepX * Double(points.count - 1)
            var area = Path()
            var line = Path()
            for (i, value) in points.enumerated() {
                let x = startX + stepX * Double(i)
                let y = size.height - value * (size.height - 4) - 2
                if i == 0 {
                    area.move(to: CGPoint(x: x, y: size.height))
                    area.addLine(to: CGPoint(x: x, y: y))
                    line.move(to: CGPoint(x: x, y: y))
                } else {
                    area.addLine(to: CGPoint(x: x, y: y))
                    line.addLine(to: CGPoint(x: x, y: y))
                }
            }
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.closeSubpath()
            context.fill(area, with: .color(.accentColor.opacity(0.25)))
            context.stroke(line, with: .color(.accentColor), lineWidth: 1.5)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.3)))
    }
}
