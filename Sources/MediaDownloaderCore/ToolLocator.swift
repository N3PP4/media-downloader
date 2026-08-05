import Foundation

public struct ToolLocations: Equatable, Sendable {
    public var ytDLP: URL?
    public var ffmpeg: URL?

    public init(ytDLP: URL?, ffmpeg: URL?) {
        self.ytDLP = ytDLP
        self.ffmpeg = ffmpeg
    }

    public var isReady: Bool { ytDLP != nil && ffmpeg != nil }
}

public enum ToolLocator {
    public static func locate(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> ToolLocations {
        ToolLocations(
            ytDLP: locateExecutable(named: "yt-dlp", bundle: bundle, environment: environment, fileManager: fileManager),
            ffmpeg: locateExecutable(named: "ffmpeg", bundle: bundle, environment: environment, fileManager: fileManager)
        )
    }

    public static func locateExecutable(
        named name: String,
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL? {
        var candidates: [URL] = []

        if let resourceURL = bundle.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("bin/\(name)"))
            candidates.append(resourceURL.appendingPathComponent(name))
        }

        let pathDirectories = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        candidates.append(contentsOf: pathDirectories.map {
            URL(fileURLWithPath: $0).appendingPathComponent(name)
        })

        candidates.append(contentsOf: [
            URL(fileURLWithPath: "/opt/homebrew/bin/\(name)"),
            URL(fileURLWithPath: "/usr/local/bin/\(name)")
        ])

        var seen = Set<String>()
        return candidates.first { candidate in
            let path = candidate.standardizedFileURL.path
            guard seen.insert(path).inserted else { return false }
            return fileManager.isExecutableFile(atPath: path)
        }
    }
}
