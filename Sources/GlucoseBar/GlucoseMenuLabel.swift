import SwiftUI

struct GlucoseMenuLabel: View {
    @ObservedObject var store: GlucoseStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let reading = store.latest, store.menuDisplayMode == .number {
                Image(nsImage: MenuBarNumber(reading: reading, isCurrent: store.fresh || store.demo, demo: store.demo)
                    .menuImage(colorScheme: colorScheme))
                    .renderingMode(.original)
            } else if store.latest != nil {
                Image(nsImage: MenuBarSparkline(readings: store.selected?.readings ?? [], endDate: store.now,
                                               muted: !store.fresh && !store.demo, demo: store.demo)
                    .menuImage(colorScheme: colorScheme))
                    .renderingMode(.original)
            } else {
                Image(systemName: "minus")
            }
        }
        .help("\(statusDescription) · 点击展开")
        .accessibilityLabel(statusDescription)
    }

    private var statusDescription: String {
        if store.isLoadingCredential { return "正在读取钥匙串凭证，请在系统提示中完成授权" }
        guard let reading = store.latest else { return "等待血糖数据，点击展开设置" }
        let status = store.demo ? "演示数据" : (store.fresh ? "最新读数" : "旧读数")
        let trend: String
        switch reading.trend {
        case -2: trend = "快速下降"
        case -1: trend = "下降"
        case 0: trend = "平稳"
        case 1: trend = "上升"
        case 2: trend = "快速上升"
        default: trend = "趋势未知"
        }
        return "\(store.menuDisplayMode.title)，\(status)，\(String(format: "%.1f", reading.mmol)) mmol/L，\(trend)"
    }
}
