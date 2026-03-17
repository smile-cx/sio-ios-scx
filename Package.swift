// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SCXSocketIO",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "SCXSocketIO",
            targets: ["SCXSocketIO"]
        ),
        .library(
            name: "SCXStarscream",
            targets: ["SCXStarscream"]
        )
    ],
    dependencies: [],
    targets: [
        // Binary targets will be updated by GitHub Actions during release
        // These are placeholder targets - actual URLs and checksums are added during the release process
        .binaryTarget(
            name: "SCXStarscream",
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v16.1.0/SCXStarscream.xcframework.zip",
            checksum: "PLACEHOLDER_CHECKSUM_WILL_BE_REPLACED_BY_GITHUB_ACTIONS"
        ),
        .binaryTarget(
            name: "SCXSocketIO",
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v16.1.0/SCXSocketIO.xcframework.zip",
            checksum: "PLACEHOLDER_CHECKSUM_WILL_BE_REPLACED_BY_GITHUB_ACTIONS"
        )
    ]
)
