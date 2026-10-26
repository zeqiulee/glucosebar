import CoreFoundation
import Foundation

public enum SisensingParserError: Error, Sendable, Equatable {
    case invalidJSON
    case invalidResponse
    /// Server messages are deliberately omitted because they may contain account data.
    case server(code: Int, message: String?)
    case noSamples
}

/// Parses the China GS1 devices response without retaining its account metadata.
public enum SisensingParser {
    public static func parse(_ data: Data, now: Date = Date()) throws -> [SensorSeries] {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw SisensingParserError.invalidJSON
        }

        guard let response = json as? [String: Any],
              let code = integer(response["code"]) else {
            throw SisensingParserError.invalidResponse
        }
        guard code == 200 else {
            throw SisensingParserError.server(code: code, message: nil)
        }
        guard let payload = response["data"] as? [String: Any],
              let rawDevices = payload["glucoseDataList"] else {
            throw SisensingParserError.invalidResponse
        }

        let devices: [(key: String?, device: [String: Any])]
        if let list = rawDevices as? [Any] {
            devices = list.compactMap { value in
                guard let device = value as? [String: Any] else { return nil }
                return (nil, device)
            }
        } else if let object = rawDevices as? [String: Any] {
            if object["glucoseInfos"] != nil {
                devices = [(nil, object)]
            } else {
                // Some responses key the list by device identifier.
                devices = object.keys.sorted().compactMap { key in
                    guard let device = object[key] as? [String: Any] else { return nil }
                    return (key, device)
                }
            }
        } else if rawDevices is NSNull {
            devices = []
        } else {
            throw SisensingParserError.invalidResponse
        }

        var usedIDs: Set<String> = []
        var result: [SensorSeries] = []
        for (index, entry) in devices.enumerated() {
            let readings = parseReadings(entry.device["glucoseInfos"], now: now)
            guard !readings.isEmpty else { continue }

            let baseID = firstText(
                in: entry.device,
                keys: ["deviceId", "deviceSn", "deviceSN", "serialNumber", "sn", "id"]
            ) ?? entry.key ?? "device-\(index + 1)"
            var id = baseID
            var suffix = 2
            while usedIDs.contains(id) {
                id = "\(baseID)-\(suffix)"
                suffix += 1
            }
            usedIDs.insert(id)

            let label = firstText(
                in: entry.device,
                keys: ["deviceName", "name", "deviceModel", "model"]
            ) ?? "传感器 \(index + 1)"
            let isActive = integer(entry.device["deviceStatus"]).map { $0 == 1 }
            result.append(SensorSeries(id: id, label: label, isActive: isActive, readings: readings))
        }

        guard !result.isEmpty else { throw SisensingParserError.noSamples }
        return result
    }

    private static func parseReadings(_ raw: Any?, now: Date) -> [GlucoseReading] {
        guard let points = raw as? [Any] else { return [] }
        var byMillisecond: [Int64: GlucoseReading] = [:]
        for point in points {
            guard let point = point as? [String: Any],
                  let timestamp = number(point["t"]), timestamp > 0,
                  let mmol = number(point["v"]), mmol > 0, mmol <= 100 else {
                continue
            }
            let seconds = timestamp > 100_000_000_000 ? timestamp / 1_000 : timestamp
            guard seconds.isFinite, seconds <= now.timeIntervalSince1970 + 120 else { continue }
            let milliseconds = (seconds * 1_000).rounded()
            guard milliseconds.isFinite,
                  milliseconds > Double(Int64.min), milliseconds < Double(Int64.max) else {
                continue
            }
            let time = Date(timeIntervalSince1970: seconds)
            let trend = integer(point["s"]).flatMap { (-2...2).contains($0) ? $0 : nil }
            // Later entries win for the same measurement time.
            byMillisecond[Int64(milliseconds)] = GlucoseReading(time: time, mmol: mmol, trend: trend)
        }
        return byMillisecond.values.sorted { $0.time < $1.time }
    }

    private static func number(_ raw: Any?) -> Double? {
        let value: Double?
        if let raw = raw as? NSNumber {
            guard CFGetTypeID(raw) != CFBooleanGetTypeID() else { return nil }
            value = raw.doubleValue
        } else if let raw = raw as? String {
            value = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            value = nil
        }
        return value.flatMap { $0.isFinite ? $0 : nil }
    }

    private static func integer(_ raw: Any?) -> Int? {
        guard let value = number(raw), value.rounded() == value,
              value > Double(Int.min), value < Double(Int.max) else { return nil }
        return Int(value)
    }

    private static func firstText(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let text = object[key] as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            } else if let value = number(object[key]) {
                return String(value)
            }
        }
        return nil
    }
}
