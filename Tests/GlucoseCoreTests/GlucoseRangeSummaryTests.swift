import Foundation
#if canImport(XCTest) && !GLUCOSE_CORE_STANDALONE_TESTS
import XCTest
#endif
#if canImport(XCTest) || GLUCOSE_CORE_STANDALONE_TESTS
@testable import GlucoseCore

final class GlucoseRangeSummaryTests: XCTestCase {
    private let reference = 3.9...6.9
    private let origin = Date(timeIntervalSince1970: 1_700_000_000)

    func testUsesElapsedTimeInsteadOfSampleCount() throws {
        let result = summary([(0, 5), (60, 5), (540, 5), (600, 10)], end: 600)
        // The last minute leaves the interval after 22.8 seconds; the earlier nine minutes are all in range.
        XCTAssertEqual(result.coveredDuration, 600, accuracy: 0.000001)
        XCTAssertEqual(result.inRangeDuration, 562.8, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(result.percentage), 93.8, accuracy: 0.000001)
    }

    func testFlatInclusiveBoundariesAndOutsideValues() throws {
        for value in [3.9, 6.9] {
            let result = summary([(0, value), (600, value)], end: 600)
            XCTAssertEqual(result.inRangeDuration, 600)
            XCTAssertEqual(try XCTUnwrap(result.percentage), 100)
        }
        for value in [3.899, 6.901] {
            let result = summary([(0, value), (600, value)], end: 600)
            XCTAssertEqual(result.inRangeDuration, 0)
            XCTAssertEqual(try XCTUnwrap(result.percentage), 0)
        }
    }

    func testUpwardAndDownwardCrossingsUseExactFractions() throws {
        for values in [[2.9, 7.9], [7.9, 2.9]] {
            let result = summary([(0, values[0]), (600, values[1])], end: 600)
            XCTAssertEqual(result.inRangeDuration, 360, accuracy: 0.000001)
            XCTAssertEqual(try XCTUnwrap(result.percentage), 60, accuracy: 0.000001)
        }
    }

    func testClipsBothWindowEdgesIncludingCrossingSegments() throws {
        let result = summary([(0, 2.9), (600, 7.9)], start: 200, end: 400)
        XCTAssertEqual(result.duration, 200)
        XCTAssertEqual(result.coveredDuration, 200)
        XCTAssertEqual(result.inRangeDuration, 200, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(result.percentage), 100, accuracy: 0.000001)
        let crossing = summary([(0, 2.9), (600, 7.9)], start: 60, end: 540)
        XCTAssertEqual(crossing.inRangeDuration, 360, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(crossing.percentage), 75, accuracy: 0.000001)
    }

    func testMaximumGapIncludesExactlyTenMinutes() throws {
        let exact = summary([(0, 5), (600, 5)], end: 600)
        XCTAssertEqual(exact.coveredDuration, 600)
        let gap = summary([(0, 5), (601, 5)], end: 601)
        XCTAssertEqual(gap.coveredDuration, 0)
        XCTAssertEqual(gap.inRangeDuration, 0)
        XCTAssertEqual(gap.percentage, nil)
    }

    func testPartialCoverageUsesFullTwentyFourHourDenominator() throws {
        let result = summary(stride(from: 0, through: 3600, by: 300).map { (Double($0), 5.0) }, end: 86400)
        XCTAssertEqual(result.duration, 86400)
        XCTAssertEqual(result.coveredDuration, 3600)
        XCTAssertEqual(result.inRangeDuration, 3600)
        XCTAssertEqual(try XCTUnwrap(result.percentage), 100.0 / 24, accuracy: 0.000001)
        XCTAssertEqual(result.coveragePercentage, 100.0 / 24, accuracy: 0.000001)
    }

    func testAllSupportedWindowsKeepFullDenominator() throws {
        for hours in [3, 6, 12, 24] {
            let end = Double(hours * 3600)
            let result = summary([(end - 600, 5), (end, 5)], end: end)
            XCTAssertEqual(result.duration, end)
            XCTAssertEqual(result.inRangeDuration, 600)
            XCTAssertEqual(try XCTUnwrap(result.percentage), 600 / end * 100, accuracy: 0.000001)
        }
    }

    func testDoesNotExtrapolateOrCountSamplesOutsideWindow() throws {
        let result = summary([(-600, 5), (-300, 5), (60, 5), (300, 5), (900, 5), (1200, 5)], end: 600)
        // Window-edge interpolation is allowed only where a recorded pair supports it.
        XCTAssertEqual(result.coveredDuration, 600)
        XCTAssertEqual(result.inRangeDuration, 600)
        let partial = summary([(60, 5), (300, 5)], end: 600)
        XCTAssertEqual(partial.coveredDuration, 240)
        XCTAssertEqual(try XCTUnwrap(partial.percentage), 40)
        let outside = summary([(-600, 5), (-300, 5), (900, 5), (1200, 5)], end: 600)
        XCTAssertEqual(outside.percentage, nil)
    }

    func testEmptySingletonAndZeroDurationHaveNoPercentage() {
        for samples: [(Double, Double)] in [[], [(0, 5)]] {
            let result = summary(samples, end: 600)
            XCTAssertEqual(result.percentage, nil)
            XCTAssertEqual(result.coveragePercentage, 0)
        }
        let zero = summary([(0, 5), (600, 5)], end: 0)
        XCTAssertEqual(zero.duration, 0)
        XCTAssertEqual(zero.percentage, nil)
        XCTAssertEqual(zero.coveragePercentage, 0)
    }

    func testSortsDeduplicatesAndSkipsInvalidReadings() throws {
        let readings = [reading(600, 5), reading(0, 9), reading(0, 5), reading(150, .nan),
                        reading(200, .infinity), reading(250, 0), reading(300, -1),
                        GlucoseReading(time: Date(timeIntervalSince1970: .nan), mmol: 5)]
        let result = GlucoseRangeSummary.calculate(readings: readings, window: window(0, 600), range: reference)
        XCTAssertEqual(result.coveredDuration, 600)
        XCTAssertEqual(try XCTUnwrap(result.percentage), 100)
    }

    func testInvalidGapOrRangeProducesNoCoverage() {
        for gap in [0, -1, Double.nan, Double.infinity] {
            let result = GlucoseRangeSummary.calculate(readings: [reading(0, 5), reading(600, 5)],
                                                       window: window(0, 600), range: reference, maximumGap: gap)
            XCTAssertEqual(result.duration, 600)
            XCTAssertEqual(result.percentage, nil)
        }
        let result = GlucoseRangeSummary.calculate(readings: [reading(0, 5), reading(600, 5)],
                                                   window: window(0, 600), range: 3.9...Double.infinity)
        XCTAssertEqual(result.percentage, nil)
    }

    private func summary(_ values: [(Double, Double)], start: Double = 0, end: Double) -> GlucoseRangeSummary {
        GlucoseRangeSummary.calculate(readings: values.map { reading($0.0, $0.1) },
                                      window: window(start, end), range: reference)
    }

    private func reading(_ seconds: Double, _ value: Double) -> GlucoseReading {
        GlucoseReading(time: origin.addingTimeInterval(seconds), mmol: value)
    }

    private func window(_ start: Double, _ end: Double) -> DateInterval {
        DateInterval(start: origin.addingTimeInterval(start), end: origin.addingTimeInterval(end))
    }
}
#endif
