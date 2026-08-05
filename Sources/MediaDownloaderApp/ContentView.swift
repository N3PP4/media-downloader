import AppKit
import MediaDownloaderCore
import SwiftUI

struct ContentView: View {
    private enum Section: String {
        case download
        case settings
    }

    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    @State private var selectedSection: Section = .download
    private let automaticClipboardDetection: Bool

    init(
        model: AppModel,
        settings: AppSettings,
        showSettings: Bool = false,
        automaticClipboardDetection: Bool = true
    ) {
        self.model = model
        self.settings = settings
        self.automaticClipboardDetection = automaticClipboardDetection
        _selectedSection = State(initialValue: showSettings ? .settings : .download)
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("", selection: $selectedSection) {
                Label(settings.language.text(.downloadTab), systemImage: "arrow.down.circle.fill")
                    .tag(Section.download)
                Label(settings.language.text(.settingsTab), systemImage: "gearshape.fill")
                    .tag(Section.settings)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 270)

            Group {
                switch selectedSection {
                case .download:
                    DownloadView(model: model, settings: settings)
                case .settings:
                    SettingsView(model: model, settings: settings)
                }
            }
        }
        .padding(18)
        .frame(minWidth: 700, idealWidth: 760, minHeight: 570, idealHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            model.refreshTools()
            if automaticClipboardDetection {
                model.useClipboardIfAppropriate()
                model.scheduleFormatInspection()
            }
        }
        .onChange(of: settings.language) { _ in
            model.updateLanguage()
        }
        .onChange(of: model.urlText) { _ in
            model.scheduleFormatInspection()
        }
        .onChange(of: model.kind) { _ in
            model.scheduleFormatInspection()
        }
        .onChange(of: settings.allowPlaylist) { _ in
            model.scheduleFormatInspection()
        }
    }
}

private struct DownloadView: View {
    private enum DownloadConfirmation: String, Identifiable {
        case conversion
        case playlist

        var id: String { rawValue }
    }

    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    @State private var isLogExpanded = false
    @State private var downloadConfirmation: DownloadConfirmation?

