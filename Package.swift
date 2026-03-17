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
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v16.1.0/SCXStarscream.xcframework.zip",
            checksum: "39751fbe86ea6b893ef668e41e9952e29433fbf01e9190578aec63611a7ac2ff"
        ),
        .binaryTarget(
            name: "SCXSocketIO",
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v16.1.0/SCXSocketIO.xcframework.zip",
            checksum: "3a6c39d018a3d72c6dddba7b0d2c0575ed0ab8d1bff7e5ac9540accb5ca88fea"
        ),
    ]
)
