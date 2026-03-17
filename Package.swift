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
            checksum: "ece341caa30f20820aac1f9f249aac6b9d5e09243b90116bf5e7e3d729a530ee"
        ),
        .binaryTarget(
            name: "SCXSocketIO",
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v15.2.0/SCXSocketIO.xcframework.zip",
            checksum: "a7c1f67dc852ace2bd702a6e44ec5d5c914af32672ed5231f9a12e98b6d29641"
        ),
    ]
)
