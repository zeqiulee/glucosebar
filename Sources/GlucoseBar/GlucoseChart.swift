import Charts
import SwiftUI
import GlucoseCore

struct GlucoseChart: View {
    let readings: [GlucoseReading]
    var timeWindow: DateInterval? = nil
    @State private var hoverTime: Date?

    private var selectedReading: GlucoseReading? {
        hoverTime.flatMap { GlucoseChartSelection.nearest(to: $0, in: readings) }
    }

    private var xDomain: ClosedRange<Date> {
        if let timeWindow, timeWindow.duration > 0 { return timeWindow.start...timeWindow.end }
        let first = readings.first?.time ?? Date()
        let last = readings.last?.time ?? first
        return first < last ? first...last : first.addingTimeInterval(-300)...last.addingTimeInterval(300)
    }

    // Separate segments at >10-minute gaps so an outage is never drawn as a continuous measurement.
    private var points: [ChartPoint] {
        var group = 0
        return readings.enumerated().map { index, reading in
            if index > 0 && reading.time.timeIntervalSince(readings[index - 1].time) > 10 * 60 { group += 1 }
            return ChartPoint(reading: reading, group: group)
        }
    }

    private var yDomain: ClosedRange<Double> {
        let low = min(GlucosePalette.lower, readings.map(\.mmol).min() ?? GlucosePalette.lower)
        let high = max(GlucosePalette.upper, readings.map(\.mmol).max() ?? GlucosePalette.upper)
        return max(0, floor(low - 0.7))...ceil(high + 0.7)
    }

    var body: some View {
        Chart {
            RectangleMark(yStart: .value("参考下界", GlucosePalette.lower),
                          yEnd: .value("参考上界", GlucosePalette.upper))
                .foregroundStyle(GlucosePalette.blue.opacity(0.055))
                .accessibilityHidden(true)

            ForEach(points) { point in
                // Invisible anchors let Charts manage axes and domains. The overlay draws exact value colors.
                PointMark(x: .value("时间", point.reading.time), y: .value("血糖 mmol/L", point.reading.mmol))
                    .foregroundStyle(.clear)
                    .accessibilityHidden(true)
            }

            ForEach([GlucosePalette.lower, GlucosePalette.upper], id: \.self) { boundary in
                RuleMark(y: .value("自定义参考线", boundary))
                    .foregroundStyle(GlucosePalette.blue.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                    .accessibilityLabel("自定义参考线 \(String(format: "%.1f", boundary))")
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain, range: .plotDimension(padding: 0))
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let time = value.as(Date.self) {
                        Text(time, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                            .fixedSize()
                            .opacity(selectedReading == nil ? 1 : 0)
                    }
                }
            }
        }
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
        .chartPlotStyle { $0.background(Color.primary.opacity(0.025)) }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame {
                    let frame = geometry[anchor]
                    let projected = points.compactMap { point -> GlucoseTrace.Point? in
                        guard let x = proxy.position(forX: point.reading.time),
                              let y = proxy.position(forY: point.reading.mmol) else { return nil }
                        return GlucoseTrace.Point(position: CGPoint(x: x, y: y), group: point.group)
                    }
                    Canvas { context, size in
                        if let lowerY = proxy.position(forY: GlucosePalette.lower),
                           let upperY = proxy.position(forY: GlucosePalette.upper) {
                            GlucoseTrace.draw(context: &context, size: size, points: projected,
                                              lowerY: lowerY, upperY: upperY)
                        }
                    }
                    .frame(width: frame.width, height: frame.height).clipped()
                    .position(x: frame.midX, y: frame.midY)
                    .allowsHitTesting(false)

                    Rectangle().fill(.clear)
                        .contentShape(Rectangle())
                        .frame(width: frame.width, height: frame.height)
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                hoverTime = (0...frame.width).contains(location.x) && (0...frame.height).contains(location.y)
                                    ? proxy.value(atX: location.x, as: Date.self) : nil
                            case .ended:
                                hoverTime = nil
                            }
                        }
                        .onTapGesture { location in hoverTime = proxy.value(atX: location.x, as: Date.self) }
                        .position(x: frame.midX, y: frame.midY)

                    if let reading = selectedReading,
                       let x = proxy.position(forX: reading.time), let y = proxy.position(forY: reading.mmol) {
                        GlucoseChartMarker(reading: reading, point: CGPoint(x: x, y: y), plotSize: frame.size)
                            .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
        }
        .onChange(of: readings) { _, _ in hoverTime = nil }
        .accessibilityLabel("血糖历史曲线，单位毫摩尔每升。自定义参考区间3.9至6.9为蓝色，越界橘黄，偏离越大越接近红色。")
    }

    private struct ChartPoint: Identifiable {
        var id: String { reading.id }
        let reading: GlucoseReading
        let group: Int
    }
}
