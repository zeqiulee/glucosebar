import AppKit
import SwiftUI
import GlucoseCore

struct MenuBarNumber: View {
    let reading: GlucoseReading
    let isCurrent: Bool
    var demo = false

    var body: some View {
        HStack(spacing: 3) {
            if demo { Text("演示").font(.system(size: 9, weight: .medium)) }
            Text(String(format: "%.1f", reading.mmol)).monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 0.5)
            Text(reading.trendSymbol ?? "·")
                .foregroundStyle(isCurrent ? GlucosePalette.color(for: reading.mmol, normalColor: .green) : .secondary)
            if !isCurrent { Text("旧").font(.system(size: 9, weight: .medium)) }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 1)
        .frame(height: MenuBarSparkline.height)
    }

    @MainActor
    func menuImage(colorScheme: ColorScheme) -> NSImage {
        let renderer = ImageRenderer(content: self.environment(\.colorScheme, colorScheme))
        renderer.scale = 2
        renderer.isOpaque = false
        guard let bitmap = renderer.cgImage else {
            return NSImage(size: NSSize(width: 48, height: MenuBarSparkline.height))
        }
        let image = NSImage(cgImage: bitmap, size: NSSize(width: CGFloat(bitmap.width) / renderer.scale,
                                                       height: CGFloat(bitmap.height) / renderer.scale))
        image.isTemplate = false
        return image
    }
}
