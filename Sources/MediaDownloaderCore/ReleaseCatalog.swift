import Foundation

public struct AppRelease: Equatable, Sendable {
    public let version: String
    public let url: URL

    public init(version: String, url: URL) {
        self.version = version
        self.url = url
    }
}

public enum ReleaseCatalog {
    private struct GitHubRelease: Decodable {
        let tagName: String
        let draft: Bool

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case draft
        }
    }

    private struct Version: Comparable {
        let major: Int
        let minor: Int
        let patch: Int

        init?(_ value: String) {
            let normalized = value.hasPrefix("v") ? String(value.dropFirst()) : value
            let parts = normalized
                .split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 3,
                  let major = Int(parts[0]),
                  let minor = Int(parts[1]),
                  let patch = Int(parts[2]),
                  major >= 0, minor >= 0, patch >= 0 else { return nil }
            self.major = major
            self.minor = minor
            self.patch = patch
        }

        static func < (lhs: Version, rhs: Version) -> Bool {
            (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
        }
    }

    public static func newestRelease(in data: Data) throws -> AppRelease? {
        let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
        guard let newest = releases
            .filter({ !$0.draft && Version($0.tagName) != nil })
            .max(by: { Version($0.tagName)! < Version($1.tagName)! }),
              let version = Version(newest.tagName) else { return nil }

        let number = "\(version.major).\(version.minor).\(version.patch)"
        let url = URL(string: "https://github.com/N3PP4/media-downloader/releases/tag/v\(number)")!
        return AppRelease(version: number, url: url)
    }

    public static func isNewer(_ release: AppRelease, than installedVersion: String) -> Bool {
        guard let available = Version(release.version),
              let installed = Version(installedVersion) else { return false }
        return available > installed
    }
}
