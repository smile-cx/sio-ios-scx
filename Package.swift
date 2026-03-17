// swift-tools-version: 5.9
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
        .library(name: "SCXSocketIO",   targets: ["SCXSocketIO"]),
        .library(name: "SCXStarscream", targets: ["SCXStarscream"]),
    ],
    targets: [
        .binaryTarget(
            name: "SCXStarscream",
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v15.2.0/SCXStarscream.xcframework.zip",
            checksum: "66590bc6e1125696e8f10d322956c1f5199cbe40fa7eb49e72a156b9e4de357a"
        ),
        .binaryTarget(
            name: "SCXSocketIO",
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v15.2.0/SCXSocketIO.xcframework.zip",
            checksum: "2e83caaa02dd3b1e6e4fed0b812ab1ecc461fc7cb8599acb72320df175b6cc31"
        ),
    ]
)
