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
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v15.2.0/SCXSocketIO.xcframework.zip",
            checksum: "56769af56dbc926d08c696ada4f6df8b5202de4d375e63965e3bc3198659ecc1"
        ),
    ]
)
