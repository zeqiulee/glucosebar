import Foundation
import GlucoseCore

/// Selects a recorded measurement without interpolating across a sensor outage.
enum GlucoseChartSelection {
    static func nearest(to time: Date, in readings: [GlucoseReading]) -> GlucoseReading? {
        guard let first = readings.first, let last = readings.last,
              time >= first.time, time <= last.time else { return nil }

        // Lower bound: the first reading at or after the pointer's time.
        var lower = 0
        var upper = readings.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if readings[middle].time < time {
                lower = middle + 1
            } else {
                upper = middle
            }
        }

        let next = readings[lower]
        if next.time == time { return next }
        guard lower > 0 else { return nil }
        let previous = readings[lower - 1]
        guard next.time.timeIntervalSince(previous.time) <= 10 * 60 else { return nil }

        return time.timeIntervalSince(previous.time) <= next.time.timeIntervalSince(time)
            ? previous : next
    }
}
