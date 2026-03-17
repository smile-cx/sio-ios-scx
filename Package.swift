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
            checksum: "6b8960167aa8039d21ca2d6728bbc873331aacedd58726efbacd6d9a3b12f46f"
        ),
        .binaryTarget(
            name: "SCXSocketIO",
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v15.2.0/SCXSocketIO.xcframework.zip",
            checksum: "25f9ffd5a610877cb0ed3d8948c1fe7339d4f5151eef0a00e698bc9e6aee4e7d"
        ),
    ]
)
