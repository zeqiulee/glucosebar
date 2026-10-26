import AppKit
import Combine
import Foundation
import GlucoseCore

private enum ConnectionCleanupError: LocalizedError {
    case cache, credential, both

    var errorDescription: String? {
        switch self {
        case .cache: "登录凭证已清除，界面数据已清空，但本机缓存未能删除。请检查本机文件权限后清理缓存。"
        case .credential: "连接已停止，界面与本机缓存已清空，但钥匙串凭证未能删除。请解锁登录钥匙串后重试。"
        case .both: "连接已停止，界面数据已清空，但钥匙串凭证和本机缓存未能删除。请检查钥匙串及本机文件权限后重试。"
        }
    }
}

@MainActor
final class GlucoseStore: ObservableObject {
    static let shared = GlucoseStore()
    @Published private(set) var series: [SensorSeries] = []
    @Published private(set) var hasCredential = false
    @Published private(set) var isLoadingCredential = true
    @Published private(set) var isRefreshing = false
    @Published private(set) var issue: String?
    @Published private(set) var lastSync: Date?
    @Published private(set) var demo = false
    @Published private(set) var needsCleanup = false
    @Published var selectedID: String = "" {
        didSet { if !demo { UserDefaults.standard.set(selectedID, forKey: "selectedSensor") } }
    }
    @Published var hours = 6
    @Published var menuDisplayMode: MenuBarDisplayMode = .curve {
        didSet { UserDefaults.standard.set(menuDisplayMode.rawValue, forKey: MenuBarDisplayMode.preferenceKey) }
    }
    @Published private(set) var now = Date()
    private var token: String?
    private var loop: Task<Void, Never>?
    private var request: Task<Void, Never>?
    private var generation = 0
    private var nextFetch = Date.distantPast
    private var failures = 0
    private var cache: GlucoseCache {
        GlucoseCache(fileURL: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GlucoseBar", isDirectory: true).appendingPathComponent("readings.json"))
    }

    var selected: SensorSeries? {
        if !selectedID.isEmpty, let explicit = series.first(where: { $0.id == selectedID }) { return explicit }
        return series.sorted {
            if ($0.isActive == true) != ($1.isActive == true) { return $0.isActive == true }
            return ($0.readings.last?.time ?? .distantPast) > ($1.readings.last?.time ?? .distantPast)
        }.first
    }
    var latest: GlucoseReading? { selected?.readings.last }
    var age: TimeInterval? { latest.map { max(0, now.timeIntervalSince($0.time)) } }
    var stale: Bool { age.map { $0 > 10 * 60 } ?? true }
    var isEnded: Bool { selected?.isActive == false }
    var fresh: Bool { !demo && !stale && !isEnded && issue == nil && hasCredential }
    var canClearConnection: Bool {
        !isLoadingCredential && (hasCredential || needsCleanup || FileManager.default.fileExists(atPath: cache.fileURL.path))
    }
    var visibleWindow: DateInterval? {
        guard let latest, hours > 0 else { return nil }
        return DateInterval(start: latest.time.addingTimeInterval(-Double(hours) * 3600), end: latest.time)
    }
    var visibleReadings: [GlucoseReading] {
        guard let visibleWindow else { return [] }
        // Anchor to the newest sample so an offline cached curve remains inspectable with its timestamp.
        return selected?.readings.filter { visibleWindow.contains($0.time) } ?? []
    }
    var rangeSummary: GlucoseRangeSummary? {
        guard let visibleWindow, let selected else { return nil }
        // Use all samples so a segment crossing the window's start is correctly clipped.
        return GlucoseRangeSummary.calculate(readings: selected.readings, window: visibleWindow,
                                             range: GlucosePalette.lower...GlucosePalette.upper)
    }
    var menuTitle: String {
        if demo { return "演示" }
        guard hasCredential else { return "血糖 · 设置" }
        guard let latest else { return "血糖 --" }
        let value = String(format: "%.1f", latest.mmol)
        return fresh ? "\(value) \(latest.trendSymbol ?? "·")" : "\(value) · 旧"
    }

    init() {
        menuDisplayMode = UserDefaults.standard.string(forKey: MenuBarDisplayMode.preferenceKey)
            .flatMap(MenuBarDisplayMode.init(rawValue:)) ?? .curve
        selectedID = UserDefaults.standard.string(forKey: "selectedSensor") ?? ""
        loadStoredCredential()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.now = Date()
                if self.hasCredential && !self.demo && self.now >= self.nextFetch { self.refresh() }
                try? await Task.sleep(for: .seconds(10))
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.now = Date(); self?.refresh() }
        }
    }

    private func loadStoredCredential() {
        let version = generation
        Task { [weak self] in
            guard let self else { return }
            defer { self.isLoadingCredential = false }
            do {
                // System consent may take time. Never hold the main thread while the Keychain waits.
                let loaded = try await Task.detached(priority: .userInitiated) { try Credentials.load() }.value
                guard version == self.generation else { return }
                self.token = loaded
                self.hasCredential = loaded != nil
                if self.hasCredential { self.loadCache(); self.nextFetch = .distantPast; self.refresh() }
            } catch {
                guard version == self.generation else { return }
                self.issue = error.localizedDescription
            }
        }
    }

    func saveCredential(_ input: String) throws {
        let normalized = try Credentials.normalized(input)
        generation += 1
        request?.cancel()
        request = nil
        isRefreshing = false
        // Stop old requests before removing their cache. If removal fails, retain the old credential.
        // The fingerprint additionally prevents loading an old account's history after a credential change.
        do { try cache.remove() }
        catch {
            issue = GlucoseCacheError.cannotRemove.localizedDescription
            throw GlucoseCacheError.cannotRemove
        }
        try Credentials.save(normalized)
        token = normalized
        hasCredential = true
        needsCleanup = false
        isLoadingCredential = false
        demo = false
        // A replaced credential might belong to another account. Never retain the old account's samples.
        series = []; selectedID = ""; lastSync = nil; issue = nil; failures = 0
        nextFetch = .distantPast
        refresh()
    }

    func clearCredential() throws {
        // Clear in-memory data even if one of the persistent deletion steps fails.
        generation += 1; request?.cancel(); request = nil; isRefreshing = false
        token = nil; hasCredential = false; demo = false; series = []; lastSync = nil; issue = nil
        isLoadingCredential = false
        selectedID = ""
        var credentialRemoved = true
        var cacheRemoved = true
        do { try Credentials.delete() } catch { credentialRemoved = false }
        do { try cache.remove() } catch { cacheRemoved = false }
        // A retained Keychain item keeps the clear button available; there is no token to refresh with.
        hasCredential = !credentialRemoved
        needsCleanup = !credentialRemoved || !cacheRemoved
        let failure: ConnectionCleanupError?
        switch (credentialRemoved, cacheRemoved) {
        case (true, true): failure = nil
        case (true, false): failure = .cache
        case (false, true): failure = .credential
        case (false, false): failure = .both
        }
        if let failure {
            issue = failure.localizedDescription
            throw failure
        }
    }

    func refresh() {
        guard hasCredential, !demo, !isRefreshing, let token else { return }
        isRefreshing = true
        let version = generation
        request = Task { [weak self] in
            do {
                let fetched = try await CloudClient().fetch(token: token)
                guard let self, !Task.isCancelled, version == self.generation else { return }
                self.series = fetched
                self.chooseSensor()
                self.now = Date(); self.lastSync = self.now; self.issue = nil; self.failures = 0
                self.nextFetch = self.now.addingTimeInterval(60)
                self.saveCache()
                self.isRefreshing = false
            } catch is CancellationError {
                guard let self, version == self.generation else { return }
                self.isRefreshing = false
            } catch {
                guard let self, version == self.generation else { return }
                self.now = Date()
                if case CloudError.authentication = error {
                    self.issue = error.localizedDescription
                    self.nextFetch = self.now.addingTimeInterval(5 * 60)
                } else if let known = error as? CloudError {
                    self.issue = known.localizedDescription
                    self.failures += 1
                    self.nextFetch = self.now.addingTimeInterval(min(300, 60 * pow(2, Double(min(self.failures, 3)))))
                } else if case SisensingParserError.noSamples = error {
                    self.series = []; self.lastSync = self.now
                    self.issue = "云端暂时没有可用读数，请确认 iPhone 已上传数据。"
                    self.nextFetch = self.now.addingTimeInterval(60)
                    self.saveCache()
                } else {
                    self.issue = "暂时无法解析云端数据，请稍后重试。"
                    self.nextFetch = self.now.addingTimeInterval(120)
                }
                self.isRefreshing = false
            }
        }
    }

    func enterDemo() {
        guard !isLoadingCredential else { return }
        generation += 1; request?.cancel(); isRefreshing = false
        demo = true; issue = nil; now = Date(); lastSync = nil
        let points = (0...288).map { index in
            let step = Double(index)
            return GlucoseReading(time: now.addingTimeInterval((step - 288) * 300),
                                  mmol: 5.6 + 0.55 * sin(step / 13) + 0.22 * cos(step / 6), trend: 0)
        }
        series = [SensorSeries(id: "demo", label: "演示传感器", isActive: true, readings: points)]
        selectedID = "demo"
    }

    func exitDemo() {
        demo = false; series = []; issue = nil; lastSync = nil
        selectedID = UserDefaults.standard.string(forKey: "selectedSensor") ?? ""
        if hasCredential { loadCache(); nextFetch = .distantPast; refresh() }
    }

    private func chooseSensor() {
        // Empty selection means automatic: keep following the newest active sensor after replacement.
        if !selectedID.isEmpty && !series.contains(where: { $0.id == selectedID }) { selectedID = "" }
    }

    private func saveCache() {
        guard !demo, let lastSync, let token else { return }
        do {
            try cache.save(series: series, savedAt: lastSync, credential: token)
        } catch { /* Cache is optional. No health data or error payload is logged. */ }
    }
    private func loadCache() {
        guard let token, let snapshot = cache.load(credential: token) else { return }
        series = snapshot.series
        lastSync = snapshot.savedAt
        issue = "显示上次缓存，正在连接云端。"
        chooseSensor()
    }
}
