import SwiftUI

/// Shared shape-preserving curve and value-based stroke for the dashboard and menu bar.
enum GlucoseTrace {
    struct Point {
        let position: CGPoint
        let group: Int
    }

    static func draw(context: inout GraphicsContext, size: CGSize, points: [Point],
                     lowerY: CGFloat, upperY: CGFloat, lineWidth: CGFloat = 2.4,
                     normalColor: Color = GlucosePalette.blue) {
        let outline = path(through: points).strokedPath(
            StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        // Paint one continuous stroke; color follows its height, with no sample markers.
        context.fill(outline, with: .color(normalColor))
        let pixelsPerUnit = (lowerY - upperY) / (GlucosePalette.upper - GlucosePalette.lower)
        let lowerRedY = lowerY + pixelsPerUnit * GlucosePalette.fullRedDeviation
        let upperRedY = upperY - pixelsPerUnit * GlucosePalette.fullRedDeviation
        paint(outline, context: context, size: size, fromY: 0, toY: upperY,
              shading: .linearGradient(Gradient(colors: [GlucosePalette.amber, GlucosePalette.red]),
                                       startPoint: CGPoint(x: 0, y: upperY),
                                       endPoint: CGPoint(x: 0, y: upperRedY)))
        paint(outline, context: context, size: size, fromY: lowerY, toY: size.height,
              shading: .linearGradient(Gradient(colors: [GlucosePalette.amber, GlucosePalette.red]),
                                       startPoint: CGPoint(x: 0, y: lowerY),
                                       endPoint: CGPoint(x: 0, y: lowerRedY)))
    }

    static func path(through points: [Point]) -> Path {
        var path = Path()
        var run: [CGPoint] = []
        var group: Int?
        for point in points {
            if let last = run.last, group != point.group || point.position.x <= last.x {
                appendSmoothRun(run, to: &path)
                run.removeAll(keepingCapacity: true)
            }
            run.append(point.position)
            group = point.group
        }
        appendSmoothRun(run, to: &path)
        return path
    }

    private static func paint(_ outline: Path, context: GraphicsContext, size: CGSize,
                              fromY: CGFloat, toY: CGFloat, shading: GraphicsContext.Shading) {
        let top = max(0, fromY)
        let bottom = min(size.height, toY)
        guard bottom > top else { return }
        var layer = context
        layer.clip(to: Path(CGRect(x: 0, y: top, width: size.width, height: bottom - top)))
        layer.fill(outline, with: shading)
    }

    private static func appendSmoothRun(_ points: [CGPoint], to path: inout Path) {
        // A single sample has no connecting line and deliberately gets no dot.
        guard points.count >= 2 else { return }
        let widths = zip(points, points.dropFirst()).map { $1.x - $0.x }
        let slopes = zip(points, points.dropFirst()).enumerated().map { index, pair in
            (pair.1.y - pair.0.y) / widths[index]
        }
        var tangents = Array(repeating: CGFloat.zero, count: points.count)
        if points.count == 2 {
            tangents = [slopes[0], slopes[0]]
        } else {
            tangents[0] = endpointTangent(widths[0], widths[1], slopes[0], slopes[1])
            let last = slopes.count - 1
            tangents[points.count - 1] = endpointTangent(widths[last], widths[last - 1], slopes[last], slopes[last - 1])
            for index in 1..<(points.count - 1) {
                let left = slopes[index - 1], right = slopes[index]
                if left != 0, right != 0, (left > 0) == (right > 0) {
                    // PCHIP's weighted harmonic mean preserves shape even for unequal time intervals.
                    let a = 2 * widths[index] + widths[index - 1]
                    let b = widths[index] + 2 * widths[index - 1]
                    tangents[index] = (a + b) / (a / left + b / right)
                }
            }
        }
        path.move(to: points[0])
        for index in widths.indices {
            let start = points[index], end = points[index + 1]
            let third = widths[index] / 3
            path.addCurve(to: end,
                          control1: CGPoint(x: start.x + third, y: start.y + tangents[index] * third),
                          control2: CGPoint(x: end.x - third, y: end.y - tangents[index + 1] * third))
        }
    }

    private static func endpointTangent(_ width: CGFloat, _ adjacentWidth: CGFloat,
                                       _ slope: CGFloat, _ adjacentSlope: CGFloat) -> CGFloat {
        let tangent = ((2 * width + adjacentWidth) * slope - width * adjacentSlope) / (width + adjacentWidth)
        guard slope != 0, (tangent > 0) == (slope > 0) else { return 0 }
        if (slope > 0) != (adjacentSlope > 0), abs(tangent) > 3 * abs(slope) {
            return 3 * slope
        }
        return tangent
    }
}
