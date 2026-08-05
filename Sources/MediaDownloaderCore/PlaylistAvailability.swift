import Foundation

public struct PlaylistAvailability: Equatable, Sendable {
    public let isPlaylist: Bool
    public let title: String?
    public let itemCount: Int?

    public init(isPlaylist: Bool, title: String?, itemCount: Int?) {
        self.isPlaylist = isPlaylist
        self.title = title
        self.itemCount = itemCount
    }
}

public enum PlaylistAvailabilityError: Error, Equatable, Sendable {
    case invalidJSON
}

public enum PlaylistAvailabilityParser {
    public static func parse(_ data: Data) throws -> PlaylistAvailability {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlaylistAvailabilityError.invalidJSON
        }

        let type = (root["_type"] as? String)?.lowercased()
        let entries = root["entries"] as? [Any]
        let isPlaylist = type == "playlist" || entries != nil
        let explicitCount = integerValue(root["playlist_count"])
            ?? integerValue(root["n_entries"])
        let itemCount = isPlaylist ? (explicitCount ?? entries?.count) : 1

        return PlaylistAvailability(
            isPlaylist: isPlaylist,
            title: nonEmptyString(root["title"]),
            itemCount: itemCount
        )
    }

    private static func integerValue(_ value: Any?) -> Int? {
        if let integer = value as? Int { return integer }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String,
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return string
    }
}
