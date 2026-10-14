// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LightBringer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LightBringer", targets: ["LightBringer"])
    ],
    targets: [
        .executableTarget(
            name: "LightBringer",
            path: "Sources/LightBringer",
            swiftSettings: [
                // Keep compatibility with AppKit APIs whose concurrency annotations
                // differ between macOS SDK versions.
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
