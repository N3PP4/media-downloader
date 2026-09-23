import Foundation
import MediaDownloaderCore

@MainActor
final class AppReleaseChecker: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case current(AppRelease)
        case updateAvailable(AppRelease)
        case failed
    }

    static let releasesURL = URL(string: "https://github.com/N3PP4/media-downloader/releases")!
    private static let apiURL = URL(string: "https://api.github.com/repos/N3PP4/media-downloader/releases?per_page=20")!

    @Published private(set) var state: State = .idle

    func check(installedVersion: String) {
        guard state != .checking else { return }
        state = .checking

        Task {
            do {
                var request = URLRequest(url: Self.apiURL)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("Media-Downloader", forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 15
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let response = response as? HTTPURLResponse,
                      response.statusCode == 200,
                      let release = try ReleaseCatalog.newestRelease(in: data) else {
                    state = .failed
                    return
                }
                state = ReleaseCatalog.isNewer(release, than: installedVersion)
                    ? .updateAvailable(release)
                    : .current(release)
            } catch {
                state = .failed
            }
        }
    }
}
