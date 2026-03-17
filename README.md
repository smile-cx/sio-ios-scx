# SCXSocketIO

Pre-compiled [Socket.IO Client Swift](https://github.com/socketio/socket.io-client-swift) with **SCX** prefix on all symbols to avoid duplicate-symbol conflicts when integrating into apps that may already use Socket.IO or Starscream.

Distributed as **XCFrameworks** via Swift Package Manager binary targets for fast, conflict-free integration.

## Installation

### Swift Package Manager (Recommended)

In Xcode: **File > Add Package Dependencies** and enter:

```
https://github.com/smile-cx/sio-ios-scx
```

Select the desired version and add `SCXSocketIO` (and optionally `SCXStarscream`) to your target.

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/smile-cx/sio-ios-scx", exact: "v16.1.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SCXSocketIO", package: "sio-ios-scx"),
        ]
    )
]
```

### Manual

Download `SCXStarscream.xcframework.zip` and `SCXSocketIO.xcframework.zip` from the [Releases](https://github.com/smile-cx/sio-ios-scx/releases) page, unzip them, and drag both into your Xcode project.

## Usage

```swift
import SCXSocketIO

let manager = SCXSocketManager(socketURL: URL(string: "https://example.com")!)
let socket = manager.defaultSocket

socket.on(clientEvent: .connect) { data, ack in
    print("Connected!")
}

socket.on("message") { data, ack in
    print("Received: \(data)")
}

socket.connect()
```

All public types follow the same API as the original Socket.IO Client Swift, with the `SCX` prefix:

| Original | Prefixed |
|----------|----------|
| `SocketManager` | `SCXSocketManager` |
| `SocketIOClient` | `SCXSocketIOClient` |
| `SocketIOClientOption` | `SCXSocketIOClientOption` |
| `SocketIOStatus` | `SCXSocketIOStatus` |
| `SocketClientEvent` | `SCXSocketClientEvent` |

## What's Included

- **SCXSocketIO.xcframework** -- Prefixed Socket.IO client library
- **SCXStarscream.xcframework** -- Prefixed Starscream WebSocket dependency
- **PrivacyInfo.xcprivacy** embedded in both frameworks
- iOS device (arm64) + Simulator (arm64, x86_64)
- Built with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` for binary compatibility

## Why Prefixed?

If your app (or another SDK you integrate) already includes Socket.IO or Starscream, you'll get duplicate symbol errors at link time. By prefixing all type names with `SCX`, this package can coexist with the original libraries without conflicts.

## Building a New Release

The build is fully automated via GitHub Actions:

1. Go to **Actions > Build and Release Prefixed Socket.IO**
2. Click **Run workflow**
3. Enter the Socket.IO version tag (e.g. `v16.1.0`)
4. The workflow will:
   - Clone Socket.IO and Starscream at the specified versions
   - Prefix all symbols with `SCX`
   - Build XCFrameworks for iOS device + Simulator
   - Update `Package.swift` with binary target URLs and checksums
   - Create a GitHub Release with the artifacts

## Platform Support

- iOS 13+
- macOS 10.15+
- tvOS 13+
- watchOS 6+

## License

This project repackages [socket.io-client-swift](https://github.com/socketio/socket.io-client-swift) (MIT License) and [Starscream](https://github.com/daltoniam/Starscream) (Apache 2.0 License). See the original repositories for license details.
