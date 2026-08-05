import MediaDownloaderCore
import SwiftUI

public struct MediaDownloaderRoot: View {
    @StateObject private var settings: AppSettings
    @StateObject private var model: AppModel
    private let showSettings: Bool
    private let automaticClipboardDetection: Bool

    public init(
        showSettings: Bool = false,
        automaticClipboardDetection: Bool = true,
        initialURL: String = "",
        previewFormatAvailability: FormatAvailability? = nil,
        previewFormatInspectionFailed: Bool = false
    ) {
        let settings = AppSettings()
        let model = AppModel(settings: settings)
        model.urlText = initialURL
        model.configurePreview(
            formatAvailability: previewFormatAvailability,
            inspectionFailed: previewFormatInspectionFailed
        )
        self.showSettings = showSettings
        self.automaticClipboardDetection = automaticClipboardDetection
        _settings = StateObject(wrappedValue: settings)
        _model = StateObject(wrappedValue: model)
    }

    public var body: some View {
        ContentView(
            model: model,
            settings: settings,
            showSettings: showSettings,
            automaticClipboardDetection: automaticClipboardDetection
        )
    }
}
