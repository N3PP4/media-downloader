import Foundation
import MediaDownloaderCore

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let language = "language"
        static let destinationPath = "destinationPath"
        static let videoQuality = "videoQuality"
        static let mp3Quality = "mp3Quality"
        static let allowPlaylist = "allowPlaylist"
        static let confirmPlaylistBeforeDownload = "confirmPlaylistBeforeDownload"
        static let revealOnCompletion = "revealOnCompletion"
    }

    private let defaults: UserDefaults

    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }
    @Published var destinationURL: URL {
        didSet { defaults.set(destinationURL.path, forKey: Key.destinationPath) }
    }
    @Published var videoQuality: VideoQuality {
        didSet { defaults.set(videoQuality.rawValue, forKey: Key.videoQuality) }
    }
    @Published var mp3Quality: MP3Quality {
        didSet { defaults.set(mp3Quality.rawValue, forKey: Key.mp3Quality) }
    }
    @Published var allowPlaylist: Bool {
        didSet { defaults.set(allowPlaylist, forKey: Key.allowPlaylist) }
    }
    @Published var confirmPlaylistBeforeDownload: Bool {
        didSet { defaults.set(confirmPlaylistBeforeDownload, forKey: Key.confirmPlaylistBeforeDownload) }
    }
    @Published var revealOnCompletion: Bool {
        didSet { defaults.set(revealOnCompletion, forKey: Key.revealOnCompletion) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        language = AppLanguage(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .japanese
        videoQuality = VideoQuality(rawValue: defaults.string(forKey: Key.videoQuality) ?? "") ?? .best
        mp3Quality = MP3Quality(rawValue: defaults.string(forKey: Key.mp3Quality) ?? "") ?? .best
        allowPlaylist = defaults.object(forKey: Key.allowPlaylist) as? Bool ?? false
        confirmPlaylistBeforeDownload = defaults.object(forKey: Key.confirmPlaylistBeforeDownload) as? Bool ?? true
        revealOnCompletion = defaults.object(forKey: Key.revealOnCompletion) as? Bool ?? true

        if let savedPath = defaults.string(forKey: Key.destinationPath), !savedPath.isEmpty {
            destinationURL = URL(fileURLWithPath: savedPath, isDirectory: true)
        } else {
            destinationURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
        }
    }
}
