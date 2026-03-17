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
    dependencies: [
        // No external dependencies - all code is prefixed and included
    ],
    targets: [
        .target(
            name: "SCXStarscream",
            dependencies: [],
            path: "Sources/SCXStarscream",
            resources: [],
            swiftSettings: [
                .define("STARSCREAM_PREFIXED")
            ]
        ),
        .target(
            name: "SCXSocketIO",
            dependencies: ["SCXStarscream"],
            path: "Sources/SCXSocketIO",
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy")
            ],
            swiftSettings: [
                .define("SOCKETIO_PREFIXED")
            ]
        ),

        // Binary targets for pre-built XCFrameworks (optional, for faster builds)
        // Uncomment and update URLs after first release
        /*
        .binaryTarget(
            name: "SCXSocketIOBinary",
            url: "https://github.com/YOUR_USERNAME/sio-ios-scx/releases/download/v16.1.0/SCXSocketIO-v16.1.0.zip",
            checksum: "REPLACE_WITH_ACTUAL_CHECKSUM"
        ),
        .binaryTarget(
            name: "SCXStarscreamBinary",
            url: "https://github.com/YOUR_USERNAME/sio-ios-scx/releases/download/v16.1.0/SCXStarscream-v16.1.0.zip",
            checksum: "REPLACE_WITH_ACTUAL_CHECKSUM"
        )
        */
    ]
)
