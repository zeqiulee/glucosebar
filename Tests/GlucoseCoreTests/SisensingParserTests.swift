import Foundation
#if canImport(XCTest) && !GLUCOSE_CORE_STANDALONE_TESTS
import XCTest
#endif
#if canImport(XCTest) || GLUCOSE_CORE_STANDALONE_TESTS
@testable import GlucoseCore

final class SisensingParserTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testParsesMmolWithoutConvertingUnits() throws {
        let parsed = try parse(devices: [[
            "deviceId": "sensor-a",
            "deviceName": "GS1",
            "deviceStatus": 1,
            "glucoseInfos": [["t": 1_699_999_940_000, "v": 5.8, "s": 1]]
        ]])
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].id, "sensor-a")
        XCTAssertEqual(parsed[0].label, "GS1")
        XCTAssertEqual(parsed[0].isActive, true)
        XCTAssertEqual(parsed[0].readings[0].mmol, 5.8)
        XCTAssertEqual(parsed[0].readings[0].time, Date(timeIntervalSince1970: 1_699_999_940))
        XCTAssertEqual(parsed[0].readings[0].trendSymbol, "↗")
    }

    func testAcceptsSingleDeviceObjectAndNumericStrings() throws {
        let parsed = try parse(devices: [
            "deviceId": "sensor-b",
            "deviceStatus": "1",
            "glucoseInfos": [["t": "1699999940123", "v": " 6.2 ", "s": "-2"]]
        ])
        let reading = try XCTUnwrap(parsed.first?.readings.first)
        XCTAssertEqual(reading.time.timeIntervalSince1970, 1_699_999_940.123, accuracy: 0.0001)
        XCTAssertEqual(reading.mmol, 6.2)
        XCTAssertEqual(reading.trendSymbol, "↓")
        XCTAssertEqual(parsed[0].isActive, true)
    }

    func testAcceptsSecondsAndMillisecondsAndSortsByMeasurementTime() throws {
        let parsed = try parse(devices: [["glucoseInfos": [
            ["t": 1_699_999_980_000, "v": 6.0],
            ["t": "1699999920", "v": 5.0],
            ["t": 1_699_999_950.5, "v": 5.5]
        ]]])
        XCTAssertEqual(parsed[0].readings.map(\.mmol), [5.0, 5.5, 6.0])
        XCTAssertEqual(parsed[0].readings.map { $0.time.timeIntervalSince1970 }, [
            1_699_999_920, 1_699_999_950.5, 1_699_999_980
        ])
    }

    func testDuplicateMeasurementTimesUseLastObservation() throws {
        let parsed = try parse(devices: [["glucoseInfos": [
            ["t": 1_699_999_940_000, "v": 5.0, "s": 1],
            ["t": "1699999940", "v": "5.2", "s": 2],
            ["t": 1_699_999_940_000, "v": 0]
        ]]])
        XCTAssertEqual(parsed[0].readings.count, 1)
        XCTAssertEqual(parsed[0].readings[0].mmol, 5.2)
        XCTAssertEqual(parsed[0].readings[0].trend, 2)
    }

    func testSkipsInvalidValuesAndFutureDatesWithoutDroppingValidPoints() throws {
        let values: [Any] = [0, -1, 100.1, "NaN", "Infinity", "-Infinity", true, NSNull(), "bad"]
        var points: [[String: Any]] = values.map { ["t": 1_699_999_940_000, "v": $0] }
        points += [
            ["t": "NaN", "v": 5.0],
            ["t": "Infinity", "v": 5.0],
            ["t": true, "v": 5.0],
            ["t": 0, "v": 5.0],
            ["t": -1, "v": 5.0],
            ["t": 1_700_000_121_000, "v": 5.0],
            ["t": 1_700_000_120_000, "v": 100.0],
            ["t": 1_699_999_940_000, "v": 0.1]
        ]
        let parsed = try parse(devices: [["glucoseInfos": points]])
        XCTAssertEqual(parsed[0].readings.map(\.mmol), [0.1, 100.0])
    }

    func testMalformedPointsAreSkipped() throws {
        let parsed = try parse(devices: [["glucoseInfos": [
            "bad", NSNull(), ["v": 5.0], ["t": 1_699_999_940_000],
            ["t": 1_699_999_940_000, "v": 5.7]
        ] as [Any]]])
        XCTAssertEqual(parsed[0].readings.map(\.mmol), [5.7])
    }

    func testUnknownOrMissingTrendNeverShowsFlatArrow() throws {
        let points: [[String: Any]] = [
            ["t": 1_699_999_910_000, "v": 5, "s": 3],
            ["t": 1_699_999_920_000, "v": 5, "s": -3],
            ["t": 1_699_999_930_000, "v": 5, "s": 0.5],
            ["t": 1_699_999_940_000, "v": 5, "s": true],
            ["t": 1_699_999_950_000, "v": 5]
        ]
        let parsed = try parse(devices: [["glucoseInfos": points]])
        XCTAssertTrue(parsed[0].readings.allSatisfy { $0.trend == nil && $0.trendSymbol == nil })
    }

    func testKnownTrendSymbols() {
        XCTAssertEqual((-2...2).map {
            GlucoseReading(time: now, mmol: 5, trend: $0).trendSymbol
        }, ["↓", "↘", "→", "↗", "↑"])
    }

    func testDevicesRemainSeparateEvenWithMatchingTimestampOrIdentifier() throws {
        let parsed = try parse(devices: [
            ["deviceId": "same-id", "deviceStatus": 0,
             "glucoseInfos": [["t": 1_699_999_940_000, "v": 5.0]]],
            ["deviceId": "same-id", "deviceStatus": 1,
             "glucoseInfos": [["t": 1_699_999_940_000, "v": 6.0]]],
            ["glucoseInfos": [["t": 1_699_999_940_000, "v": 7.0]]],
            ["glucoseInfos": [["t": 1_699_999_940_000, "v": 8.0]]]
        ])
        XCTAssertEqual(parsed.count, 4)
        XCTAssertEqual(Set(parsed.map(\.id)).count, 4)
        XCTAssertEqual(parsed.map { $0.readings.map(\.mmol) }, [[5.0], [6.0], [7.0], [8.0]])
        XCTAssertEqual(parsed.map(\.isActive), [false, true, nil, nil])
    }

    func testDeviceObjectMapUsesKeysAsSeparateIdentifiers() throws {
        let parsed = try parse(devices: [
            "sensor-z": ["glucoseInfos": [["t": 1_699_999_940_000, "v": 6.0]]],
            "sensor-a": ["glucoseInfos": [["t": 1_699_999_940_000, "v": 5.0]]]
        ])
        XCTAssertEqual(parsed.map(\.id), ["sensor-a", "sensor-z"])
        XCTAssertEqual(parsed.map { $0.readings[0].mmol }, [5.0, 6.0])
    }

    func testNoSamplesThrowsForEmptyOrEntirelyInvalidDeviceData() throws {
        let cases: [Any] = [
            [], NSNull(), [["glucoseInfos": []]],
            [["glucoseInfos": [["t": 1_699_999_940_000, "v": 0]]]]
        ]
        for devices in cases {
            XCTAssertThrowsError(try parse(devices: devices)) {
                XCTAssertEqual($0 as? SisensingParserError, .noSamples)
            }
        }
    }

    func testAuthenticationFailureRetainsOnlyCode() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "code": "401", "message": "account-specific details", "data": NSNull()
        ])
        XCTAssertThrowsError(try SisensingParser.parse(data, now: now)) {
            XCTAssertEqual($0 as? SisensingParserError, .server(code: 401, message: nil))
        }
    }

    func testInvalidJSONAndInvalidShapeUseDistinctErrors() throws {
        XCTAssertThrowsError(try SisensingParser.parse(Data("not json".utf8), now: now)) {
            XCTAssertEqual($0 as? SisensingParserError, .invalidJSON)
        }
        let responses: [Any] = [[], ["code": 200], ["code": true],
                                ["code": 200, "data": ["glucoseDataList": 1]]]
        for response in responses {
            let data = try JSONSerialization.data(withJSONObject: response)
            XCTAssertThrowsError(try SisensingParser.parse(data, now: now)) {
                XCTAssertEqual($0 as? SisensingParserError, .invalidResponse)
            }
        }
    }

    func testModelsAreCodableAndReadingIdentityDependsOnTime() throws {
        let reading = GlucoseReading(time: now, mmol: 5.8, trend: 1)
        let series = SensorSeries(id: "a", label: "A", isActive: true, readings: [reading])
        let decoded = try JSONDecoder().decode(SensorSeries.self, from: JSONEncoder().encode(series))
        XCTAssertEqual(series, decoded)
        XCTAssertEqual(reading.id, GlucoseReading(time: now, mmol: 6.2).id)
        XCTAssertNotEqual(reading.id, GlucoseReading(time: now.addingTimeInterval(1), mmol: 5.8).id)
    }

    private func parse(devices: Any) throws -> [SensorSeries] {
        let data = try JSONSerialization.data(withJSONObject: [
            "code": 200,
            "data": ["glucoseDataList": devices]
        ])
        return try SisensingParser.parse(data, now: now)
    }
}
#endif
