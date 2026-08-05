import Foundation
import MediaDownloaderCore

enum AppLanguage: String, CaseIterable, Identifiable {
    case japanese
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .japanese: "日本語"
        case .english: "English"
        }
    }

    func text(_ key: AppTextKey) -> String {
        switch self {
        case .japanese: AppText.japanese[key] ?? key.rawValue
        case .english: AppText.english[key] ?? key.rawValue
        }
    }

    func videoQualityName(_ quality: VideoQuality) -> String {
        switch quality {
        case .best: text(.qualityBest)
        case .ultraHD2160: "4K (2160p)"
        case .quadHD1440: "2K (1440p)"
        case .fullHD1080: "Full HD (1080p)"
        case .hd720: "HD (720p)"
        }
    }

    func bestVideoQualityName(maximumHeight: Int?) -> String {
        guard let maximumHeight else { return text(.qualityBest) }
        let resolution: String
        switch maximumHeight {
        case 2160...: resolution = "4K"
        case 1440..<2160: resolution = "1440p"
        case 1080..<1440: resolution = "1080p"
        case 720..<1080: resolution = "720p"
        default: resolution = "\(maximumHeight)p"
        }
        switch self {
        case .japanese: return "最高画質（\(resolution)）"
        case .english: return "Best quality (\(resolution))"
        }
    }

    func mp3QualityName(_ quality: MP3Quality) -> String {
        switch quality {
        case .best: text(.audioBest)
        case .high: text(.audioHigh)
        case .standard: text(.audioStandard)
        }
    }
}

enum AppTextKey: String {
    case appName, downloadTab, settingsTab, urlLabel, urlPlaceholder, paste
    case clipboardDetected, video, mp3, format, quality, destination, choose
    case download, cancel, preparing, waiting, completed, completedWithWarnings, failed, cancelled
    case openInFinder, downloadAnother, settings, displaySettings, downloadSettings, language, allowPlaylist
    case allowPlaylistHelp, confirmPlaylist, confirmPlaylistHelp, revealOnCompletion, revealOnCompletionHelp
    case componentStatus, bundledToolsHelp, bundledToolMissingHelp, ready, missing, refresh, ytDLPDescription, ffmpegDescription
    case qualityBest, audioBest, audioHigh, audioStandard
    case invalidEmpty, invalidScheme, invalidHost, createFolderFailed
    case missingYtDLP, missingFFmpeg, genericFailure, currentItem, activity
    case log, noLog, selectFolder, statusReady, version, about
    case analyzingFormats, maximumResolution, selectedResolution, conversionNoticeTitle, conversionNoticeBody
    case conversionConfirmTitle, conversionConfirmMessage, continueAction
    case convertingForQuickTime, conversionFailed, fastWithoutConversion
    case playlistConfirmTitle, playlistCountUnknown, playlistTimeWarning
    case formatInspectionFailedTitle, formatInspectionFailedBody
    case supportedOS, supportedCPU, developer, orLater, unknownCPU
}

