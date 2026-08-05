import MediaDownloaderUI
import SwiftUI

@main
struct MediaDownloaderApp: App {
    var body: some Scene {
        WindowGroup {
            MediaDownloaderRoot()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
