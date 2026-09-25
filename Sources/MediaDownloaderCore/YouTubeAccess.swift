import Foundation

public enum BrowserCookieSource: String, CaseIterable, Identifiable, Sendable {
    case chrome
    case safari
    case firefox

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .chrome: "Chrome"
        case .safari: "Safari"
        case .firefox: "Firefox"
        }
    }
}

public enum YouTubeAccess {
    public static func isYouTubeURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com")
    }

    public static func needsBrowserVerification(_ message: String) -> Bool {
        let normalized = message.lowercased().replacingOccurrences(of: "’", with: "'")
        return normalized.contains("sign in to confirm you're not a bot")
            || normalized.contains("sign in to confirm you are not a bot")
    }

    public static func browserCookieArguments(
        for url: URL,
        browser: BrowserCookieSource?
    ) -> [String] {
        guard isYouTubeURL(url), let browser else { return [] }
        return ["--cookies-from-browser", browser.rawValue]
    }
}
