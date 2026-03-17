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
            checksum: "3bfa3a14c3eb1eae1a41c505edb294d63ada2baec6fe8fff21384c034661bb77"
        ),
        .binaryTarget(
            name: "SCXSocketIO",
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v15.2.0/SCXSocketIO.xcframework.zip",
            checksum: "faf747d20973c136df1e2a94e8b5102136395f918361b8281356ea4f4e2174dd"
        ),
    ]
)
