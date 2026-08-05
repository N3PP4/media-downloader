// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MediaDownloader",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "MediaDownloaderCore", targets: ["MediaDownloaderCore"]),
        .executable(name: "MediaDownloaderApp", targets: ["MediaDownloaderApp"]),
        .executable(name: "MediaDownloaderCoreTestsRunner", targets: ["MediaDownloaderCoreTestsRunner"]),
        .executable(name: "MediaDownloaderUISnapshot", targets: ["MediaDownloaderUISnapshot"]),
        .executable(name: "MediaDownloaderAppIntegrationRunner", targets: ["MediaDownloaderAppIntegrationRunner"])
    ],
    targets: [
        .target(name: "MediaDownloaderCore"),
        .target(
            name: "MediaDownloaderUI",
            dependencies: ["MediaDownloaderCore"],
            path: "Sources/MediaDownloaderApp"
        ),
        .executableTarget(
            name: "MediaDownloaderApp",
            dependencies: ["MediaDownloaderUI"],
            path: "Sources/MediaDownloaderEntry"
        ),
        .executableTarget(
            name: "MediaDownloaderCoreTestsRunner",
            dependencies: ["MediaDownloaderCore"]
        ),
        .executableTarget(
            name: "MediaDownloaderUISnapshot",
            dependencies: ["MediaDownloaderUI", "MediaDownloaderCore"],
            path: "Sources/MediaDownloaderUISnapshot"
        ),
        .executableTarget(
            name: "MediaDownloaderAppIntegrationRunner",
            dependencies: ["MediaDownloaderUI", "MediaDownloaderCore"],
            path: "Sources/MediaDownloaderAppIntegrationRunner"
        )
    ]
)
