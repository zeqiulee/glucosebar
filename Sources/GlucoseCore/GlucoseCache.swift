import CryptoKit
import Foundation

public enum GlucoseCacheError: LocalizedError, Sendable, Equatable {
    case cannotSave, cannotRemove

    public var errorDescription: String? {
        switch self {
        case .cannotSave: "无法保存本机缓存。当前读数仍可查看。"
        case .cannotRemove: "无法删除本机缓存。登录凭证未更换，请检查本机文件权限后重试。"
        }
    }
}

/// Optional local history. A cache is usable only with the credential that created it.
/// The credential itself is never encoded; schema 1 caches have no ownership binding and are ignored.
public struct GlucoseCache: Sendable {
    public struct Snapshot: Sendable {
        public let savedAt: Date
        public let series: [SensorSeries]
    }

    private struct Envelope: Codable {
        let schema: Int
        let credentialFingerprint: String
        let savedAt: Date
        let series: [SensorSeries]
    }

    public let fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    private static func fingerprint(_ credential: String) -> String {
        SHA256.hash(data: Data(credential.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    public func load(credential: String, now: Date = Date()) -> Snapshot? {
        guard !credential.isEmpty,
              let data = try? Data(contentsOf: fileURL),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.schema == 2,
              envelope.credentialFingerprint == Self.fingerprint(credential) else { return nil }
        let cutoff = now.addingTimeInterval(-14 * 24 * 3600)
        let series = envelope.series.map {
            SensorSeries(id: $0.id, label: $0.label, isActive: $0.isActive,
                         readings: $0.readings.filter {
                             $0.time >= cutoff && $0.time <= now && $0.mmol.isFinite && $0.mmol > 0 && $0.mmol <= 100
                         })
        }.filter { !$0.readings.isEmpty }
        return Snapshot(savedAt: envelope.savedAt, series: series)
    }

    public func save(series: [SensorSeries], savedAt: Date, credential: String) throws {
        guard !credential.isEmpty else { throw GlucoseCacheError.cannotSave }
        do {
            let manager = FileManager.default
            let directory = fileURL.deletingLastPathComponent()
            try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
            // Apply permissions to an existing cache directory too, before creating a replacement file.
            try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let envelope = Envelope(schema: 2, credentialFingerprint: Self.fingerprint(credential),
                                    savedAt: savedAt, series: series)
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: fileURL, options: .atomic)
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            // Never expose filesystem paths, encoded history, or credentials in user-visible errors.
            throw GlucoseCacheError.cannotSave
        }
    }

    public func remove() throws {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            // This API clears one cache file, never an unexpected directory tree.
            guard attributes[.type] as? FileAttributeType != .typeDirectory else {
                throw GlucoseCacheError.cannotRemove
            }
            try FileManager.default.removeItem(at: fileURL)
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return
        } catch {
            throw GlucoseCacheError.cannotRemove
        }
    }
}
