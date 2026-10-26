import AppKit
import ServiceManagement
import SwiftUI

struct ConnectionView: View {
    @ObservedObject var store: GlucoseStore
    @State private var tokenInput = ""
    @State private var localError: String?
    @State private var saved = false
    @State private var showRemoval = false
    @State private var showGuide = true
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.path").font(.system(size: 32)).foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("连接硅基动感").font(.title2.weight(.semibold))
                        Text("国内版 · GS1 · 本人云端记录").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.isLoadingCredential {
                        ProgressView().controlSize(.small)
                        Text("正在读取凭证").font(.caption).foregroundStyle(.secondary)
                    } else if store.hasCredential {
                        Label("已保存凭证", systemImage: "key.fill").font(.caption).foregroundStyle(.teal)
                    }
                }

                MenuBarDisplaySettings(mode: $store.menuDisplayMode)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("登录凭证").font(.headline)
                        SecureField("粘贴 token 或 Bearer 值", text: $tokenInput)
                            .textFieldStyle(.roundedBorder).onSubmit(save)
                            .privacySensitive()
                        Text("保存至这台 Mac 的系统钥匙串。输入不会显示在日志或导出文件中。")
                            .font(.caption).foregroundStyle(.secondary)
                        if store.isLoadingCredential {
                            Text("如系统提示，请在 macOS 对话框中完成钥匙串授权。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        HStack {
                            Button("保存并验证连接", action: save)
                                .buttonStyle(.borderedProminent).tint(.teal)
                                .disabled(store.isLoadingCredential || tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            if store.isRefreshing { ProgressView().controlSize(.small) }
                            if saved && !store.isRefreshing && store.issue == nil && store.latest != nil {
                                Label("已读到云端数据", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.teal)
                            }
                        }
                        if let message = localError ?? store.issue {
                            Text(message).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }

                DisclosureGroup("如何在 iPhone 获取凭证", isExpanded: $showGuide) {
                    VStack(alignment: .leading, spacing: 10) {
                        step("1", "在 iPhone 登录「硅基动感」，确认能看到最新血糖。")
                        step("2", "使用支持 HTTPS 解密的抓包工具，按向导安装根证书。在「设置 → 通用 → 关于本机 → 证书信任设置」开启该证书的完全信任。")
                        step("3", "开始抓取并筛选 api.sisensing.com，打开硅基动感刷新一次。在返回 200 的请求头中找到 Authorization，复制 Bearer 后面的值。")
                        step("4", "将凭证直接粘贴到上方输入框，点「保存并验证连接」。请勿把凭证发到聊天或公开分享抓包记录。")
                        step("5", "完成后停止抓包及其 VPN，在「设置 → 通用 → VPN 与设备管理」移除该工具的证书描述文件，并清除抓包记录。")
                        HStack {
                            Link("抓包工具官方说明", destination: URL(string: "https://docs.httpcatcher.com/quickstart")!)
                            Link("接口参考", destination: URL(string: "https://github.com/ImLovinIt/nightscout-sisensingcgm-uploader#obtain-sisensing-api-bearer-token")!)
                        }.font(.caption)
                        Text("重新安装硅基 App 或在其他设备登录后，可能需要重新获取凭证。此工具使用社区已验证的 App 接口，当前账号仍需实际验证。")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 8)
                }

                Divider()
                Toggle("登录 Mac 后启动", isOn: Binding(get: { loginEnabled }, set: { enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                            loginEnabled = SMAppService.mainApp.status == .enabled
                            localError = nil
                        } catch {
                            localError = "无法修改登录启动设置，请在系统设置的「通用 → 登录项」中检查。"
                        }
                    }))
                HStack {
                    Button(store.demo ? "退出演示" : "预览界面演示") {
                        if store.demo { store.exitDemo(); AppWindows.closeDashboard() }
                        else { store.enterDemo(); AppWindows.showDashboard(store: store) }
                    }.disabled(store.isLoadingCredential)
                    if store.latest != nil && !store.demo {
                        Button("查看血糖面板") { AppWindows.showDashboard(store: store) }
                    }
                    Spacer()
                    Button("清除凭证与本机缓存", role: .destructive) { showRemoval = true }
                        .disabled(!store.canClearConnection)
                }
                Text("每分钟检查云端更新；读数超过 10 分钟会标为过期。历史记录缓存在本机 Application Support，清除连接时一并删除。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("自定义参考区间为 3.9–6.9 mmol/L：状态栏数字固定白色，箭头在区间内为绿色，小曲线在区间内为白色；展开面板曲线在区间内为蓝色。越界橘黄，偏离越大越接近红色。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("GlucoseBar \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版") · 独立查看工具，使用原 App 的告警。")
                    .font(.caption2).foregroundStyle(.tertiary)
            }.padding(26)
        }
        .frame(width: 540, height: 650)
        .confirmationDialog("清除本机连接？", isPresented: $showRemoval) {
            Button("清除凭证与缓存", role: .destructive) {
                defer { tokenInput = ""; saved = false }
                do { try store.clearCredential(); localError = nil }
                catch { localError = error.localizedDescription }
            }
        } message: { Text("这会删除钥匙串中的凭证及本机缓存。之后可重新连接。") }
        .onDisappear { tokenInput = "" }
        .onAppear { showGuide = !store.hasCredential }
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number).font(.caption.weight(.semibold)).foregroundStyle(.teal).frame(width: 16)
            Text(text).font(.caption).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func save() {
        guard !store.isLoadingCredential else { return }
        do {
            try store.saveCredential(tokenInput)
            tokenInput = ""; localError = nil; saved = true
        } catch { localError = error.localizedDescription }
    }
}
