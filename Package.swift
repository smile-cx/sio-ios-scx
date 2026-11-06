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
        .library(name: "SCXSocketIO", targets: ["SCXSocketIO"]),
    ],
    targets: [
        .binaryTarget(
            name: "SCXSocketIO",
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v16.1.1/SCXSocketIO.xcframework.zip",
            checksum: "edbac77467c80e3dcdcfc4f325b3e3d7e3f72a68d0d8898b06b78a60e6d78d83"
        ),
    ]
)
