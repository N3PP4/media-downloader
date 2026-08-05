import Foundation

public enum DownloadKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case video
    case mp3

    public var id: String { rawValue }
}

public enum VideoQuality: String, CaseIterable, Identifiable, Codable, Sendable {
    case best
    case ultraHD2160
    case quadHD1440
    case fullHD1080
    case hd720

    public var id: String { rawValue }

    public static let quickTimeCompatibleCases: [VideoQuality] = [
        .best,
        .fullHD1080,
        .hd720
    ]

    public var maximumHeight: Int? {
        switch self {
        case .best: nil
        case .ultraHD2160: 2160
        case .quadHD1440: 1440
        case .fullHD1080: 1080
        case .hd720: 720
        }
    }
}

public enum MP3Quality: String, CaseIterable, Identifiable, Codable, Sendable {
    case best
    case high
    case standard

    public var id: String { rawValue }

    public var ytDLPValue: String {
        switch self {
        case .best: "0"
        case .high: "2"
        case .standard: "5"
        }
    }
}

public struct DownloadRequest: Equatable, Sendable {
    public var url: URL
    public var destinationDirectory: URL
    public var kind: DownloadKind
    public var videoQuality: VideoQuality
    public var mp3Quality: MP3Quality
    public var allowPlaylist: Bool
    public var convertForQuickTime: Bool

    public init(
        url: URL,
        destinationDirectory: URL,
        kind: DownloadKind,
        videoQuality: VideoQuality = .best,
        mp3Quality: MP3Quality = .best,
        allowPlaylist: Bool = false,
        convertForQuickTime: Bool = false
    ) {
        self.url = url
        self.destinationDirectory = destinationDirectory
        self.kind = kind
        self.videoQuality = videoQuality
        self.mp3Quality = mp3Quality
        self.allowPlaylist = allowPlaylist
        self.convertForQuickTime = convertForQuickTime
    }
}

public enum URLValidationError: Error, Equatable, Sendable {
    case empty
    case unsupportedScheme
    case missingHost
}

public enum URLValidator {
    public static func validate(_ input: String) -> Result<URL, URLValidationError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return .failure(.unsupportedScheme)
        }
        guard let host = components.host, !host.isEmpty,
              let url = components.url else {
            return .failure(.missingHost)
        }
        return .success(url)
    }
}
