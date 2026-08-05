import Foundation
import MediaDownloaderCore

public struct AppIntegrationResult: Sendable {
    public let succeeded: Bool
    public let outputURL: URL?
    public let outputURLs: [URL]
    public let successfulItemCount: Int
    public let failedItemCount: Int
    public let errorMessage: String
    public let progress: Double
    public let logLineCount: Int
}

public enum AppIntegrationHarness {
    public static func bestQualityLabel(maximumHeight: Int?, japanese: Bool) -> String {
        (japanese ? AppLanguage.japanese : AppLanguage.english)
            .bestVideoQualityName(maximumHeight: maximumHeight)
    }

    @MainActor
    public static func qualitiesAfterInspectionFailure() -> [VideoQuality] {
        let suiteName = "MediaDownloaderQualityFallback-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)
        let model = AppModel(settings: settings)
        model.urlText = "https://example.com/video"
        model.configurePreview(formatAvailability: nil, inspectionFailed: true)
        return model.selectableVideoQualities
    }

    public static func conversionArgumentsAreValid() -> Bool {
        let input = URL(fileURLWithPath: "/tmp/input.mp4")
        let output = URL(fileURLWithPath: "/tmp/output.mp4")
        let hardware = ConversionRunner.arguments(
            inputURL: input,
            outputURL: output,
            encoder: .videoToolbox
        )
        let software = ConversionRunner.arguments(
            inputURL: input,
            outputURL: output,
            encoder: .software
        )
        return hardware.contains("hevc_videotoolbox")
            && hardware.contains("-allow_sw")
            && software.contains("libx265")
            && software.contains("-crf")
            && software.contains("yuv420p")
            && hardware.contains("hvc1")
            && software.contains("hvc1")
    }

    @MainActor
    public static func shouldConfirmPlaylist(
        allowPlaylist: Bool,
        confirmationEnabled: Bool
    ) -> Bool {
        let suiteName = "MediaDownloaderConfirmation-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.allowPlaylist = allowPlaylist
        settings.confirmPlaylistBeforeDownload = confirmationEnabled
        let model = AppModel(settings: settings)
        model.urlText = "https://example.com/playlist"
        return model.shouldConfirmPlaylist
    }

    @MainActor
    public static func run(
        url: String,
        destination: URL,
        kind: DownloadKind,
        videoQuality: VideoQuality = .best,
        allowPlaylist: Bool = false,
        timeout: TimeInterval = 30
    ) async -> AppIntegrationResult {
        let suiteName = "MediaDownloaderIntegration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.destinationURL = destination
        settings.revealOnCompletion = false
        settings.allowPlaylist = allowPlaylist
        settings.videoQuality = videoQuality

        let model = AppModel(settings: settings)
        model.urlText = url
        model.kind = kind

        if kind == .video, videoQuality == .best {
            model.scheduleFormatInspection()
            let inspectionDeadline = Date(timeIntervalSinceNow: 30)
            while model.isInspectingFormats && Date() < inspectionDeadline {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }

        model.startDownload()

        let deadline = Date(timeIntervalSinceNow: timeout)
        while model.isRunning && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        if model.isRunning {
            model.cancelDownload()
            let cancellationDeadline = Date(timeIntervalSinceNow: 5)
            while model.isRunning && Date() < cancellationDeadline {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            return AppIntegrationResult(
                succeeded: false,
                outputURL: nil,
                outputURLs: model.outputURLs,
                successfulItemCount: model.successfulItemCount,
                failedItemCount: model.failedItemCount,
                errorMessage: "Integration test timed out",
                progress: model.progress,
                logLineCount: model.logLines.count
            )
        }

        return AppIntegrationResult(
            succeeded: model.phase == .completed || model.phase == .completedWithWarnings,
            outputURL: model.outputURL,
            outputURLs: model.outputURLs,
            successfulItemCount: model.successfulItemCount,
            failedItemCount: model.failedItemCount,
            errorMessage: model.errorMessage,
            progress: model.progress,
            logLineCount: model.logLines.count
        )
    }

    @MainActor
    public static func inspect(
        url: String,
        timeout: TimeInterval = 30
    ) async -> FormatAvailability? {
        let suiteName = "MediaDownloaderInspection-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        let model = AppModel(settings: settings)
        model.urlText = url
        model.scheduleFormatInspection()

        let deadline = Date(timeIntervalSinceNow: timeout)
        while model.isInspectingFormats && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return model.formatAvailability
    }

    @MainActor
    public static func inspectPlaylist(
        url: String,
        timeout: TimeInterval = 30
    ) async -> PlaylistAvailability? {
        let suiteName = "MediaDownloaderPlaylistInspection-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.allowPlaylist = true
        let model = AppModel(settings: settings)
        model.urlText = url
        model.scheduleFormatInspection()

        let deadline = Date(timeIntervalSinceNow: timeout)
        while model.isInspectingPlaylist && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return model.playlistAvailability
    }
}
