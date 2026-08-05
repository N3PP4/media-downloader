import Foundation

public struct FormatAvailability: Equatable, Sendable {
    public let sourceMaximumHeight: Int
    public let quickTimeMaximumHeight: Int?
    public let hasAACAudio: Bool
    public let duration: TimeInterval?

    public init(
        sourceMaximumHeight: Int,
        quickTimeMaximumHeight: Int?,
        hasAACAudio: Bool,
        duration: TimeInterval?
    ) {
        self.sourceMaximumHeight = sourceMaximumHeight
        self.quickTimeMaximumHeight = quickTimeMaximumHeight
        self.hasAACAudio = hasAACAudio
        self.duration = duration
    }

    public var selectableQualities: [VideoQuality] {
        var qualities: [VideoQuality] = [.best]
        if sourceMaximumHeight >= 2160 { qualities.append(.ultraHD2160) }
        if sourceMaximumHeight >= 1440 { qualities.append(.quadHD1440) }
        if sourceMaximumHeight >= 1080 { qualities.append(.fullHD1080) }
        if sourceMaximumHeight >= 720 { qualities.append(.hd720) }
        return qualities
    }

    public func requiresQuickTimeConversion(for quality: VideoQuality) -> Bool {
        let requestedHeight = quality.maximumHeight ?? sourceMaximumHeight
        return (quickTimeMaximumHeight ?? 0) < requestedHeight || !hasAACAudio
    }
}

public enum FormatAvailabilityError: Error, Equatable, Sendable {
    case invalidJSON
    case noVideoFormats
}

public enum FormatAvailabilityParser {
    public static func parse(_ data: Data) throws -> FormatAvailability {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let formats = root["formats"] as? [[String: Any]] else {
            throw FormatAvailabilityError.invalidJSON
        }

        var sourceHeights: [Int] = []
        var quickTimeHeights: [Int] = []
        var hasAACAudio = false

        for format in formats {
            let videoCodec = (format["vcodec"] as? String)?.lowercased() ?? "none"
            let audioCodec = (format["acodec"] as? String)?.lowercased() ?? "none"
            let height = effectiveResolution(format)

            if videoCodec != "none", let height, height > 0 {
                sourceHeights.append(height)
                if videoCodec.hasPrefix("avc1") || videoCodec.hasPrefix("h264") {
                    quickTimeHeights.append(height)
                }
            }

            if audioCodec.hasPrefix("mp4a") || audioCodec.hasPrefix("aac") {
                hasAACAudio = true
            }
        }

        guard let maximumHeight = sourceHeights.max() else {
            throw FormatAvailabilityError.noVideoFormats
        }

        return FormatAvailability(
            sourceMaximumHeight: maximumHeight,
            quickTimeMaximumHeight: quickTimeHeights.max(),
            hasAACAudio: hasAACAudio,
            duration: doubleValue(root["duration"])
        )
    }

    private static func integerValue(_ value: Any?) -> Int? {
        if let integer = value as? Int { return integer }
        if let number = value as? NSNumber { return number.intValue }
        if let double = value as? Double { return Int(double.rounded()) }
        return nil
    }

    private static func effectiveResolution(_ format: [String: Any]) -> Int? {
        if let note = format["format_note"] as? String,
           let match = note.range(of: #"^[0-9]+(?=p)"#, options: .regularExpression),
           let value = Int(note[match]) {
            return value
        }

        let width = integerValue(format["width"])
        let height = integerValue(format["height"])
        if let width, let height, width > 0, height > 0 {
            return min(width, height)
        }
        return height ?? width
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let integer = value as? Int { return Double(integer) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }
}
