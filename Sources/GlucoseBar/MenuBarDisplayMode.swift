import SwiftUI

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case curve
    case number

    static let preferenceKey = "menuBarDisplayMode"
    var id: String { rawValue }
    var title: String { self == .curve ? "曲线模式" : "数字模式" }
}

struct MenuBarDisplaySettings: View {
    @Binding var mode: MenuBarDisplayMode

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("状态栏显示").font(.headline)
                Picker("显示模式", selection: $mode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }.pickerStyle(.segmented)
                Text(mode == .curve
                     ? "最近12小时曲线：参考区间内白色，越界橘黄至红色。"
                     : "数值固定白色；趋势箭头在参考区间内为绿色，越界橘黄至红色。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("自定义参考区间 3.9–6.9 mmol/L · 切换后立即生效")
                    .font(.caption2).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
        }
    }
}
