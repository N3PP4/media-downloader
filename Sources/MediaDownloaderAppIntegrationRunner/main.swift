import Foundation
import MediaDownloaderCore
import MediaDownloaderUI

@main
struct MediaDownloaderAppIntegrationRunner {
    @MainActor
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--check-quality-labels"] {
            let checks = [
                AppIntegrationHarness.bestQualityLabel(maximumHeight: 2160, japanese: true) == "最高画質（4K）",
                AppIntegrationHarness.bestQualityLabel(maximumHeight: 1440, japanese: true) == "最高画質（1440p）",
                AppIntegrationHarness.bestQualityLabel(maximumHeight: 1080, japanese: true) == "最高画質（1080p）",
                AppIntegrationHarness.bestQualityLabel(maximumHeight: 2160, japanese: false) == "Best quality (4K)",
                AppIntegrationHarness.bestQualityLabel(maximumHeight: nil, japanese: false) == "Best quality (Auto)",
                AppIntegrationHarness.qualitiesAfterInspectionFailure() == VideoQuality.allCases
            ]
            guard checks.allSatisfy({ $0 }) else {
                fputs("quality label check failed\n", stderr)
                exit(1)
            }
            print("PASS: dynamic best-quality labels")
            return
        }
        if arguments == ["--check-conversion-arguments"] {
            guard AppIntegrationHarness.conversionArgumentsAreValid() else {
                fputs("conversion argument check failed\n", stderr)
                exit(1)
            }
            print("PASS: VideoToolbox and libx265 conversion arguments")
            return
        }
        if arguments == ["--check-confirmations"] {
            let enabled = AppIntegrationHarness.shouldConfirmPlaylist(
                allowPlaylist: true,
                confirmationEnabled: true
            )
            let hidden = AppIntegrationHarness.shouldConfirmPlaylist(
                allowPlaylist: true,
                confirmationEnabled: false
            )
            let singleOnly = AppIntegrationHarness.shouldConfirmPlaylist(
                allowPlaylist: false,
                confirmationEnabled: true
            )
            guard enabled, !hidden, !singleOnly else {
                fputs("playlist confirmation state check failed\n", stderr)
                exit(1)
            }
            print("PASS: playlist confirmation enabled, hidden, and single-item states")
            return
        }
        if arguments.count == 2, arguments[0] == "--inspect" {
            guard let availability = await AppIntegrationHarness.inspect(url: arguments[1]) else {
                fputs("format inspection failed\n", stderr)
                exit(1)
            }
            print(
                "PASS: max=\(availability.sourceMaximumHeight) "
                    + "quickTimeMax=\(availability.quickTimeMaximumHeight ?? 0) "
                    + "aac=\(availability.hasAACAudio) "
                    + "choices=\(availability.selectableQualities.map(\.rawValue).joined(separator: ","))"
            )
            return
        }
        if arguments.count == 2, arguments[0] == "--inspect-playlist" {
            guard let availability = await AppIntegrationHarness.inspectPlaylist(url: arguments[1]) else {
                fputs("playlist inspection failed\n", stderr)
                exit(1)
            }
            let itemCount = availability.itemCount.map(String.init) ?? "unknown"
            let title = availability.title ?? "unknown"
            print(
                "PASS: playlist=\(availability.isPlaylist) "
                    + "count=\(itemCount) "
                    + "title=\(title)"
            )
            return
        }

        guard (3...6).contains(arguments.count),
              let kind = DownloadKind(rawValue: arguments[2]) else {
            fputs("usage: MediaDownloaderAppIntegrationRunner URL DESTINATION video|mp3 [video-quality] [timeout-seconds] [allow-playlist]\n", stderr)
            exit(2)
        }
        let videoQuality = arguments.count >= 4
            ? VideoQuality(rawValue: arguments[3]) ?? .best
            : .best
        let timeout = arguments.count >= 5 ? Double(arguments[4]) ?? 30 : 30
        let allowPlaylist = arguments.count == 6
            ? ["1", "true", "yes"].contains(arguments[5].lowercased())
            : false

        let result = await AppIntegrationHarness.run(
            url: arguments[0],
            destination: URL(fileURLWithPath: arguments[1], isDirectory: true),
            kind: kind,
            videoQuality: videoQuality,
            allowPlaylist: allowPlaylist,
            timeout: timeout
        )

        guard result.succeeded,
              let outputURL = result.outputURL,
              FileManager.default.fileExists(atPath: outputURL.path) else {
            fputs(
                "integration failed: \(result.errorMessage) progress=\(result.progress) logs=\(result.logLineCount)\n",
                stderr
            )
            exit(1)
        }

        print(
            "PASS: \(kind.rawValue) output=\(outputURL.path) outputs=\(result.outputURLs.count) "
                + "succeeded=\(result.successfulItemCount) failed=\(result.failedItemCount) "
                + "progress=\(result.progress) logs=\(result.logLineCount)"
        )
    }
}
