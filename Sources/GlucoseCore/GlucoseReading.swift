import Foundation

/// One glucose observation, in mmol/L.
public struct GlucoseReading: Sendable, Codable, Equatable, Identifiable {
    public let time: Date
    public let mmol: Double
    public let trend: Int?

    public var id: String { String(time.timeIntervalSince1970) }

    public var trendSymbol: String? {
        switch trend {
        case -2: "↓"
        case -1: "↘"
        case 0: "→"
        case 1: "↗"
        case 2: "↑"
        default: nil
        }
    }

    public init(time: Date, mmol: Double, trend: Int? = nil) {
        self.time = time
        self.mmol = mmol
        self.trend = trend.flatMap { (-2...2).contains($0) ? $0 : nil }
    }
}

/// Observations remain grouped by sensor so charts never bridge two devices.
public struct SensorSeries: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let isActive: Bool?
    public let readings: [GlucoseReading]

    public init(
        id: String,
        label: String,
        isActive: Bool? = nil,
        readings: [GlucoseReading]
    ) {
        self.id = id
        self.label = label
        self.isActive = isActive
        self.readings = readings
    }
}
