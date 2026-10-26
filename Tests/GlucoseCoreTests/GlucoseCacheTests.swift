import Foundation
#if canImport(XCTest) && !GLUCOSE_CORE_STANDALONE_TESTS
import XCTest
#endif
#if canImport(XCTest) || GLUCOSE_CORE_STANDALONE_TESTS
@testable import GlucoseCore

final class GlucoseCacheTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let firstCredential = "synthetic-test-credential-alpha"
    private let secondCredential = "synthetic-test-credential-beta"

    func testRoundTripBindsHistoryWithoutEncodingCredential() throws {
        try withCache { cache, _ in
            let expected = samples()
            try cache.save(series: expected, savedAt: now, credential: firstCredential)
            let restored = try XCTUnwrap(cache.load(credential: firstCredential, now: now))
            XCTAssertEqual(restored.savedAt, now)
            XCTAssertEqual(restored.series, expected)
            let data = try Data(contentsOf: cache.fileURL)
            let text = try XCTUnwrap(String(data: data, encoding: .utf8))
            XCTAssertTrue(!text.contains(firstCredential))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let fingerprint = try XCTUnwrap(object["credentialFingerprint"] as? String)
            XCTAssertEqual(fingerprint.count, 64)
            XCTAssertTrue(fingerprint.allSatisfy { "0123456789abcdef".contains($0) })
            XCTAssertEqual(object["schema"] as? Int, 2)
        }
    }

    func testDifferentCredentialCannotLoadExistingHistory() throws {
        try withCache { cache, _ in
            try cache.save(series: samples(), savedAt: now, credential: firstCredential)
            XCTAssertTrue(cache.load(credential: secondCredential, now: now) == nil)
            XCTAssertTrue(cache.load(credential: "", now: now) == nil)
            XCTAssertTrue(cache.load(credential: firstCredential, now: now) != nil)
        }
    }

    func testLegacyAndUnknownSchemasAreIgnored() throws {
        try withCache { cache, root in
            try FileManager.default.createDirectory(at: cache.fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            // Old schema 1 has no ownership binding, even when all health fields are otherwise valid.
            let legacy = LegacyCache(schema: 1, savedAt: now, series: samples())
            try JSONEncoder().encode(legacy).write(to: cache.fileURL)
            XCTAssertTrue(cache.load(credential: firstCredential, now: now) == nil)
            try cache.save(series: samples(), savedAt: now, credential: firstCredential)
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: cache.fileURL)) as? [String: Any])
            object["schema"] = 99
            try JSONSerialization.data(withJSONObject: object).write(to: cache.fileURL)
            XCTAssertTrue(cache.load(credential: firstCredential, now: now) == nil)
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
        }
    }

    func testCorruptCacheIsIgnored() throws {
        try withCache { cache, _ in
            try FileManager.default.createDirectory(at: cache.fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            for payload in ["broken", "{}", "null", "[]"] {
                try Data(payload.utf8).write(to: cache.fileURL)
                XCTAssertTrue(cache.load(credential: firstCredential, now: now) == nil)
            }
        }
    }

    func testSaveCreatesAndRestoresPrivatePermissions() throws {
        try withCache { cache, _ in
            let manager = FileManager.default
            let directory = cache.fileURL.deletingLastPathComponent()
            try cache.save(series: samples(), savedAt: now, credential: firstCredential)
            XCTAssertEqual(try permissionBits(directory), 0o700)
            XCTAssertEqual(try permissionBits(cache.fileURL), 0o600)
            try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
            try manager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: cache.fileURL.path)
            try cache.save(series: samples(), savedAt: now, credential: firstCredential)
            XCTAssertEqual(try permissionBits(directory), 0o700)
            XCTAssertEqual(try permissionBits(cache.fileURL), 0o600)
        }
    }

    func testRemovalIsIdempotentAndClearsHistory() throws {
        try withCache { cache, _ in
            try cache.remove()
            try cache.save(series: samples(), savedAt: now, credential: firstCredential)
            try cache.remove()
            XCTAssertTrue(!FileManager.default.fileExists(atPath: cache.fileURL.path))
            XCTAssertTrue(cache.load(credential: firstCredential, now: now) == nil)
            try cache.remove()
        }
    }

    func testRemovalFailureIsReportedWithoutDeletingUnexpectedDirectory() throws {
        try withCache { cache, _ in
            let manager = FileManager.default
            try manager.createDirectory(at: cache.fileURL, withIntermediateDirectories: true)
            let sentinel = cache.fileURL.appendingPathComponent("unrelated-test-file")
            try Data("synthetic".utf8).write(to: sentinel)
            XCTAssertThrowsError(try cache.remove()) { error in
                XCTAssertEqual(error as? GlucoseCacheError, .cannotRemove)
                XCTAssertTrue(!error.localizedDescription.contains(cache.fileURL.path))
                XCTAssertTrue(!error.localizedDescription.contains(firstCredential))
            }
            XCTAssertTrue(manager.fileExists(atPath: sentinel.path))
        }
    }

    func testWriteFailureAndEmptyCredentialUseStaticErrors() throws {
        try withCache { cache, root in
            XCTAssertThrowsError(try cache.save(series: samples(), savedAt: now, credential: "")) { error in
                XCTAssertEqual(error as? GlucoseCacheError, .cannotSave)
            }
            let blocker = root.appendingPathComponent("not-a-directory")
            try Data("synthetic".utf8).write(to: blocker)
            let invalid = GlucoseCache(fileURL: blocker.appendingPathComponent("readings.json"))
            XCTAssertThrowsError(try invalid.save(series: samples(), savedAt: now, credential: firstCredential)) { error in
                XCTAssertEqual(error as? GlucoseCacheError, .cannotSave)
                XCTAssertTrue(!error.localizedDescription.contains(root.path))
                XCTAssertTrue(!error.localizedDescription.contains(firstCredential))
            }
        }
    }

    func testLoadLimitsHistoryToRecentPastValidReadings() throws {
        try withCache { cache, _ in
            let history = [SensorSeries(id: "synthetic", label: "Synthetic", isActive: true, readings: [
                GlucoseReading(time: now.addingTimeInterval(-15 * 24 * 3600), mmol: 5),
                GlucoseReading(time: now.addingTimeInterval(-14 * 24 * 3600), mmol: 5.1),
                GlucoseReading(time: now.addingTimeInterval(-60), mmol: 0),
                GlucoseReading(time: now, mmol: 5.2),
                GlucoseReading(time: now.addingTimeInterval(60), mmol: 5.3)
            ])]
            try cache.save(series: history, savedAt: now, credential: firstCredential)
            let result = try XCTUnwrap(cache.load(credential: firstCredential, now: now))
            XCTAssertEqual(result.series[0].readings.map(\.mmol), [5.1, 5.2])
        }
    }

    private struct LegacyCache: Codable {
        let schema: Int
        let savedAt: Date
        let series: [SensorSeries]
    }

    private func samples() -> [SensorSeries] {
        [SensorSeries(id: "synthetic", label: "Synthetic", isActive: true, readings: [
            GlucoseReading(time: now.addingTimeInterval(-60), mmol: 5.1, trend: 1),
            GlucoseReading(time: now, mmol: 5.2, trend: 0)
        ])]
    }

    private func permissionBits(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.posixPermissions] as? NSNumber).intValue & 0o777
    }

    private func withCache(_ operation: (GlucoseCache, URL) throws -> Void) throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("glucosebar-cache-tests-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? manager.removeItem(at: root) }
        try operation(GlucoseCache(fileURL: root.appendingPathComponent("private/readings.json")), root)
    }
}
#endif
