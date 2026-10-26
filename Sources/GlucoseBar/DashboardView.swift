import AppKit
import SwiftUI
import GlucoseCore

struct DashboardView: View {
    @ObservedObject var store: GlucoseStore

    private var accent: Color { store.demo ? .purple : (store.fresh ? .teal : .orange) }
    private var status: String? {
        if store.isLoadingCredential { return "读取凭证" }
        if store.demo { return "演示数据" }
        if !store.hasCredential { return "等待连接" }
        if store.issue != nil { return store.latest == nil ? "连接异常" : "连接异常 · 上次读数" }
        if store.isEnded { return "传感器未运行" }
        if store.latest == nil { return "等待数据" }
        if store.stale { return "数据已过期" }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform.path").foregroundStyle(accent)
                Text("GlucoseBar").font(.headline)
                Spacer()
                if store.isRefreshing { ProgressView().controlSize(.mini) }
                if let status { Text(status).font(.caption).foregroundStyle(accent) }
            }

            if let latest = store.latest {
                readingHeader(latest)
                HStack {
                    Text("时间范围").font(.subheadline.weight(.medium)).fixedSize()
                    Spacer()
                    Picker("时间范围", selection: $store.hours) {
                        ForEach([3, 6, 12, 24], id: \.self) { Text("\($0)h").tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 205)
                }
                GlucoseChart(readings: store.visibleReadings, timeWindow: store.visibleWindow)
                    .frame(height: 175)
                HStack(spacing: 5) {
                    Circle().fill(GlucosePalette.blue).frame(width: 6, height: 6)
                    Text("参考 3.9–6.9").foregroundStyle(.secondary)
                    Spacer()
                    GlucoseRangeLabel(summary: store.rangeSummary, hours: store.hours)
                }.font(.caption2)
                HStack {
                    Image(systemName: "clock")
                    Text("测量于 \(latest.time.formatted(date: .abbreviated, time: .shortened))")
                    Spacer()
                    if let age = store.age { Text(ageDescription(age)) }
                }
                .font(.caption).foregroundStyle(.secondary)

                if store.series.count > 1 {
                    Picker("传感器", selection: $store.selectedID) {
                        Text("自动跟随当前传感器").tag("")
                        ForEach(store.series) { sensor in
                            Text(sensor.label + (sensor.isActive == true ? " · 使用中" : " · 历史") +
                                 (sensor.readings.last.map { " · " + $0.time.formatted(date: .abbreviated, time: .shortened) } ?? ""))
                                .tag(sensor.id)
                        }
                    }.font(.caption)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "drop.circle").font(.system(size: 36)).foregroundStyle(.teal)
                    Text(store.isLoadingCredential ? "正在读取钥匙串凭证" : (store.hasCredential ? "等待第一条血糖记录" : "把血糖放在菜单栏"))
                        .font(.title3.weight(.semibold))
                    Text(store.isLoadingCredential ? "如系统提示，请在 macOS 对话框中完成钥匙串授权。" : (store.hasCredential ? "正在读取本人硅基云端记录。请确认 iPhone 上已有最新数据。" : "连接国内版「硅基动感」，在这里查看当前数值和历史曲线。"))
                        .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if !store.hasCredential {
                        Button("连接硅基动感…") { showSettings() }.buttonStyle(.borderedProminent).tint(.teal)
                        Button("先看界面演示") { store.enterDemo() }.buttonStyle(.link).disabled(store.isLoadingCredential)
                    }
                }.padding(.vertical, 8)
            }

            if let issue = store.issue {
                Label(issue, systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if store.demo {
                HStack {
                    Label("模拟读数，未连接真实账号", systemImage: "eye")
                    Spacer()
                    Button("退出演示") { store.exitDemo() }
                }.font(.caption).foregroundStyle(.purple)
            }
            Divider()
            HStack {
                Button { store.refresh() } label: { Label("刷新", systemImage: "arrow.clockwise") }
                    .disabled(!store.hasCredential || store.isRefreshing || store.demo)
                Button { showSettings() } label: { Label("设置", systemImage: "slider.horizontal.3") }
                Spacer()
                Button("退出") { NSApplication.shared.terminate(nil) }
            }.buttonStyle(.borderless).font(.caption)
        }
        .padding(20).frame(width: 420)
    }

    private func readingHeader(_ latest: GlucoseReading) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(String(format: "%.1f", latest.mmol))
                .font(.system(size: 50, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(latest.trendSymbol ?? "·").font(.system(size: 30, weight: .medium))
                .accessibilityLabel(latest.trendSymbol == nil ? "趋势未知" : "血糖趋势")
            Text("mmol/L").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }.foregroundStyle(store.fresh || store.demo ? GlucosePalette.color(for: latest.mmol) : .secondary)
    }

    private func ageDescription(_ age: TimeInterval) -> String {
        if age < 60 { return "刚刚" }
        if age < 3600 { return "\(Int(age / 60)) 分钟前" }
        if age < 86400 { return "\(Int(age / 3600)) 小时前" }
        return "\(Int(age / 86400)) 天前"
    }

    private func showSettings() {
        AppWindows.showSettings(store: store)
    }
}
