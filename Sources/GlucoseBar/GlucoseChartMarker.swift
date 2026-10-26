import SwiftUI
import GlucoseCore

/// Coordinates are local to the plot, including the time tag immediately under its x axis.
struct GlucoseChartMarker: View {
    let reading: GlucoseReading
    let point: CGPoint
    let plotSize: CGSize

    private var color: Color { GlucosePalette.color(for: reading.mmol) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: point.x, y: 0))
                path.addLine(to: CGPoint(x: point.x, y: plotSize.height))
            }
            .stroke(Color.primary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

            Circle().fill(color).frame(width: 7, height: 7)
                .overlay(Circle().stroke(.background, lineWidth: 1.5))
                .position(point)

            Text(String(format: "%.1f mmol/L", reading.mmol))
                .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                .foregroundStyle(color)
                .frame(width: 82, height: 24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(color.opacity(0.35), lineWidth: 0.5))
                .position(x: clampedX(point.x, width: 82), y: point.y >= 32 ? point.y - 21 : point.y + 21)

            Text(reading.time, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                .font(.system(size: 10, weight: .medium)).monospacedDigit()
                .foregroundStyle(.primary)
                .frame(width: 52, height: 20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                .position(x: clampedX(point.x, width: 52), y: plotSize.height + 11)
        }
        .frame(width: plotSize.width, height: plotSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("选中读数 \(String(format: "%.1f", reading.mmol)) 毫摩尔每升，\(reading.time.formatted(date: .omitted, time: .shortened))")
    }

    private func clampedX(_ value: CGFloat, width: CGFloat) -> CGFloat {
        min(max(value, width / 2), max(width / 2, plotSize.width - width / 2))
    }
}