    private var language: AppLanguage { settings.language }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                urlSection
                formatSection
                destinationSection
                actionSection
                if model.phase != .idle || !model.logLines.isEmpty {
                    logSection
                }
            }
            .padding(8)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                Image(systemName: "arrow.down.to.line.compact")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(language.text(.appName))
                .font(.system(size: 25, weight: .bold))
            Spacer()
        }
    }

    private var urlSection: some View {
        GroupBox {
            HStack(spacing: 10) {
                TextField(language.text(.urlPlaceholder), text: $model.urlText)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .disabled(model.isRunning)
                    .onSubmit {
                        if !model.isRunning && !model.isInspectingMedia {
                            beginDownload()
                        }
                    }

                Button(action: model.useClipboard) {
                    Label(language.text(.paste), systemImage: "doc.on.clipboard")
                }
                .disabled(model.isRunning)
            }
            .padding(.vertical, 4)
        } label: {
            Label(language.text(.urlLabel), systemImage: "link")
                .font(.headline)
        }
    }

    private var formatSection: some View {
        GroupBox {
            VStack(spacing: 14) {
                Picker(language.text(.format), selection: $model.kind) {
                    Label(language.text(.video), systemImage: "film").tag(DownloadKind.video)
                    Label(language.text(.mp3), systemImage: "music.note").tag(DownloadKind.mp3)
                }
                .pickerStyle(.segmented)
                .disabled(model.isRunning)

                HStack {
                    Text(language.text(.quality))
                        .foregroundStyle(.secondary)
                    Spacer()

                    if model.kind == .video {
                        Picker("", selection: $settings.videoQuality) {
                            ForEach(model.selectableVideoQualities) { quality in
                                Text(videoQualityName(quality)).tag(quality)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 190)
                    } else {
                        Picker("", selection: $settings.mp3Quality) {
                            ForEach(MP3Quality.allCases) { quality in
                                Text(language.mp3QualityName(quality)).tag(quality)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 190)
                    }
                }
                .disabled(model.isRunning)

                if model.kind == .video {
                    formatAvailabilityNotice
                }
            }
            .padding(.vertical, 5)
        } label: {
            Label(language.text(.format), systemImage: "slider.horizontal.3")
                .font(.headline)
        }
    }

    private var destinationSection: some View {
        GroupBox {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.destinationURL.lastPathComponent)
                        .fontWeight(.medium)
                    Text(settings.destinationURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button(language.text(.choose), action: chooseDestination)
                    .disabled(model.isRunning)
            }
            .padding(.vertical, 5)
        } label: {
            Label(language.text(.destination), systemImage: "folder")
                .font(.headline)
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        switch model.phase {
        case .idle:
            VStack(spacing: 9) {
                Button(action: beginDownload) {
                    Label(language.text(.download), systemImage: "arrow.down.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .disabled(model.isInspectingMedia)
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .alert(item: $downloadConfirmation) { confirmation in
                Alert(
                    title: Text(confirmationTitle(confirmation)),
                    message: Text(confirmationMessage(confirmation)),
                    primaryButton: .cancel(Text(language.text(.cancel))),
                    secondaryButton: .default(Text(language.text(.continueAction))) {
                        model.startDownload()
                    }
                )
            }

        case .running:
            progressCard

        case .completed:
            resultCard(
                icon: "checkmark.circle.fill",
                color: .green,
                title: language.text(.completed),
                message: completionSummary
            ) {
                Button(language.text(.openInFinder), action: model.revealOutput)
                Button(language.text(.downloadAnother), action: model.resetForAnotherDownload)
                    .buttonStyle(.borderedProminent)
            }

        case .completedWithWarnings:
            resultCard(
                icon: "exclamationmark.circle.fill",
                color: .orange,
                title: language.text(.completedWithWarnings),
                message: completionSummary
            ) {
                Button(language.text(.openInFinder), action: model.revealOutput)
                Button(language.text(.downloadAnother), action: model.resetForAnotherDownload)
                    .buttonStyle(.borderedProminent)
            }

        case .failed:
            resultCard(
                icon: "exclamationmark.triangle.fill",
                color: .red,
                title: language.text(.failed),
                message: model.errorMessage
            ) {
                Button(language.text(.downloadAnother), action: model.resetForAnotherDownload)
                    .buttonStyle(.borderedProminent)
            }

        case .cancelled:
            resultCard(
                icon: "xmark.circle.fill",
                color: .orange,
                title: language.text(.cancelled),
                message: model.currentTitle
            ) {
                Button(language.text(.downloadAnother), action: model.resetForAnotherDownload)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.currentTitle.isEmpty ? language.text(.preparing) : model.currentTitle)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    Text(model.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int((model.progress * 100).rounded()))%")
                    .font(.system(.body, design: .rounded).weight(.semibold))
            }
            ProgressView(value: model.progress)
                .progressViewStyle(.linear)
            HStack {
                Spacer()
                Button(role: .destructive, action: model.cancelDownload) {
                    Label(language.text(.cancel), systemImage: "stop.fill")
                }
            }
        }
        .padding(15)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func resultCard<Actions: View>(
        icon: String,
        color: Color,
        title: String,
        message: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 35))
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
            if !message.isEmpty {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            HStack { actions() }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var logSection: some View {
        DisclosureGroup(isExpanded: $isLogExpanded) {
            ScrollView {
                Text(model.logLines.isEmpty ? language.text(.noLog) : model.logLines.joined(separator: "\n"))
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(height: 130)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
            .padding(.top, 8)
        } label: {
            Label(language.text(.log), systemImage: "terminal")
                .font(.subheadline.weight(.medium))
        }
    }

    @ViewBuilder
    private var formatAvailabilityNotice: some View {
        if model.isInspectingMedia {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(language.text(.analyzingFormats))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else if model.formatInspectionFailed {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(language.text(.formatInspectionFailedTitle))
                        .font(.caption.weight(.semibold))
                    Text(language.text(.formatInspectionFailedBody))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if model.selectedRequiresConversion {
                        Divider().padding(.vertical, 2)
                        Text(language.text(.conversionNoticeTitle))
                            .font(.caption.weight(.semibold))
                        Text(language.text(.conversionNoticeBody))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(10)
            .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        } else if model.selectedRequiresConversion {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    if let selectedHeight = model.selectedResolutionHeight {
                        Text("\(language.text(.selectedResolution)): \(resolutionName(selectedHeight))")
                            .font(.caption.weight(.semibold))
                    }
                    Text(language.text(.conversionNoticeTitle))
                        .font(.caption.weight(.semibold))
                    Text(language.text(.conversionNoticeBody))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        } else if let maximumHeight = model.sourceMaximumHeight {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(language.text(.maximumResolution)): \(resolutionName(maximumHeight))")
                    if let selectedHeight = model.selectedResolutionHeight {
                        Text("\(language.text(.selectedResolution)): \(resolutionName(selectedHeight)) • \(language.text(.fastWithoutConversion))")
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .font(.caption)
        }
    }

    private func beginDownload() {
        guard !model.isInspectingMedia else { return }
        if model.shouldConfirmPlaylist {
            downloadConfirmation = .playlist
        } else if model.selectedRequiresConversion {
            downloadConfirmation = .conversion
        } else {
            model.startDownload()
        }
    }

    private func confirmationTitle(_ confirmation: DownloadConfirmation) -> String {
        switch confirmation {
        case .conversion: language.text(.conversionConfirmTitle)
        case .playlist: language.text(.playlistConfirmTitle)
        }
    }

    private func confirmationMessage(_ confirmation: DownloadConfirmation) -> String {
        guard confirmation == .playlist else {
            return language.text(.conversionConfirmMessage)
        }

        let count: String
        if let itemCount = model.playlistItemCount {
            count = language == .japanese ? "\(itemCount)件" : "\(itemCount) items"
        } else {
            count = language.text(.playlistCountUnknown)
        }
        let quality = model.kind == .video
            ? videoQualityName(settings.videoQuality)
            : language.mp3QualityName(settings.mp3Quality)
        let conversion = model.selectedRequiresConversion
            ? "\n\n\(language.text(.conversionConfirmMessage))"
            : ""
        let playlistName = model.playlistTitle.map {
            language == .japanese ? "プレイリスト：\($0)\n" : "Playlist: \($0)\n"
        } ?? ""
        if language == .japanese {
            return "\(playlistName)対象：\(count)\n品質：\(quality)\n\n\(language.text(.playlistTimeWarning))\(conversion)"
        }
        return "\(playlistName)Items: \(count)\nQuality: \(quality)\n\n\(language.text(.playlistTimeWarning))\(conversion)"
    }

    private var completionSummary: String {
        let total = model.successfulItemCount + model.failedItemCount
        guard total > 1 || model.failedItemCount > 0 else { return model.currentTitle }
        if language == .japanese {
            return "成功：\(model.successfulItemCount)件　失敗：\(model.failedItemCount)件"
        }
        return "Succeeded: \(model.successfulItemCount)  Failed: \(model.failedItemCount)"
    }

    private func resolutionName(_ height: Int) -> String {
        switch height {
        case 2160...: "4K"
        case 1440..<2160: "1440p"
        case 1080..<1440: "1080p"
        case 720..<1080: "720p"
        default: "\(height)p"
        }
    }

    private func videoQualityName(_ quality: VideoQuality) -> String {
        let baseName = language.videoQualityName(quality)
        guard quality == .best,
              !model.isPlaylistDownload,
              let maximumHeight = model.sourceMaximumHeight else {
            return baseName
        }
        return language.bestVideoQualityName(maximumHeight: maximumHeight)
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.title = language.text(.selectFolder)
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.destinationURL
        if panel.runModal() == .OK, let url = panel.url {
            settings.destinationURL = url
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings

    private var language: AppLanguage { settings.language }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(language.text(.settings))
                    .font(.system(size: 24, weight: .bold))

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        settingRow(title: language.text(.language)) {
                            Picker("", selection: $settings.language) {
                                ForEach(AppLanguage.allCases) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                    }
                    .padding(.vertical, 4)
                } label: {
                    Text(language.text(.displaySettings)).font(.headline)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        settingToggle(
                            title: language.text(.allowPlaylist),
                            help: language.text(.allowPlaylistHelp),
                            isOn: $settings.allowPlaylist
                        )
                        Divider()
                        settingToggle(
                            title: language.text(.confirmPlaylist),
                            help: language.text(.confirmPlaylistHelp),
                            isOn: $settings.confirmPlaylistBeforeDownload
                        )
                        .disabled(!settings.allowPlaylist)
                        Divider()
                        settingToggle(
                            title: language.text(.revealOnCompletion),
                            help: language.text(.revealOnCompletionHelp),
                            isOn: $settings.revealOnCompletion
                        )
                    }
                    .padding(.vertical, 4)
                } label: {
                    Text(language.text(.downloadSettings)).font(.headline)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(language.text(.bundledToolsHelp))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        componentRow(
                            name: "yt-dlp",
                            description: language.text(.ytDLPDescription),
                            location: model.toolLocations.ytDLP
                        )
                        Divider()
                        componentRow(
                            name: "FFmpeg",
                            description: language.text(.ffmpegDescription),
                            location: model.toolLocations.ffmpeg
                        )
                        HStack {
                            Spacer()
                            Button(action: model.refreshTools) {
                                Label(language.text(.refresh), systemImage: "arrow.clockwise")
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } label: {
                    Text(language.text(.componentStatus)).font(.headline)
                }

                GroupBox {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(language.text(.appName)).fontWeight(.semibold)
                            Text("\(language.text(.version)) \(appVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(language.text(.supportedOS)): macOS Monterey 12 \(language.text(.orLater))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(language.text(.supportedCPU)): \(architectureName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(language.text(.developer)): N3PP4")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Powered by yt-dlp and FFmpeg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.tint)
                    }
                    .padding(.vertical, 4)
                } label: {
                    Text(language.text(.about)).font(.headline)
                }
            }
            .padding(8)
        }
    }

    private func settingRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
            Spacer()
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingToggle(title: String, help: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(help)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.checkbox)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func componentRow(name: String, description: String, location: URL?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: location == nil ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(location == nil ? .orange : .green)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let location {
                    Text(location.path)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(language.text(.bundledToolMissingHelp))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Text(language.text(location == nil ? .missing : .ready))
                .font(.caption.weight(.semibold))
                .foregroundStyle(location == nil ? .orange : .green)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.2.1"
    }

    private var architectureName: String {
        #if arch(arm64)
        return "Apple Silicon"
        #elseif arch(x86_64)
        return "Intel"
        #else
        return language.text(.unknownCPU)
        #endif
    }
}
