#!/bin/bash
set -euo pipefail

# Build prefixed Socket.IO XCFrameworks locally
# Usage: ./scripts/build-local.sh <socket-io-version>

readonly VERSION="${1:?Usage: $0 <socket-io-version> (e.g. v15.2.0)}"
readonly PREFIX="SCX"
readonly SOCKETIO_REPO="https://github.com/socketio/socket.io-client-swift.git"
readonly STARSCREAM_REPO="https://github.com/daltoniam/Starscream.git"

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly ROOT_DIR="$(dirname "$SCRIPT_DIR")"
readonly WORK_DIR="$ROOT_DIR/build-local"
readonly BUILD_PKG="$WORK_DIR/build-pkg"
readonly ARCHIVE_DIR="$WORK_DIR/archives"
readonly OUTPUT_DIR="$WORK_DIR/output"
readonly DD="$WORK_DIR/DerivedData"
readonly LOG_DIR="$WORK_DIR/logs"
readonly START_TIME=$(date +%s)

log_error() { echo "ERROR: $*" >&2; }

# Validation
command -v python3 &>/dev/null || { log_error "python3 required"; exit 1; }
command -v xcodebuild &>/dev/null || { log_error "xcodebuild required"; exit 1; }
[ -f "$SCRIPT_DIR/prefix-symbols.py" ] || { log_error "prefix-symbols.py not found"; exit 1; }

echo "Building SCXSocketIO from Socket.IO $VERSION"

# Clean and setup
rm -rf "$WORK_DIR"
mkdir -p "$BUILD_PKG/Sources/${PREFIX}Starscream" "$BUILD_PKG/Sources/${PREFIX}SocketIO"
mkdir -p "$ARCHIVE_DIR" "$OUTPUT_DIR" "$LOG_DIR"

# Clone repositories
clone_repo() {
    local repo_url="$1" dest_dir="$2" version="$3" name="$4"
    if [ -n "$version" ]; then
        git clone --depth 1 --branch "$version" "$repo_url" "$dest_dir" > "$LOG_DIR/git-clone-${name}.log" 2>&1 || \
        git clone --depth 1 "$repo_url" "$dest_dir" >> "$LOG_DIR/git-clone-${name}.log" 2>&1 || \
        { log_error "Failed to clone $name"; return 1; }
    else
        git clone --depth 1 "$repo_url" "$dest_dir" > "$LOG_DIR/git-clone-${name}.log" 2>&1 || \
        { log_error "Failed to clone $name"; return 1; }
    fi
}

