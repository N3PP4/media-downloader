import Foundation
import MediaDownloaderCore

struct TestSuite {
    private(set) var checks = 0
    private(set) var failures: [String] = []

    mutating func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        checks += 1
        if !condition() {
            failures.append("\(file):\(line): \(message)")
        }
    }
}

var suite = TestSuite()

do {
    let httpsURL = try URLValidator.validate("https://example.com/video").get()
    let trimmedURL = try URLValidator.validate(" http://example.com/a \n").get()
    suite.expect(
        httpsURL.absoluteString == "https://example.com/video",
        "HTTPS URL should be accepted"
    )
    suite.expect(
        trimmedURL.absoluteString == "http://example.com/a",
        "Whitespace should be trimmed"
    )
} catch {
    suite.expect(false, "Valid URL unexpectedly failed: \(error)")
}
suite.expect(URLValidator.validate("   ") == .failure(.empty), "Empty input should be rejected")
suite.expect(URLValidator.validate("file:///tmp/video") == .failure(.unsupportedScheme), "File URL should be rejected")
suite.expect(URLValidator.validate("javascript:alert(1)") == .failure(.unsupportedScheme), "JavaScript URL should be rejected")
suite.expect(URLValidator.validate("https:///video") == .failure(.missingHost), "Missing host should be rejected")

let destination = URL(fileURLWithPath: "/tmp/Media Downloads", isDirectory: true)
let source = URL(string: "https://example.com/watch?v=abc&list=def")!
let ffmpeg = URL(fileURLWithPath: "/Applications/Media Downloader.app/Contents/Resources/bin/ffmpeg")

let videoRequest = DownloadRequest(url: source, destinationDirectory: destination, kind: .video)
let videoArguments = CommandBuilder.arguments(for: videoRequest, ffmpegURL: ffmpeg)
suite.expect(videoArguments.contains("bv*+ba/b"), "Best video format should match v0.5")
suite.expect(
    videoArguments.contains(where: { $0.hasPrefix("before_dl:__MD_ITEM__") }),
    "Downloads should print per-item playlist metadata"
)
suite.expect(videoArguments.contains("--merge-output-format"), "Video should enable merging")
suite.expect(videoArguments.contains("mp4"), "Video should merge to MP4")
suite.expect(
    videoArguments.contains("%(title)s [%(id)s] [%(resolution)s].%(ext)s"),
    "Video filename should include its resolution so different qualities can coexist"
)
suite.expect(videoArguments.contains("-t"), "Video should use the QuickTime-compatible MP4 preset")
suite.expect(videoArguments.contains("--no-playlist"), "Playlist should be disabled by default")
suite.expect(videoArguments.last == source.absoluteString, "URL should be the final argument")
suite.expect(videoArguments[videoArguments.firstIndex(of: "-P")! + 1] == destination.path, "Destination should be passed intact")
suite.expect(videoArguments[videoArguments.firstIndex(of: "--ffmpeg-location")! + 1] == ffmpeg.path, "FFmpeg path should be explicit")

let automaticMaximumConversionRequest = DownloadRequest(
    url: source,
    destinationDirectory: destination,
    kind: .video,
    videoQuality: .best,
    convertForQuickTime: true
)
let automaticMaximumConversionArguments = CommandBuilder.arguments(
    for: automaticMaximumConversionRequest,
    ffmpegURL: ffmpeg
)
suite.expect(
    automaticMaximumConversionArguments.contains("bv*+ba/b"),
    "Automatic maximum conversion should request the true source maximum"
)
suite.expect(
    !automaticMaximumConversionArguments.contains("-t"),
    "Automatic maximum conversion should not apply the 1080p QuickTime preset"
)

let limitedRequest = DownloadRequest(
    url: source,
    destinationDirectory: destination,
    kind: .video,
    videoQuality: .fullHD1080,
    allowPlaylist: true
)
let limitedArguments = CommandBuilder.arguments(for: limitedRequest, ffmpegURL: nil)
suite.expect(limitedArguments.contains("bv*[format_note^=1080p]+ba/b[format_note^=1080p]/bv*[height<=1080]+ba/b[height<=1080]/b"), "1080p should request the named resolution with a safe fallback")
suite.expect(limitedArguments.contains("--yes-playlist"), "Playlist setting should be honored")
suite.expect(limitedArguments.contains("--ignore-errors"), "Playlist downloads should continue after individual failures")
suite.expect(!limitedArguments.contains("--ffmpeg-location"), "Missing optional FFmpeg path should be omitted")

let conversionRequest = DownloadRequest(
    url: source,
    destinationDirectory: destination,
    kind: .video,
    videoQuality: .ultraHD2160,
    convertForQuickTime: true
)
let conversionArguments = CommandBuilder.arguments(for: conversionRequest, ffmpegURL: ffmpeg)
suite.expect(!conversionArguments.contains("-t"), "4K conversion downloads the original-quality codec before conversion")
suite.expect(conversionArguments.contains("bv*[format_note^=2160p]+ba/b[format_note^=2160p]/bv*[height<=2160]+ba/b[height<=2160]/b"), "4K conversion should request 2160p, including portrait video")

let mp3Request = DownloadRequest(
    url: source,
    destinationDirectory: destination,
    kind: .mp3,
    mp3Quality: .high
)
let mp3Arguments = CommandBuilder.arguments(for: mp3Request, ffmpegURL: ffmpeg)
suite.expect(mp3Arguments.contains("-x"), "MP3 should extract audio")
suite.expect(mp3Arguments[mp3Arguments.firstIndex(of: "--audio-format")! + 1] == "mp3", "MP3 format should be selected")
suite.expect(mp3Arguments[mp3Arguments.firstIndex(of: "--audio-quality")! + 1] == "2", "High MP3 quality should use VBR 2")

