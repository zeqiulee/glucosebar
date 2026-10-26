import SwiftUI
import GlucoseCore

struct GlucoseRangeLabel: View {
    let summary: GlucoseRangeSummary?
    let hours: Int

    private var percentageText: String {
        guard let percentage = summary?.percentage else { return "--" }
        return String(format: "%.1f%%", percentage)
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("健康比例：").foregroundStyle(.secondary)
            Text(percentageText).fontWeight(.medium).foregroundStyle(.primary)
        }
        .font(.caption2).monospacedDigit().fixedSize()
        .help(explanation)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("健康比例\(percentageText == "--" ? "暂无统计" : percentageText)。\(explanation)")
    }

    private var explanation: String {
        guard let summary, summary.percentage != nil else {
            return "所选\(hours)小时内暂无足够的连续读数，无法统计时长。"
        }
        let seconds = Int(summary.inRangeDuration.rounded())
        let elapsed = seconds >= 3600 ? "\(seconds / 3600)小时\(seconds % 3600 / 60)分钟"
            : (seconds >= 60 ? "\(seconds / 60)分钟\(seconds % 60)秒" : "\(seconds)秒")
        return "截至图中最新测量时间，3.9–6.9 mmol/L 内的估算时长为\(elapsed)，除以所选完整\(hours)小时。有效数据覆盖\(String(format: "%.1f%%", summary.coveragePercentage))；缺失数据不计入区间内时长。"
    }
}
