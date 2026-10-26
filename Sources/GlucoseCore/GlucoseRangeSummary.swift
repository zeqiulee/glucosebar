import Foundation

/// Time within a reference interval, measured against the entire selected window.
public struct GlucoseRangeSummary: Sendable, Equatable {
    public let duration: TimeInterval
    public let coveredDuration: TimeInterval
    public let inRangeDuration: TimeInterval

    /// Missing coverage remains in the denominator; no observed interval has no percentage.
    public var percentage: Double? {
        guard duration > 0, coveredDuration > 0 else { return nil }
        return min(100, max(0, inRangeDuration / duration * 100))
    }

    public var coveragePercentage: Double {
        guard duration > 0 else { return 0 }
        return min(100, max(0, coveredDuration / duration * 100))
    }

    public static func calculate(
        readings: [GlucoseReading],
        window: DateInterval,
        range: ClosedRange<Double>,
        maximumGap: TimeInterval = 600
    ) -> Self {
        let duration = window.duration
        guard duration.isFinite, duration > 0,
              window.start.timeIntervalSince1970.isFinite,
              window.end.timeIntervalSince1970.isFinite else {
            return Self(duration: 0, coveredDuration: 0, inRangeDuration: 0)
        }
        guard range.lowerBound.isFinite, range.upperBound.isFinite,
              maximumGap.isFinite, maximumGap > 0 else {
            return Self(duration: duration, coveredDuration: 0, inRangeDuration: 0)
        }

        // The parser already sorts and deduplicates. Keep this API deterministic for other callers too.
        let ordered = readings.enumerated().filter {
            $0.element.time.timeIntervalSince1970.isFinite && $0.element.mmol.isFinite && $0.element.mmol > 0
        }.sorted {
            if $0.element.time == $1.element.time { return $0.offset < $1.offset }
            return $0.element.time < $1.element.time
        }
        var samples: [GlucoseReading] = []
        for observation in ordered {
            if samples.last?.time == observation.element.time {
                samples[samples.count - 1] = observation.element
            } else {
                samples.append(observation.element)
            }
        }

        var covered: TimeInterval = 0
        var inRange: TimeInterval = 0
        for (start, end) in zip(samples, samples.dropFirst()) {
            let interval = end.time.timeIntervalSince(start.time)
            guard interval > 0, interval <= maximumGap else { continue }
            let clippedStart = max(window.start, start.time)
            let clippedEnd = min(window.end, end.time)
            let clippedDuration = clippedEnd.timeIntervalSince(clippedStart)
            guard clippedDuration > 0 else { continue }
            covered += clippedDuration

            // Estimate threshold crossing times from raw readings. Visual curve smoothing does not alter this statistic.
            let difference = end.mmol - start.mmol
            let startValue = start.mmol + difference * (clippedStart.timeIntervalSince(start.time) / interval)
            let endValue = start.mmol + difference * (clippedEnd.timeIntervalSince(start.time) / interval)
            let clippedDifference = endValue - startValue
            if clippedDifference == 0 {
                if range.contains(startValue) { inRange += clippedDuration }
                continue
            }
            let firstCrossing = (range.lowerBound - startValue) / clippedDifference
            let secondCrossing = (range.upperBound - startValue) / clippedDifference
            let entry = max(0, min(firstCrossing, secondCrossing))
            let exit = min(1, max(firstCrossing, secondCrossing))
            inRange += clippedDuration * max(0, exit - entry)
        }

        let boundedCoverage = min(duration, max(0, covered))
        return Self(duration: duration, coveredDuration: boundedCoverage,
                    inRangeDuration: min(boundedCoverage, max(0, inRange)))
    }
}
