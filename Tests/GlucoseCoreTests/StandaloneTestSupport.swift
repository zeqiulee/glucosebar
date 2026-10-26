// The explicit standalone flag takes precedence, even when the SDK includes XCTest.
// A normal Xcode / SwiftPM test build does not define this flag and uses XCTest.
#if GLUCOSE_CORE_STANDALONE_TESTS
import Foundation

class XCTestCase {}

private enum StandaloneTestFailure: Error { case missingValue }

func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    guard actual == expected else { fatalError("Equality assertion failed at \(file):\(line)") }
}

func XCTAssertEqual(_ actual: Double, _ expected: Double, accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
    guard abs(actual - expected) <= accuracy else { fatalError("Accuracy assertion failed at \(file):\(line)") }
}

func XCTAssertNotEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    guard actual != expected else { fatalError("Inequality assertion failed at \(file):\(line)") }
}

func XCTAssertTrue(_ condition: Bool, file: StaticString = #filePath, line: UInt = #line) {
    guard condition else { fatalError("Boolean assertion failed at \(file):\(line)") }
}

func XCTUnwrap<T>(_ value: T?) throws -> T {
    guard let value else { throw StandaloneTestFailure.missingValue }
    return value
}

func XCTAssertThrowsError<T>(
    _ expression: @autoclosure () throws -> T,
    _ handler: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        _ = try expression()
        fatalError("Expected an error at \(file):\(line)")
    } catch {
        handler(error)
    }
}

@main
enum StandaloneCoreTests {
    static func main() throws {
        let tests = SisensingParserTests()
        let ranges = GlucoseRangeSummaryTests()
        let cache = GlucoseCacheTests()
        let cases: [(String, () throws -> Void)] = [
            ("mmol units", tests.testParsesMmolWithoutConvertingUnits),
            ("single object and numeric strings", tests.testAcceptsSingleDeviceObjectAndNumericStrings),
            ("seconds, milliseconds and ordering", tests.testAcceptsSecondsAndMillisecondsAndSortsByMeasurementTime),
            ("duplicate observations", tests.testDuplicateMeasurementTimesUseLastObservation),
            ("invalid values and future timestamps", tests.testSkipsInvalidValuesAndFutureDatesWithoutDroppingValidPoints),
            ("malformed observations", tests.testMalformedPointsAreSkipped),
            ("unknown trend", tests.testUnknownOrMissingTrendNeverShowsFlatArrow),
            ("known trends", tests.testKnownTrendSymbols),
            ("device isolation", tests.testDevicesRemainSeparateEvenWithMatchingTimestampOrIdentifier),
            ("object map", tests.testDeviceObjectMapUsesKeysAsSeparateIdentifiers),
            ("no samples", tests.testNoSamplesThrowsForEmptyOrEntirelyInvalidDeviceData),
            ("authentication errors", tests.testAuthenticationFailureRetainsOnlyCode),
            ("invalid JSON and shape", tests.testInvalidJSONAndInvalidShapeUseDistinctErrors),
            ("Codable models", tests.testModelsAreCodableAndReadingIdentityDependsOnTime),
            ("time weighting", ranges.testUsesElapsedTimeInsteadOfSampleCount),
            ("inclusive reference boundaries", ranges.testFlatInclusiveBoundariesAndOutsideValues),
            ("threshold crossing time", ranges.testUpwardAndDownwardCrossingsUseExactFractions),
            ("window boundary clipping", ranges.testClipsBothWindowEdgesIncludingCrossingSegments),
            ("ten-minute data gap", ranges.testMaximumGapIncludesExactlyTenMinutes),
            ("partial-day denominator", ranges.testPartialCoverageUsesFullTwentyFourHourDenominator),
            ("supported window denominators", ranges.testAllSupportedWindowsKeepFullDenominator),
            ("no extrapolation", ranges.testDoesNotExtrapolateOrCountSamplesOutsideWindow),
            ("missing duration", ranges.testEmptySingletonAndZeroDurationHaveNoPercentage),
            ("range input normalization", ranges.testSortsDeduplicatesAndSkipsInvalidReadings),
            ("invalid range configuration", ranges.testInvalidGapOrRangeProducesNoCoverage),
            ("credential-bound cache round trip", cache.testRoundTripBindsHistoryWithoutEncodingCredential),
            ("cache credential isolation", cache.testDifferentCredentialCannotLoadExistingHistory),
            ("cache schema isolation", cache.testLegacyAndUnknownSchemasAreIgnored),
            ("corrupt cache", cache.testCorruptCacheIsIgnored),
            ("cache file permissions", cache.testSaveCreatesAndRestoresPrivatePermissions),
            ("cache clear and idempotence", cache.testRemovalIsIdempotentAndClearsHistory),
            ("cache deletion failure", cache.testRemovalFailureIsReportedWithoutDeletingUnexpectedDirectory),
            ("cache write failure", cache.testWriteFailureAndEmptyCredentialUseStaticErrors),
            ("cache retention", cache.testLoadLimitsHistoryToRecentPastValidReadings)
        ]
        for (name, test) in cases {
            try test()
            print("PASS: \(name)")
        }
        print("\(cases.count) core tests passed.")
    }
}
#endif
