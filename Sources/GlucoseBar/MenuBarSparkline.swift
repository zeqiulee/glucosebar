import AppKit
import SwiftUI
import GlucoseCore

/// A fixed, wall-clock 12-hour window, independent of the expanded chart's range picker.
struct MenuBarSparkline: View {
    static let width: CGFloat = 48
    static let height: CGFloat = 18
    static let duration: TimeInterval = 12 * 3600

    let readings: [GlucoseReading]
    let endDate: Date
    var muted = false
    var demo = false

    private var window: [GlucoseReading] {
        let start = endDate.addingTimeInterval(-Self.duration)
        let samples = readings.filter { $0.time <= endDate }
        guard let first = samples.firstIndex(where: { $0.time >= start }) else { return [] }
        // Retain one boundary neighbour so the left edge can be cropped at the actual window start.
        return Array(samples[max(0, first - 1)...])
    }

    var body: some View {
        Canvas { context, size in
            let samples = window
            guard samples.count >= 2 else { return }
            let start = endDate.addingTimeInterval(-Self.duration)
            let inWindow = samples.filter { $0.time >= start }
            let low = min(GlucosePalette.lower, inWindow.map(\.mmol).min() ?? GlucosePalette.lower) - 0.65
            let high = max(GlucosePalette.upper, inWindow.map(\.mmol).max() ?? GlucosePalette.upper) + 0.65
            let bottom = max(0, low)
            let inset: CGFloat = 1.1
            let plotHeight = max(1, size.height - 2 * inset)
            func y(_ value: Double) -> CGFloat {
                inset + (high - value) / (high - bottom) * plotHeight
            }
            var group = 0
            let points = samples.enumerated().map { index, sample in
                if index > 0 && sample.time.timeIntervalSince(samples[index - 1].time) > 10 * 60 { group += 1 }
                return GlucoseTrace.Point(
                    position: CGPoint(x: inset + sample.time.timeIntervalSince(start) / Self.duration * (size.width - 2 * inset),
                                      y: y(sample.mmol)),
                    group: group)
            }
            // A subtle dark edge keeps the white core legible over light menu-bar wallpapers too.
            context.stroke(GlucoseTrace.path(through: points), with: .color(.black.opacity(0.25)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            GlucoseTrace.draw(context: &context, size: size, points: points,
                              lowerY: y(GlucosePalette.lower), upperY: y(GlucosePalette.upper),
                              lineWidth: 1.5, normalColor: .white)
        }
        .frame(width: Self.width, height: Self.height)
        .clipped()
        .opacity(muted ? 0.4 : 1)
        .accessibilityLabel("过去12小时血糖趋势")
    }

    @MainActor
    func menuImage(colorScheme: ColorScheme) -> NSImage {
        let content = HStack(spacing: 3) {
            self
            if demo {
                Text("演").font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 2).background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 2))
            }
        }.environment(\.colorScheme, colorScheme)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.isOpaque = false
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: Self.width, height: Self.height))
        image.size = NSSize(width: demo ? Self.width + 16 : Self.width, height: Self.height)
        image.isTemplate = false
        return image
    }
}

