import AppKit
import SwiftUI
import GlucoseCore

private let previewEnd = Date(timeIntervalSince1970: 1_792_540_800)

private func syntheticReadings() -> [GlucoseReading] {
    (0...288).map { index in
        let hour = Double(index) / 12
        let value = 5.25 + 0.4 * sin(hour * 1.4) + 0.16 * cos(hour * 4.2)
            + 3.1 * exp(-pow((hour - 5.5) / 0.8, 2))
            - 2.2 * exp(-pow((hour - 12.3) / 0.7, 2))
            + 3.8 * exp(-pow((hour - 20.7) / 0.9, 2))
        return GlucoseReading(time: previewEnd.addingTimeInterval(Double(index - 288) * 300),
                              mmol: value, trend: 0)
    }
}

private struct HistoryPreview: View {
    let samples = syntheticReadings()
    private var window: DateInterval { DateInterval(start: previewEnd.addingTimeInterval(-24 * 3600), end: previewEnd) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("GlucoseBar").font(.title2.weight(.semibold))
                Spacer()
                Text("演示数据").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text("历史趋势").font(.headline)
                Spacer()
                Text("24 小时").foregroundStyle(.secondary)
            }
            GlucoseChart(readings: samples, timeWindow: window).frame(height: 205)
            HStack {
                Circle().fill(GlucosePalette.blue).frame(width: 6, height: 6)
                Text("参考 3.9–6.9").foregroundStyle(.secondary)
                Spacer()
                GlucoseRangeLabel(summary: .calculate(readings: samples, window: window, range: 3.9...6.9), hours: 24)
            }.font(.caption)
            Text("合成数据 · 无真实账号或个人健康记录").font(.caption2).foregroundStyle(.secondary)
        }.padding(24).frame(width: 500).background(.white)
    }
}

private struct MenuModesPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("曲线，或数字。你来选择。").font(.title2.weight(.semibold))
                Spacer()
                Text("演示数据").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 26) {
                Text("曲线模式").frame(width: 80, alignment: .leading)
                Image(nsImage: MenuBarSparkline(readings: syntheticReadings(), endDate: previewEnd, demo: true)
                    .menuImage(colorScheme: .dark))
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color(red: 0.02, green: 0.40, blue: 0.54), in: RoundedRectangle(cornerRadius: 8))
                Text("过去 12 小时").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 26) {
                Text("数字模式").frame(width: 80, alignment: .leading)
                HStack(spacing: 16) {
                    ForEach([5.4, 7.4, 9.6], id: \.self) { value in
                        Image(nsImage: MenuBarNumber(reading: .init(time: previewEnd, mmol: value, trend: value > 6.9 ? 1 : 0),
                                                    isCurrent: true, demo: true).menuImage(colorScheme: .dark))
                    }
                }.padding(14).background(Color(red: 0.10, green: 0.12, blue: 0.14), in: RoundedRectangle(cornerRadius: 8))
            }
            Text("菜单栏展示样式 · 所有读数均为合成示例").font(.caption2).foregroundStyle(.secondary)
        }.padding(26).frame(width: 600).background(.white)
    }
}

@main
struct PublicPreviews {
    @MainActor static func render<V: View>(_ view: V, path: URL) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .environment(\.timeZone, TimeZone(identifier: "Asia/Shanghai")!))
        renderer.scale = 2
        guard let bitmap = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: bitmap).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: path)
    }

    @MainActor static func main() throws {
        _ = NSApplication.shared
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try render(HistoryPreview(), path: output.appendingPathComponent("history.png"))
        try render(MenuModesPreview(), path: output.appendingPathComponent("menu-bar-modes.png"))
        print("Rendered two native previews using only synthetic data.")
    }
}