clone_repo "$SOCKETIO_REPO" "$WORK_DIR/socketio-source" "$VERSION" "Socket.IO" || exit 1
STAR_VER=$(grep -A5 'Starscream' "$WORK_DIR/socketio-source/Package.swift" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
STAR_VER="${STAR_VER:-4.0.8}"
clone_repo "$STARSCREAM_REPO" "$WORK_DIR/starscream-source" "$STAR_VER" "Starscream" || exit 1

# Assemble sources
for dir in "$WORK_DIR"/starscream-source/Sources/*/; do
    [ -d "$dir" ] && cp -R "$dir"/* "$BUILD_PKG/Sources/${PREFIX}Starscream/" 2>/dev/null || true
done
cp "$WORK_DIR"/starscream-source/Sources/*.swift "$BUILD_PKG/Sources/${PREFIX}Starscream/" 2>/dev/null || true

[ -d "$WORK_DIR/socketio-source/Source/SocketIO" ] || { log_error "SocketIO source directory not found"; exit 1; }
cp -R "$WORK_DIR"/socketio-source/Source/SocketIO/* "$BUILD_PKG/Sources/${PREFIX}SocketIO/"

if [ -f "$ROOT_DIR/Resources/PrivacyInfo.xcprivacy" ]; then
    cp "$ROOT_DIR/Resources/PrivacyInfo.xcprivacy" "$BUILD_PKG/Sources/${PREFIX}Starscream/"
    cp "$ROOT_DIR/Resources/PrivacyInfo.xcprivacy" "$BUILD_PKG/Sources/${PREFIX}SocketIO/"
fi

# Remove duplicate SSLSecurity wrapper
rm -f "$BUILD_PKG/Sources/${PREFIX}SocketIO/Util/SSLSecurity.swift"

# Validate
STARSCREAM_COUNT=$(find "$BUILD_PKG/Sources/${PREFIX}Starscream" -name '*.swift' | wc -l | tr -d ' ')
SOCKETIO_COUNT=$(find "$BUILD_PKG/Sources/${PREFIX}SocketIO" -name '*.swift' | wc -l | tr -d ' ')
[ "$STARSCREAM_COUNT" -eq 0 ] || [ "$SOCKETIO_COUNT" -eq 0 ] && { log_error "No Swift files found"; exit 1; }

# Prefix symbols
python3 "$SCRIPT_DIR/prefix-symbols.py" "$BUILD_PKG/Sources/${PREFIX}Starscream" "$PREFIX" \
    --apply-to "$BUILD_PKG/Sources/${PREFIX}SocketIO" > "$LOG_DIR/prefix-starscream.log" 2>&1 || \
    { log_error "Failed to prefix Starscream types"; exit 1; }

python3 "$SCRIPT_DIR/prefix-symbols.py" "$BUILD_PKG/Sources/${PREFIX}SocketIO" "$PREFIX" > "$LOG_DIR/prefix-socketio.log" 2>&1 || \
    { log_error "Failed to prefix SocketIO types"; exit 1; }

# Restore RFC 6455 WebSocket HTTP header string literals that were incorrectly renamed
# by prefix-symbols.py (e.g. "Sec-SCXWebSocket-Version" → "Sec-WebSocket-Version")
find "$BUILD_PKG/Sources" -name '*.swift' -exec \
    sed -i '' 's/"Sec-SCXWebSocket-/"Sec-WebSocket-/g' {} +

# Fix cross-module references
find "$BUILD_PKG/Sources/${PREFIX}SocketIO" -name '*.swift' -exec \
    sed -i '' "s/import Starscream/import ${PREFIX}Starscream/g" {} +
find "$BUILD_PKG/Sources/${PREFIX}SocketIO" -name '*.swift' -exec \
    sed -i '' "s/Starscream\.\([A-Z]\)/${PREFIX}Starscream.SCX\1/g" {} +
find "$BUILD_PKG/Sources" -name '*.swift' -exec \
    sed -i '' "s/SocketIO\.\([A-Z]\)/${PREFIX}SocketIO.SCX\1/g" {} +

# Add modification notices
python3 "$SCRIPT_DIR/add-modification-notices.py" "$BUILD_PKG/Sources/${PREFIX}Starscream" > "$LOG_DIR/add-notices-starscream.log" 2>&1 || \
    { log_error "Failed to add Starscream modification notices"; exit 1; }

python3 "$SCRIPT_DIR/add-modification-notices.py" "$BUILD_PKG/Sources/${PREFIX}SocketIO" > "$LOG_DIR/add-notices-socketio.log" 2>&1 || \
    { log_error "Failed to add SocketIO modification notices"; exit 1; }

# Merge into single module
cp -R "$BUILD_PKG/Sources/${PREFIX}Starscream"/* "$BUILD_PKG/Sources/${PREFIX}SocketIO/"
find "$BUILD_PKG/Sources/${PREFIX}SocketIO" -name '*.swift' -exec \
    sed -i '' "/^import ${PREFIX}Starscream$/d" {} +
find "$BUILD_PKG/Sources/${PREFIX}SocketIO" -name '*.swift' -exec \
    sed -i '' "s/${PREFIX}Starscream\.//g" {} +
find "$BUILD_PKG/Sources/${PREFIX}SocketIO" -name '*.swift' -exec \
    sed -i '' "s/security?\.security/security/g" {} +

# Generate Package.swift
cat > "$BUILD_PKG/Package.swift" << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let prefix = "SCX"

let package = Package(
    name: "\(prefix)SocketIO",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "\(prefix)SocketIO", type: .dynamic, targets: ["\(prefix)SocketIO"]),
    ],
    targets: [
        .target(
            name: "\(prefix)SocketIO",
            path: "Sources/\(prefix)SocketIO",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
    ]
)
EOF

cd "$BUILD_PKG"
swift package resolve > "$LOG_DIR/swift-package-resolve.log" 2>&1 || { log_error "Package resolution failed"; exit 1; }

# Build XCFramework
"$SCRIPT_DIR/build-xcframework-core.sh" "${PREFIX}SocketIO" "$ARCHIVE_DIR" "$OUTPUT_DIR" "$DD" \
    > "$LOG_DIR/build-xcframework-${PREFIX}SocketIO.log" 2>&1 || {
    log_error "XCFramework build failed"
    tail -50 "$LOG_DIR/build-xcframework-${PREFIX}SocketIO.log" >&2
    exit 1
}

cd ..

# Summary
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo ""
echo "Build complete ($((DURATION / 60))m $((DURATION % 60))s)"
echo ""

ls "$OUTPUT_DIR"/*.xcframework 1>/dev/null 2>&1 || { log_error "No XCFrameworks found"; exit 1; }
ls -lh "$OUTPUT_DIR"/*.xcframework

# Generate checksums
echo ""
cd "$OUTPUT_DIR"
for FW in *.xcframework; do
    [ -d "$FW" ] && zip -r -y -q "${FW%.xcframework}.xcframework.zip" "$FW" 2>/dev/null
done

if ls *.zip 1>/dev/null 2>&1; then
    echo "SHA-256 checksums:"
    shasum -a 256 *.zip | tee "$LOG_DIR/checksums.txt"
fi
