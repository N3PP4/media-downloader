import AppKit
import MediaDownloaderCore
import MediaDownloaderUI
import SwiftUI

@MainActor
func renderSnapshot(to outputURL: URL, showSettings: Bool, showConversion: Bool, useDarkMode: Bool) throws {
    let viewHeight: CGFloat = showSettings ? 1000 : 640
    let previousQuality = UserDefaults.standard.string(forKey: "videoQuality")
    let previousLanguage = UserDefaults.standard.string(forKey: "language")
    let previousAllowPlaylist = UserDefaults.standard.object(forKey: "allowPlaylist")
    let previousPlaylistConfirmation = UserDefaults.standard.object(forKey: "confirmPlaylistBeforeDownload")
    UserDefaults.standard.set(snapshotUsesEnglish ? "english" : "japanese", forKey: "language")
    if showConversion { UserDefaults.standard.set("best", forKey: "videoQuality") }
    if showSettings {
        UserDefaults.standard.set(true, forKey: "allowPlaylist")
        UserDefaults.standard.set(true, forKey: "confirmPlaylistBeforeDownload")
    }
    let rootView = MediaDownloaderRoot(
        showSettings: showSettings,
        automaticClipboardDetection: false,
        initialURL: (showConversion || showInspectionFailure) ? "https://example.com/video" : "",
        previewFormatAvailability: showConversion
            ? FormatAvailability(
                sourceMaximumHeight: snapshotMaximumHeight,
                quickTimeMaximumHeight: 1080,
                hasAACAudio: true,
                duration: 30
            )
            : nil,
        previewFormatInspectionFailed: showInspectionFailure
    )
        .frame(width: 760, height: viewHeight)
        .environment(\.colorScheme, useDarkMode ? .dark : .light)
    if let previousQuality {
        UserDefaults.standard.set(previousQuality, forKey: "videoQuality")
    } else {
        UserDefaults.standard.removeObject(forKey: "videoQuality")
    }
    if let previousLanguage {
        UserDefaults.standard.set(previousLanguage, forKey: "language")
    } else {
        UserDefaults.standard.removeObject(forKey: "language")
    }
    if let previousAllowPlaylist {
        UserDefaults.standard.set(previousAllowPlaylist, forKey: "allowPlaylist")
    } else {
        UserDefaults.standard.removeObject(forKey: "allowPlaylist")
    }
    if let previousPlaylistConfirmation {
        UserDefaults.standard.set(previousPlaylistConfirmation, forKey: "confirmPlaylistBeforeDownload")
    } else {
        UserDefaults.standard.removeObject(forKey: "confirmPlaylistBeforeDownload")
    }
    let hostingView = NSHostingView(rootView: rootView)
    hostingView.frame = NSRect(x: 0, y: 0, width: 760, height: viewHeight)

    let window = NSWindow(
        contentRect: hostingView.frame,
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.contentView = hostingView
    window.layoutIfNeeded()
    hostingView.layoutSubtreeIfNeeded()

    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
    hostingView.layoutSubtreeIfNeeded()

    guard let representation = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
        throw NSError(domain: "MediaDownloaderUISnapshot", code: 1)
    }
    hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
    guard let png = representation.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "MediaDownloaderUISnapshot", code: 2)
    }
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try png.write(to: outputURL, options: .atomic)
}

let arguments = Array(CommandLine.arguments.dropFirst())
let showSettings = arguments.contains("--settings")
let showConversion = arguments.contains("--conversion")
let useDarkMode = arguments.contains("--dark")
let showInspectionFailure = arguments.contains("--inspection-failure")
let snapshotUsesEnglish = arguments.contains("--english")
let snapshotMaximumHeight = arguments
    .first(where: { $0.hasPrefix("--maximum-height=") })
    .flatMap { Int($0.replacingOccurrences(of: "--maximum-height=", with: "")) }
    ?? 2160
let optionPrefixes = ["--settings", "--conversion", "--dark", "--english", "--inspection-failure", "--maximum-height="]
let outputPath = arguments.first(where: { argument in
    !optionPrefixes.contains(where: { prefix in argument == prefix || argument.hasPrefix(prefix) })
})
    ?? FileManager.default.currentDirectoryPath + "/.build/ui-snapshot.png"

do {
    NSApplication.shared.setActivationPolicy(.prohibited)
    try MainActor.assumeIsolated {
        try renderSnapshot(
            to: URL(fileURLWithPath: outputPath),
            showSettings: showSettings,
            showConversion: showConversion,
            useDarkMode: useDarkMode
        )
    }
    print("Rendered \(outputPath)")
} catch {
    fputs("Snapshot failed: \(error)\n", stderr)
    exit(1)
}