private enum AppText {
    static let japanese: [AppTextKey: String] = [
        .appName: "Media Downloader",
        .downloadTab: "ダウンロード",
        .settingsTab: "設定",
        .urlLabel: "メディアURL",
        .urlPlaceholder: "https://…",
        .paste: "ペースト",
        .clipboardDetected: "クリップボードのURLを入力しました",
        .video: "動画",
        .mp3: "MP3",
        .format: "形式",
        .quality: "品質",
        .destination: "保存先",
        .choose: "変更…",
        .download: "ダウンロード",
        .cancel: "キャンセル",
        .preparing: "準備しています…",
        .waiting: "URLを入力してください",
        .completed: "ダウンロードが完了しました",
        .completedWithWarnings: "一部の処理が完了しませんでした",
        .failed: "ダウンロードに失敗しました",
        .cancelled: "ダウンロードをキャンセルしました",
        .openInFinder: "Finderで表示",
        .downloadAnother: "続けてダウンロード",
        .settings: "設定",
        .displaySettings: "表示",
        .downloadSettings: "ダウンロード設定",
        .language: "表示言語",
        .allowPlaylist: "プレイリスト内の動画をすべて保存",
        .allowPlaylistHelp: "オンにすると、プレイリストURL内の動画をすべて保存します。オフの場合は、URLで指定した動画1件だけを保存します。動画数や画質によって時間と保存容量が増えます。",
        .confirmPlaylist: "プレイリスト開始前の確認を表示",
        .confirmPlaylistHelp: "対象件数、選択画質、変換時間と保存容量の注意をダウンロード前に表示します。",
        .revealOnCompletion: "完了後にFinderで表示",
        .revealOnCompletionHelp: "保存されたファイルをFinderで自動的に選択します。",
        .componentStatus: "このアプリが使用している内蔵ツール",
        .bundledToolsHelp: "yt-dlpとFFmpegはアプリに同梱されています。追加インストールは必要ありません。",
        .bundledToolMissingHelp: "内蔵ツールが見つかりません。アプリを再インストールしてください。",
        .ready: "内蔵・利用可能",
        .missing: "見つかりません",
        .refresh: "再確認",
        .ytDLPDescription: "対応サイトからメディア情報を取得します。",
        .ffmpegDescription: "動画と音声の結合、MP3変換に使用します。",
        .qualityBest: "最高画質（自動）",
        .audioBest: "最高音質",
        .audioHigh: "高音質",
        .audioStandard: "標準",
        .invalidEmpty: "URLを入力してください。",
        .invalidScheme: "http または https で始まるURLを入力してください。",
        .invalidHost: "有効なURLを入力してください。",
        .createFolderFailed: "保存先フォルダを使用できません。",
        .missingYtDLP: "yt-dlpが見つかりません。アプリを再インストールしてください。",
        .missingFFmpeg: "FFmpegが見つかりません。アプリを再インストールしてください。",
        .genericFailure: "処理中に問題が発生しました。ログを確認してください。",
        .currentItem: "処理中",
        .activity: "進捗",
        .log: "詳細ログ",
        .noLog: "ログはまだありません。",
        .selectFolder: "保存先フォルダを選択",
        .statusReady: "ダウンロードする準備ができています",
        .version: "バージョン",
        .about: "このアプリについて",
        .analyzingFormats: "利用可能な解像度を確認しています…",
        .maximumResolution: "利用可能な最大解像度",
        .selectedResolution: "現在の選択",
        .conversionNoticeTitle: "ダウンロード後に変換します",
        .conversionNoticeBody: "この解像度はQuickTime用のHEVCへ変換するため、1080pより完了まで時間がかかります。",
        .conversionConfirmTitle: "変換が必要な画質です",
        .conversionConfirmMessage: "ダウンロード後にQuickTime対応形式へ変換します。動画の長さにより変換に時間がかかります。1080p以下なら通常は変換なしで早く完了します。",
        .continueAction: "ダウンロードを続ける",
        .convertingForQuickTime: "QuickTime用に変換しています…",
        .conversionFailed: "QuickTime対応形式への変換に失敗しました。元のダウンロードファイルは残っています。",
        .fastWithoutConversion: "この解像度は変換なしでダウンロードできます。",
        .playlistConfirmTitle: "プレイリスト全体を保存しますか？",
        .playlistCountUnknown: "件数不明",
        .playlistTimeWarning: "動画数や選択画質によって、長い処理時間と大きな保存容量が必要になる場合があります。",
        .formatInspectionFailedTitle: "利用可能な画質を確認できませんでした",
        .formatInspectionFailedBody: "画質はすべて選択できます。選択した画質がない場合は、実際に利用できる範囲で保存されます。",
        .supportedOS: "対応OS",
        .supportedCPU: "対応CPU",
        .developer: "開発者",
        .orLater: "以降",
        .unknownCPU: "不明"
    ]

