// swift-tools-version: 5.9
import PackageDescription

// This Package.swift is automatically updated by GitHub Actions during release.
// The URLs and checksums below point to the latest pre-compiled XCFrameworks.

let package = Package(
    name: "SCXSocketIO",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "SCXSocketIO",   targets: ["SCXSocketIO"]),
        .library(name: "SCXStarscream", targets: ["SCXStarscream"]),
    ],
    targets: [
        .binaryTarget(
            name: "SCXStarscream",
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v16.1.0/SCXStarscream.xcframework.zip",
            checksum: "PLACEHOLDER_WILL_BE_REPLACED_BY_CI"
        ),
        .binaryTarget(
            name: "SCXSocketIO",
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v16.1.0/SCXSocketIO.xcframework.zip",
            checksum: "PLACEHOLDER_WILL_BE_REPLACED_BY_CI"
        ),
    ]
)
