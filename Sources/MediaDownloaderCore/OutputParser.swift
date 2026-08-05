import Foundation

public enum DownloadOutputEvent: Equatable, Sendable {
    case progress(Double)
    case title(String)
    case item(DownloadItemMetadata)
    case file(URL)
    case status(String)
}

public struct DownloadItemMetadata: Equatable, Sendable {
    public let index: Int?
    public let total: Int?
    public let duration: TimeInterval?
    public let title: String

    public init(index: Int?, total: Int?, duration: TimeInterval?, title: String) {
        self.index = index
        self.total = total
        self.duration = duration
        self.title = title
    }
}

public enum OutputParser {
    private static let progressExpression = try! NSRegularExpression(
        pattern: #"\[download\]\s+([0-9]+(?:\.[0-9]+)?)%"#
    )
    private static let ansiExpression = try! NSRegularExpression(
        pattern: #"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])"#
    )

    public static func parse(line rawLine: String) -> DownloadOutputEvent? {
        let line = stripANSI(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }

        if line.hasPrefix("__MD_TITLE__") {
            return .title(String(line.dropFirst("__MD_TITLE__".count)))
        }

        if line.hasPrefix("__MD_ITEM__") {
            let payload = String(line.dropFirst("__MD_ITEM__".count))
            let fields = payload.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
            guard fields.count == 4 else { return nil }
            return .item(DownloadItemMetadata(
                index: positiveInteger(fields[0]),
                total: positiveInteger(fields[1]),
                duration: positiveDouble(fields[2]),
                title: String(fields[3])
            ))
        }

        if line.hasPrefix("__MD_FILE__") {
            let path = String(line.dropFirst("__MD_FILE__".count))
            return .file(URL(fileURLWithPath: path))
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        if let match = progressExpression.firstMatch(in: line, range: range),
           let percentRange = Range(match.range(at: 1), in: line),
           let percent = Double(line[percentRange]) {
            return .progress(min(max(percent / 100, 0), 1))
        }

        if line.hasPrefix("[download]") {
            return .status(line.replacingOccurrences(of: "[download]", with: "")
                .trimmingCharacters(in: .whitespaces))
        }
        if line.hasPrefix("[ExtractAudio]") {
            return .status("Converting to MP3…")
        }
        if line.hasPrefix("[Merger]") {
            return .status("Merging video and audio…")
        }
        if line.hasPrefix("ERROR:") || line.hasPrefix("WARNING:") {
            return .status(line)
        }

        return nil
    }

    public static func stripANSI(_ input: String) -> String {
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return ansiExpression.stringByReplacingMatches(in: input, range: range, withTemplate: "")
    }

    private static func positiveInteger(_ value: Substring) -> Int? {
        guard let integer = Int(value), integer > 0 else { return nil }
        return integer
    }

    private static func positiveDouble(_ value: Substring) -> Double? {
        guard let double = Double(value), double > 0 else { return nil }
        return double
    }
}