    static let english: [AppTextKey: String] = [
        .appName: "Media Downloader",
        .downloadTab: "Download",
        .settingsTab: "Settings",
        .urlLabel: "Media URL",
        .urlPlaceholder: "https://…",
        .paste: "Paste",
        .clipboardDetected: "URL pasted from the clipboard",
        .video: "Video",
        .mp3: "MP3",
        .format: "Format",
        .quality: "Quality",
        .destination: "Save to",
        .choose: "Choose…",
        .download: "Download",
        .cancel: "Cancel",
        .preparing: "Preparing…",
        .waiting: "Enter a URL to begin",
        .completed: "Download completed",
        .completedWithWarnings: "Some items could not be completed",
        .failed: "Download failed",
        .cancelled: "Download cancelled",
        .openInFinder: "Show in Finder",
        .downloadAnother: "Download another",
        .settings: "Settings",
        .displaySettings: "Display",
        .downloadSettings: "Download settings",
        .language: "Language",
        .allowPlaylist: "Save every video in playlists",
        .allowPlaylistHelp: "When enabled, every video in a playlist URL is saved. When disabled, only the video specified by the URL is saved. More videos and higher quality require more time and storage.",
        .confirmPlaylist: "Confirm before starting playlists",
        .confirmPlaylistHelp: "Shows the item count, selected quality, and time and storage notice before downloading.",
        .revealOnCompletion: "Show in Finder when complete",
        .revealOnCompletionHelp: "Automatically selects the saved file in Finder.",
        .componentStatus: "Bundled tools used by this app",
        .bundledToolsHelp: "yt-dlp and FFmpeg are included with the app. No additional installation is required.",
        .bundledToolMissingHelp: "A bundled tool is missing. Reinstall the application.",
        .ready: "Bundled and available",
        .missing: "Missing",
        .refresh: "Check again",
        .ytDLPDescription: "Retrieves media information from supported sites.",
        .ffmpegDescription: "Merges video and audio and converts MP3 files.",
        .qualityBest: "Best quality (Auto)",
        .audioBest: "Best quality",
        .audioHigh: "High quality",
        .audioStandard: "Standard",
        .invalidEmpty: "Enter a URL.",
        .invalidScheme: "Enter a URL beginning with http or https.",
        .invalidHost: "Enter a valid URL.",
        .createFolderFailed: "The destination folder cannot be used.",
        .missingYtDLP: "yt-dlp is missing. Reinstall the application.",
        .missingFFmpeg: "FFmpeg is missing. Reinstall the application.",
        .genericFailure: "Something went wrong. Check the log for details.",
        .currentItem: "Current item",
        .activity: "Progress",
        .log: "Details",
        .noLog: "No log output yet.",
        .selectFolder: "Choose download folder",
        .statusReady: "Ready to download",
        .version: "Version",
        .about: "About",
        .analyzingFormats: "Checking available resolutions…",
        .maximumResolution: "Maximum available resolution",
        .selectedResolution: "Current selection",
        .conversionNoticeTitle: "Conversion required after download",
        .conversionNoticeBody: "This resolution will be converted to HEVC for QuickTime, so it takes longer than 1080p.",
        .conversionConfirmTitle: "This quality requires conversion",
        .conversionConfirmMessage: "After downloading, the video will be converted to a QuickTime-compatible format. Conversion time depends on video length. 1080p or lower normally finishes faster without conversion.",
        .continueAction: "Continue download",
        .convertingForQuickTime: "Converting for QuickTime…",
        .conversionFailed: "Conversion to a QuickTime-compatible format failed. The original downloaded file was kept.",
        .fastWithoutConversion: "This resolution downloads without conversion.",
        .playlistConfirmTitle: "Save the entire playlist?",
        .playlistCountUnknown: "Unknown item count",
        .playlistTimeWarning: "The number of videos and selected quality may require substantial processing time and storage.",
        .formatInspectionFailedTitle: "Available qualities could not be checked",
        .formatInspectionFailedBody: "All quality choices remain available. If the selected quality is unavailable, the best available quality within that limit will be saved.",
        .supportedOS: "Supported OS",
        .supportedCPU: "Supported CPU",
        .developer: "Developer",
        .orLater: "or later",
        .unknownCPU: "Unknown"
    ]
}
