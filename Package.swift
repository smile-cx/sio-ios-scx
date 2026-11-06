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
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v16.1.2/SCXSocketIO.xcframework.zip",
            checksum: "91763c7a14b282b79d95b43d09aea78807f057c4bb9dd5a0965113c8459e0d6e"
        ),
    ]
)
