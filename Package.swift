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
            checksum: "14329a887e592c4d79088553c6be47160bf6df997b764bbe38a83a98849d0903"
        ),
        .binaryTarget(
            name: "SCXSocketIO",
            url: "https://github.com/smile-cx/sio-ios-scx/releases/download/v16.1.0/SCXSocketIO.xcframework.zip",
            checksum: "b12131768b20859349ef0decef32bf0b2622d81ce74099657aa4bbbd3510c020"
        ),
    ]
)
