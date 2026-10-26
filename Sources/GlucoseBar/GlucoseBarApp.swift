import AppKit
import Combine
import SwiftUI
import GlucoseCore

@main
struct GlucoseBarApp: App {
    @NSApplicationDelegateAdaptor(GlucoseAppDelegate.self) private var appDelegate
    @StateObject private var store = GlucoseStore.shared
    var body: some Scene {
        MenuBarExtra {
            DashboardView(store: store)
        } label: {
            GlucoseMenuLabel(store: store)
        }
        .menuBarExtraStyle(.window)

    }
}

@MainActor
final class GlucoseAppDelegate: NSObject, NSApplicationDelegate {
    private var credentialObservation: AnyCancellable?
    func applicationDidFinishLaunching(_ notification: Notification) {
        credentialObservation = GlucoseStore.shared.$isLoadingCredential.filter { !$0 }.first().sink { _ in
            Task { @MainActor in
                if !GlucoseStore.shared.hasCredential { AppWindows.showSettings(store: .shared) }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppWindows.showSettings(store: .shared)
        return true
    }
}

@MainActor
enum AppWindows {
    private static var settings: NSWindow?
    private static var dashboard: NSWindow?
    static func showDashboard(store: GlucoseStore) {
        if dashboard == nil {
            let host = NSHostingController(rootView: DashboardView(store: store))
            let window = NSWindow(contentViewController: host)
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.title = "GlucoseBar · 血糖面板"
            window.isReleasedWhenClosed = false
            window.center()
            dashboard = window
        }
        dashboard?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    static func closeDashboard() { dashboard?.close() }
    static func showSettings(store: GlucoseStore) {
        if settings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 650),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "GlucoseBar · 连接设置"
            window.contentView = NSHostingView(rootView: ConnectionView(store: store))
            window.isReleasedWhenClosed = false
            window.center()
            settings = window
        }
        settings?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
