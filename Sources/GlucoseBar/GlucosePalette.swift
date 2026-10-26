import SwiftUI

/// User-selected display references. These colors encode distance from the selected interval.
enum GlucosePalette {
    static let lower = 3.9
    static let upper = 6.9
    static let fullRedDeviation = 2.0
    static let blue = Color(red: 0.12, green: 0.44, blue: 0.96)
    static let amber = Color(red: 1.0, green: 0.65, blue: 0.08)
    static let red = Color(red: 0.94, green: 0.13, blue: 0.18)

    static func color(for mmol: Double, normalColor: Color = blue) -> Color {
        guard mmol.isFinite else { return .secondary }
        if (lower...upper).contains(mmol) { return normalColor }
        let distance = mmol < lower ? lower - mmol : mmol - upper
        let amount = min(1, max(0, distance / fullRedDeviation))
        return Color(red: 1.0 + (0.94 - 1.0) * amount,
                     green: 0.65 + (0.13 - 0.65) * amount,
                     blue: 0.08 + (0.18 - 0.08) * amount)
    }

}
