import AppKit
import Foundation
import MediaDownloaderCore

@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case running
        case completed
        case completedWithWarnings
        case failed
        case cancelled
    }

    private struct DownloadedItem: Equatable {
        let url: URL
        let metadata: DownloadItemMetadata
    }

    @Published var urlText = ""
    @Published var kind: DownloadKind = .video
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var progress = 0.0
    @Published private(set) var currentTitle = ""
    @Published private(set) var statusMessage = ""
    @Published private(set) var errorMessage = ""
    @Published private(set) var outputURLs: [URL] = []
    @Published private(set) var logLines: [String] = []
    @Published private(set) var toolLocations = ToolLocator.locate()
    @Published private(set) var formatAvailability: FormatAvailability?
    @Published private(set) var playlistAvailability: PlaylistAvailability?
    @Published private(set) var isInspectingFormats = false
    @Published private(set) var isInspectingPlaylist = false
    @Published private(set) var formatInspectionFailed = false
    @Published private(set) var isConverting = false
    @Published private(set) var successfulItemCount = 0
    @Published private(set) var failedItemCount = 0

    let settings: AppSettings
    private let runner = DownloadRunner()
    private let conversionRunner = ConversionRunner()
    private let formatInspector = FormatInspector()
    private let playlistInspector = PlaylistInspector()
    private var inspectionTask: Task<Void, Never>?
    private var activeRequiresConversion = false
    private var activeDuration: TimeInterval?
    private var conversionTemporaryURL: URL?
    private var currentItemMetadata: DownloadItemMetadata?
    private var downloadedItems: [DownloadedItem] = []
    private var conversionQueue: [DownloadedItem] = []
    private var conversionQueueIndex = 0
    private var downloadFailureCount = 0
    private var downloadFailureIndexes = Set<Int>()
    private var sawUnindexedDownloadFailure = false
    private var conversionFailureCount = 0
    private var activeExpectedCount: Int?

    init(settings: AppSettings) {
        self.settings = settings
        statusMessage = settings.language.text(.statusReady)
    }

    var isRunning: Bool { phase == .running }
    var isInspectingMedia: Bool { isInspectingFormats || isInspectingPlaylist }
    var outputURL: URL? { outputURLs.last }

    var isPlaylistDownload: Bool {
        settings.allowPlaylist && (playlistAvailability?.isPlaylist ?? true)
    }

    var shouldConfirmPlaylist: Bool {
        isPlaylistDownload && settings.confirmPlaylistBeforeDownload
    }

    var playlistItemCount: Int? { playlistAvailability?.itemCount }
    var playlistTitle: String? { playlistAvailability?.title }

    var selectableVideoQualities: [VideoQuality] {
        if isPlaylistDownload { return VideoQuality.allCases }
        if let formatAvailability { return formatAvailability.selectableQualities }
        if formatInspectionFailed { return VideoQuality.allCases }
        var qualities = VideoQuality.quickTimeCompatibleCases
        if !qualities.contains(settings.videoQuality) {
            qualities.insert(settings.videoQuality, at: 1)
        }
        return qualities
    }

    var selectedRequiresConversion: Bool {
        guard kind == .video else { return false }
        if isPlaylistDownload {
            return settings.videoQuality == .best
                || (settings.videoQuality.maximumHeight ?? 0) > 1080
        }
        if let formatAvailability {
            return formatAvailability.requiresQuickTimeConversion(for: settings.videoQuality)
        }
        guard case .success = URLValidator.validate(urlText) else { return false }
        return settings.videoQuality == .best
            || (settings.videoQuality.maximumHeight ?? 0) > 1080
    }

    var sourceMaximumHeight: Int? { formatAvailability?.sourceMaximumHeight }

    var selectedResolutionHeight: Int? {
        if isPlaylistDownload { return settings.videoQuality.maximumHeight }
        guard let availability = formatAvailability else {
            return settings.videoQuality.maximumHeight
        }
        return min(
            settings.videoQuality.maximumHeight ?? availability.sourceMaximumHeight,
            availability.sourceMaximumHeight
        )
    }

    func useClipboard() {
        guard let value = NSPasteboard.general.string(forType: .string),
              case .success = URLValidator.validate(value) else { return }
        urlText = value.trimmingCharacters(in: .whitespacesAndNewlines)
        statusMessage = settings.language.text(.clipboardDetected)
        if phase != .running { phase = .idle }
    }

    func useClipboardIfAppropriate() {
        guard urlText.isEmpty else { return }
        useClipboard()
    }

    func refreshTools() {
        toolLocations = ToolLocator.locate()
    }

    func scheduleFormatInspection() {
        inspectionTask?.cancel()
        formatInspector.cancel()
        playlistInspector.cancel()
        formatAvailability = nil
        formatInspectionFailed = false
        playlistAvailability = nil
        isInspectingFormats = false
        isInspectingPlaylist = false

        guard case .success(let url) = URLValidator.validate(urlText) else { return }

        isInspectingFormats = kind == .video
        isInspectingPlaylist = settings.allowPlaylist
        inspectionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            if self.kind == .video {
                self.inspectFormats(url: url)
            }
            if self.settings.allowPlaylist {
                self.inspectPlaylist(url: url)
            }
        }
    }

    func startDownload() {
        inspectionTask?.cancel()
        formatInspector.cancel()
        playlistInspector.cancel()
        isInspectingFormats = false
        isInspectingPlaylist = false
        errorMessage = ""
        outputURLs = []
        currentTitle = ""
        logLines = []
        progress = 0
        successfulItemCount = 0
        failedItemCount = 0
        currentItemMetadata = nil
        downloadedItems = []
        conversionQueue = []
        conversionQueueIndex = 0
        downloadFailureCount = 0
        downloadFailureIndexes = []
        sawUnindexedDownloadFailure = false
        conversionFailureCount = 0

        let url: URL
        switch URLValidator.validate(urlText) {
        case .success(let validURL):
            url = validURL
        case .failure(let error):
            phase = .failed
            errorMessage = localizedValidationError(error)
            return
        }

        refreshTools()
        guard let ytDLP = toolLocations.ytDLP else {
            phase = .failed
            errorMessage = settings.language.text(.missingYtDLP)
            return
        }
        guard let ffmpeg = toolLocations.ffmpeg else {
            phase = .failed
            errorMessage = settings.language.text(.missingFFmpeg)
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: settings.destinationURL,
                withIntermediateDirectories: true
            )
        } catch {
            phase = .failed
            errorMessage = settings.language.text(.createFolderFailed)
            return
        }

        let needsConversion = selectedRequiresConversion
        let request = DownloadRequest(
            url: url,
            destinationDirectory: settings.destinationURL,
            kind: kind,
            videoQuality: settings.videoQuality,
            mp3Quality: settings.mp3Quality,
            allowPlaylist: settings.allowPlaylist,
            convertForQuickTime: needsConversion
        )
        let arguments = CommandBuilder.arguments(for: request, ffmpegURL: ffmpeg)
        let environment = toolEnvironment(ytDLP: ytDLP, ffmpeg: ffmpeg)

        activeRequiresConversion = request.convertForQuickTime
        activeDuration = formatAvailability?.duration
        activeExpectedCount = isPlaylistDownload ? playlistAvailability?.itemCount : 1
        isConverting = false
        conversionTemporaryURL = nil

        phase = .running
        statusMessage = settings.language.text(.preparing)

        do {
            try runner.start(
                executableURL: ytDLP,
                arguments: arguments,
                environment: environment,
                callbacks: .init(
                    onEvent: { [weak self] event in self?.handle(event) },
                    onRawLine: { [weak self] line in self?.appendLog(line) },
                    onCompletion: { [weak self] code, wasCancelled, recentLines in
                        self?.handleCompletion(exitCode: code, wasCancelled: wasCancelled, recentLines: recentLines)
                    }
                )
            )
        } catch {
            phase = .failed
            errorMessage = error.localizedDescription
        }
    }

    func cancelDownload() {
        guard isRunning else { return }
        statusMessage = settings.language.text(.cancelled)
        if isConverting {
            conversionRunner.cancel()
        } else {
            runner.cancel()
        }
    }

    func resetForAnotherDownload() {
        phase = .idle
        progress = 0
        currentTitle = ""
        statusMessage = settings.language.text(.statusReady)
        errorMessage = ""
        outputURLs = []
        logLines = []
        formatAvailability = nil
        formatInspectionFailed = false
        playlistAvailability = nil
        isInspectingFormats = false
        isInspectingPlaylist = false
        isConverting = false
        activeRequiresConversion = false
        activeDuration = nil
        activeExpectedCount = nil
        currentItemMetadata = nil
        downloadedItems = []
        conversionQueue = []
        conversionQueueIndex = 0
        downloadFailureCount = 0
        downloadFailureIndexes = []
        sawUnindexedDownloadFailure = false
        conversionFailureCount = 0
        successfulItemCount = 0
        failedItemCount = 0
        removeConversionTemporaryFile()
        urlText = ""
        useClipboardIfAppropriate()
    }

    func revealOutput() {
        let existingOutputs = outputURLs.filter { FileManager.default.fileExists(atPath: $0.path) }
        if !existingOutputs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(existingOutputs)
        } else {
            NSWorkspace.shared.open(settings.destinationURL)
        }
    }

    func updateLanguage() {
        if phase == .idle {
            statusMessage = settings.language.text(.statusReady)
        }
    }

    func configurePreview(formatAvailability: FormatAvailability?, inspectionFailed: Bool) {
        self.formatAvailability = formatAvailability
        formatInspectionFailed = inspectionFailed
    }

    private func handle(_ event: DownloadOutputEvent) {
        switch event {
        case .progress(let value):
            let index = currentItemMetadata?.index ?? 1
            let total = currentItemMetadata?.total ?? activeExpectedCount ?? 1
            let overallDownloadProgress = min(
                max((Double(index - 1) + value) / Double(max(total, 1)), 0),
                1
            )
            progress = activeRequiresConversion ? overallDownloadProgress * 0.5 : overallDownloadProgress
            let percent = Int((value * 100).rounded())
            let itemPosition = total > 1 ? " \(index)/\(total)" : ""
            statusMessage = settings.language == .japanese
                ? "ダウンロード中\(itemPosition)… \(percent)%"
                : "Downloading\(itemPosition)… \(percent)%"
        case .title(let title):
            currentTitle = title
        case .item(let metadata):
            currentItemMetadata = metadata
            currentTitle = metadata.title
            if let total = metadata.total { activeExpectedCount = total }
        case .file(let url):
            let fallbackIndex = downloadedItems.count + 1
            let metadata = currentItemMetadata ?? DownloadItemMetadata(
                index: fallbackIndex,
                total: activeExpectedCount,
                duration: downloadedItems.isEmpty ? activeDuration : nil,
                title: currentTitle.isEmpty ? url.deletingPathExtension().lastPathComponent : currentTitle
            )
            if !downloadedItems.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
                downloadedItems.append(DownloadedItem(url: url, metadata: metadata))
                outputURLs.append(url)
            }
        case .status(let status):
            if status.hasPrefix("ERROR:") {
                if let index = currentItemMetadata?.index {
                    downloadFailureIndexes.insert(index)
                } else {
                    sawUnindexedDownloadFailure = true
                }
                return
            }
            if status.hasPrefix("WARNING:") {
                return
            }
            statusMessage = localizedStatus(status)
        }
    }

    private func appendLog(_ line: String) {
        logLines.append(line)
        if logLines.count > 250 {
            logLines.removeFirst(logLines.count - 250)
        }
    }

    private func handleCompletion(exitCode: Int32, wasCancelled: Bool, recentLines: [String]) {
        if wasCancelled {
            phase = .cancelled
            statusMessage = settings.language.text(.cancelled)
            return
        }

        guard !downloadedItems.isEmpty else {
            phase = .failed
            statusMessage = settings.language.text(.failed)
            let usefulError = recentLines.last(where: { $0.hasPrefix("ERROR:") })
            errorMessage = usefulError?.replacingOccurrences(of: "ERROR:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                ?? settings.language.text(.genericFailure)
            return
        }

        let expected = activeExpectedCount ?? downloadedItems.count
        let missingItems = max(expected - downloadedItems.count, 0)
        let reportedFailures = max(
            downloadFailureIndexes.count,
            sawUnindexedDownloadFailure ? 1 : 0
        )
        if exitCode != 0 {
            downloadFailureCount = max(max(missingItems, reportedFailures), 1)
            appendLog("[Media Downloader] Playlist continued after one or more download failures")
        } else {
            downloadFailureCount = max(missingItems, reportedFailures)
        }

        if activeRequiresConversion, kind == .video {
            startQuickTimeConversionQueue()
        } else {
            finishDownloadProcessing()
        }
    }

    private func localizedValidationError(_ error: URLValidationError) -> String {
        switch error {
        case .empty: settings.language.text(.invalidEmpty)
        case .unsupportedScheme: settings.language.text(.invalidScheme)
        case .missingHost: settings.language.text(.invalidHost)
        }
    }

    private func inspectFormats(url: URL) {
        refreshTools()
        guard let ytDLP = toolLocations.ytDLP else {
            isInspectingFormats = false
            return
        }

        let inspectedURL = url.absoluteString
        do {
            try formatInspector.inspect(
                url: url,
                executableURL: ytDLP,
                environment: toolEnvironment(ytDLP: ytDLP, ffmpeg: toolLocations.ffmpeg),
                completion: { [weak self] result in
                    guard let self,
                          case .success(let currentURL) = URLValidator.validate(self.urlText),
                          currentURL.absoluteString == inspectedURL else { return }
                    self.isInspectingFormats = false
                    if case .success(let availability) = result {
                        self.formatAvailability = availability
                        self.formatInspectionFailed = false
                        if !self.settings.allowPlaylist,
                           !availability.selectableQualities.contains(self.settings.videoQuality) {
                            self.settings.videoQuality = .best
                        }
                    } else {
                        self.formatInspectionFailed = true
                    }
                }
            )
        } catch {
            isInspectingFormats = false
            formatInspectionFailed = true
        }
    }

    private func inspectPlaylist(url: URL) {
        refreshTools()
        guard let ytDLP = toolLocations.ytDLP else {
            isInspectingPlaylist = false
            return
        }

        let inspectedURL = url.absoluteString
        do {
            try playlistInspector.inspect(
                url: url,
                executableURL: ytDLP,
                environment: toolEnvironment(ytDLP: ytDLP, ffmpeg: toolLocations.ffmpeg),
                completion: { [weak self] result in
                    guard let self,
                          case .success(let currentURL) = URLValidator.validate(self.urlText),
                          currentURL.absoluteString == inspectedURL else { return }
                    self.isInspectingPlaylist = false
                    if case .success(let availability) = result {
                        self.playlistAvailability = availability
                    }
                }
            )
        } catch {
            isInspectingPlaylist = false
        }
    }

    private func startQuickTimeConversionQueue() {
        conversionQueue = downloadedItems.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        conversionFailureCount += downloadedItems.count - conversionQueue.count
        conversionQueueIndex = 0
        isConverting = true
        progress = max(progress, 0.5)
        startNextQuickTimeConversion()
    }

    private func startNextQuickTimeConversion() {
        guard conversionQueueIndex < conversionQueue.count else {
            isConverting = false
            conversionTemporaryURL = nil
            finishDownloadProcessing()
            return
        }

        guard let ffmpeg = toolLocations.ffmpeg else {
            conversionFailureCount += conversionQueue.count - conversionQueueIndex
            isConverting = false
            finishDownloadProcessing()
            return
        }

        let item = conversionQueue[conversionQueueIndex]
        let originalURL = item.url
        let baseName = originalURL.deletingPathExtension().lastPathComponent
        let temporaryURL = originalURL.deletingLastPathComponent()
            .appendingPathComponent(".\(baseName)-\(UUID().uuidString).converting.mp4")
        conversionTemporaryURL = temporaryURL
        currentTitle = item.metadata.title
        let position = conversionQueueIndex + 1
        let total = conversionQueue.count
        statusMessage = settings.language == .japanese
            ? "QuickTime用に変換中 \(position)/\(total)…"
            : "Converting for QuickTime \(position)/\(total)…"
        appendLog("[Media Downloader] Starting QuickTime HEVC conversion \(position)/\(total)")

        startQuickTimeConversion(
            ffmpeg: ffmpeg,
            item: item,
            originalURL: originalURL,
            temporaryURL: temporaryURL,
            encoder: .videoToolbox
        )
    }

    private func startQuickTimeConversion(
        ffmpeg: URL,
        item: DownloadedItem,
        originalURL: URL,
        temporaryURL: URL,
        encoder: ConversionRunner.VideoEncoder
    ) {
        conversionTemporaryURL = temporaryURL
        do {
            try conversionRunner.start(
                executableURL: ffmpeg,
                inputURL: originalURL,
                outputURL: temporaryURL,
                duration: item.metadata.duration ?? (conversionQueue.count == 1 ? activeDuration : nil),
                encoder: encoder,
                callbacks: .init(
                    onProgress: { [weak self] value in
                        guard let self else { return }
                        let overall = (Double(self.conversionQueueIndex) + value)
                            / Double(max(self.conversionQueue.count, 1))
                        self.progress = 0.5 + (overall * 0.5)
                        let percent = Int((value * 100).rounded())
                        let position = self.conversionQueueIndex + 1
                        let total = self.conversionQueue.count
                        self.statusMessage = self.settings.language == .japanese
                            ? "QuickTime用に変換中 \(position)/\(total)… \(percent)%"
                            : "Converting for QuickTime \(position)/\(total)… \(percent)%"
                    },
                    onRawLine: { [weak self] line in self?.appendLog(line) },
                    onCompletion: { [weak self] code, wasCancelled, recentLines in
                        self?.handleConversionCompletion(
                            exitCode: code,
                            wasCancelled: wasCancelled,
                            recentLines: recentLines,
                            originalURL: originalURL,
                            temporaryURL: temporaryURL,
                            encoder: encoder
                        )
                    }
                )
            )
        } catch {
            appendLog("[Media Downloader] Conversion could not start: \(error.localizedDescription)")
            conversionFailureCount += 1
            removeConversionTemporaryFile()
            conversionQueueIndex += 1
            startNextQuickTimeConversion()
        }
    }

    private func handleConversionCompletion(
        exitCode: Int32,
        wasCancelled: Bool,
        recentLines: [String],
        originalURL: URL,
        temporaryURL: URL,
        encoder: ConversionRunner.VideoEncoder
    ) {
        if wasCancelled {
            removeConversionTemporaryFile()
            isConverting = false
            phase = .cancelled
            statusMessage = settings.language.text(.cancelled)
            return
        }

        guard exitCode == 0, FileManager.default.fileExists(atPath: temporaryURL.path) else {
            if encoder == .videoToolbox, shouldUseIntelSoftwareFallback,
               let ffmpeg = toolLocations.ffmpeg {
                appendLog("[Media Downloader] VideoToolbox conversion failed; retrying with libx265")
                removeConversionTemporaryFile()
                let item = conversionQueue[conversionQueueIndex]
                statusMessage = settings.language == .japanese
                    ? "Intel向けソフトウェア変換で再試行しています…"
                    : "Retrying with Intel software conversion…"
                startQuickTimeConversion(
                    ffmpeg: ffmpeg,
                    item: item,
                    originalURL: originalURL,
                    temporaryURL: temporaryURL,
                    encoder: .software
                )
                return
            }
            appendLog(
                recentLines.last(where: { $0.lowercased().contains("error") })
                    ?? "[Media Downloader] QuickTime conversion failed"
            )
            conversionFailureCount += 1
            removeConversionTemporaryFile()
            conversionQueueIndex += 1
            startNextQuickTimeConversion()
            return
        }

        do {
            _ = try FileManager.default.replaceItemAt(originalURL, withItemAt: temporaryURL)
            conversionTemporaryURL = nil
            appendLog("[Media Downloader] QuickTime HEVC conversion completed")
        } catch {
            conversionFailureCount += 1
            appendLog("[Media Downloader] Could not replace converted file: \(error.localizedDescription)")
            removeConversionTemporaryFile()
        }

        conversionQueueIndex += 1
        startNextQuickTimeConversion()
    }

    private var shouldUseIntelSoftwareFallback: Bool {
        #if arch(x86_64)
        return true
        #else
        return ProcessInfo.processInfo.environment["MD_TEST_INTEL_SOFTWARE_FALLBACK"] == "1"
        #endif
    }

    private func finishDownloadProcessing() {
        failedItemCount = downloadFailureCount + conversionFailureCount
        successfulItemCount = max(downloadedItems.count - conversionFailureCount, 0)
        phase = failedItemCount > 0 ? .completedWithWarnings : .completed
        progress = 1
        statusMessage = settings.language.text(
            failedItemCount > 0 ? .completedWithWarnings : .completed
        )
        if settings.revealOnCompletion { revealOutput() }
    }

    private func removeConversionTemporaryFile() {
        if let conversionTemporaryURL,
           FileManager.default.fileExists(atPath: conversionTemporaryURL.path) {
            try? FileManager.default.removeItem(at: conversionTemporaryURL)
        }
        conversionTemporaryURL = nil
    }

    private func toolEnvironment(ytDLP: URL, ffmpeg: URL?) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        var toolDirectories = [ytDLP.deletingLastPathComponent().path]
        if let ffmpeg { toolDirectories.append(ffmpeg.deletingLastPathComponent().path) }
        environment["PATH"] = (toolDirectories + [(environment["PATH"] ?? "")]).joined(separator: ":")
        environment["PYTHONUNBUFFERED"] = "1"
        environment["LC_ALL"] = "en_US.UTF-8"
        return environment
    }

    private func localizedStatus(_ status: String) -> String {
        if status == "Converting to MP3…" {
            return settings.language == .japanese ? "MP3に変換しています…" : status
        }
        if status == "Merging video and audio…" {
            return settings.language == .japanese ? "動画と音声を結合しています…" : status
        }
        return status
    }
}