suite.expect(
    OutputParser.parse(line: "[download]  42.5% of 10.00MiB at 2.00MiB/s ETA 00:02") == .progress(0.425),
    "Progress should be parsed"
)
suite.expect(OutputParser.parse(line: "[download]  120.0%") == .progress(1), "Progress should be clamped")
suite.expect(OutputParser.parse(line: "__MD_TITLE__Example Video") == .title("Example Video"), "Title marker should be parsed")
suite.expect(
    OutputParser.parse(line: "__MD_ITEM__2\t5\t123.5\tExample Video") == .item(DownloadItemMetadata(
        index: 2,
        total: 5,
        duration: 123.5,
        title: "Example Video"
    )),
    "Playlist item metadata should be parsed"
)
suite.expect(
    OutputParser.parse(line: "__MD_ITEM__NA\tNA\tNA\tSingle Video") == .item(DownloadItemMetadata(
        index: nil,
        total: nil,
        duration: nil,
        title: "Single Video"
    )),
    "Unavailable playlist metadata should use nil values"
)
suite.expect(
    OutputParser.parse(line: "__MD_FILE__/Users/test/Downloads/Example.mp4") == .file(URL(fileURLWithPath: "/Users/test/Downloads/Example.mp4")),
    "File marker should be parsed"
)
suite.expect(
    OutputParser.parse(line: "[ExtractAudio] Destination: Example.mp3") == .status("Converting to MP3…"),
    "MP3 conversion status should be parsed"
)
suite.expect(
    OutputParser.parse(line: "[Merger] Merging formats into Example.mp4") == .status("Merging video and audio…"),
    "Merge status should be parsed"
)
suite.expect(OutputParser.stripANSI("\u{001B}[31mERROR:\u{001B}[0m failed") == "ERROR: failed", "ANSI sequences should be stripped")

let availabilityJSON = """
{
  "duration": 123.5,
  "formats": [
    {"height": 720, "vcodec": "avc1.4d401f", "acodec": "none"},
    {"height": 1080, "vcodec": "avc1.640028", "acodec": "none"},
    {"height": 1440, "vcodec": "av01.0.12M.08", "acodec": "none"},
    {"height": 2160, "vcodec": "av01.0.13M.08", "acodec": "none"},
    {"height": null, "vcodec": "none", "acodec": "mp4a.40.2"}
  ]
}
""".data(using: .utf8)!
do {
    let availability = try FormatAvailabilityParser.parse(availabilityJSON)
    suite.expect(availability.sourceMaximumHeight == 2160, "Source maximum resolution should be detected")
    suite.expect(availability.quickTimeMaximumHeight == 1080, "H.264 maximum resolution should be detected")
    suite.expect(availability.hasAACAudio, "AAC availability should be detected")
    suite.expect(availability.duration == 123.5, "Duration should be detected")
    suite.expect(
        availability.selectableQualities == [.best, .ultraHD2160, .quadHD1440, .fullHD1080, .hd720],
        "A 4K source should expose 4K and lower choices"
    )
    suite.expect(availability.requiresQuickTimeConversion(for: .ultraHD2160), "4K AV1 should require conversion")
    suite.expect(availability.requiresQuickTimeConversion(for: .quadHD1440), "1440p AV1 should require conversion")
    suite.expect(!availability.requiresQuickTimeConversion(for: .fullHD1080), "1080p H.264 should not require conversion")
    suite.expect(availability.requiresQuickTimeConversion(for: .best), "Automatic maximum should convert when source 4K exceeds H.264 1080p")
} catch {
    suite.expect(false, "Format availability parsing failed: \(error)")
}

let playlistJSON = """
{
  "_type": "playlist",
  "title": "Three videos",
  "entries": [{"id": "one"}, {"id": "two"}, {"id": "three"}]
}
""".data(using: .utf8)!
do {
    let playlist = try PlaylistAvailabilityParser.parse(playlistJSON)
    suite.expect(playlist.isPlaylist, "Playlist JSON should be detected")
    suite.expect(playlist.title == "Three videos", "Playlist title should be parsed")
    suite.expect(playlist.itemCount == 3, "Playlist entry count should be parsed")
} catch {
    suite.expect(false, "Playlist availability parsing failed: \(error)")
}

let singleVideoJSON = """
{"_type": "video", "title": "Single video", "id": "one"}
""".data(using: .utf8)!
do {
    let single = try PlaylistAvailabilityParser.parse(singleVideoJSON)
    suite.expect(!single.isPlaylist, "Single video JSON should not be treated as a playlist")
    suite.expect(single.itemCount == 1, "Single video count should be one")
} catch {
    suite.expect(false, "Single video playlist parsing failed: \(error)")
}

let unknownCountPlaylistJSON = """
{"_type": "playlist", "title": "Unknown count"}
""".data(using: .utf8)!
do {
    let playlist = try PlaylistAvailabilityParser.parse(unknownCountPlaylistJSON)
    suite.expect(playlist.isPlaylist, "Unknown-count playlist should still be detected")
    suite.expect(playlist.itemCount == nil, "Unavailable playlist counts should remain unknown")
} catch {
    suite.expect(false, "Unknown-count playlist parsing failed: \(error)")
}

if suite.failures.isEmpty {
    print("PASS: \(suite.checks) checks")
    exit(EXIT_SUCCESS)
}

for failure in suite.failures {
    fputs("FAIL: \(failure)\n", stderr)
}
fputs("\(suite.failures.count) of \(suite.checks) checks failed\n", stderr)
exit(EXIT_FAILURE)
