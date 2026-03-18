#!/bin/bash
set -euo pipefail

# Build prefixed Socket.IO XCFrameworks locally
# Usage: ./scripts/build-local.sh <socket-io-version>
# Example: ./scripts/build-local.sh v15.2.0

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

# Colors for output (if terminal supports it)
if [ -t 1 ]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly NC='\033[0m' # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly NC=''
fi

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step() { echo ""; echo "========================================"; echo "$*"; echo "========================================"; }

# Validation
if ! command -v python3 &> /dev/null; then
    log_error "python3 is required but not found"
    exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
    log_error "xcodebuild is required but not found"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/prefix-symbols.py" ]; then
    log_error "prefix-symbols.py not found at: $SCRIPT_DIR/prefix-symbols.py"
    exit 1
fi

if [ ! -f "$ROOT_DIR/Resources/PrivacyInfo.xcprivacy" ]; then
    log_warn "PrivacyInfo.xcprivacy not found at: $ROOT_DIR/Resources/PrivacyInfo.xcprivacy"
fi

echo "Building SCXSocketIO from Socket.IO $VERSION"
echo ""

# Clean
rm -rf "$WORK_DIR"
mkdir -p "$BUILD_PKG/Sources/${PREFIX}Starscream" "$BUILD_PKG/Sources/${PREFIX}SocketIO"
mkdir -p "$ARCHIVE_DIR" "$OUTPUT_DIR" "$LOG_DIR"

# Clone repository with error handling
clone_repo() {
    local repo_url="$1"
    local dest_dir="$2"
    local version="$3"
    local name="$4"

    if [ -n "$version" ]; then
        if git clone --depth 1 --branch "$version" "$repo_url" "$dest_dir" > "$LOG_DIR/git-clone-${name}.log" 2>&1; then
            return 0
        elif git clone --depth 1 "$repo_url" "$dest_dir" >> "$LOG_DIR/git-clone-${name}.log" 2>&1; then
            return 0
        else
            log_error "Failed to clone $name"
            return 1
        fi
    else
        if git clone --depth 1 "$repo_url" "$dest_dir" > "$LOG_DIR/git-clone-${name}.log" 2>&1; then
            return 0
        else
            log_error "Failed to clone $name"
            return 1
        fi
    fi
}

# ── Clone sources ──────────────────────────────────────────────────
echo "Cloning repositories..."
clone_repo "$SOCKETIO_REPO" "$WORK_DIR/socketio-source" "$VERSION" "Socket.IO" || exit 1

# Extract Starscream version from Package.swift
STAR_VER=$(grep -A5 'Starscream' "$WORK_DIR/socketio-source/Package.swift" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
STAR_VER="${STAR_VER:-4.0.8}"

clone_repo "$STARSCREAM_REPO" "$WORK_DIR/starscream-source" "$STAR_VER" "Starscream" || exit 1
echo "✓ Cloned Socket.IO $VERSION and Starscream $STAR_VER"

# ── Assemble sources ───────────────────────────────────────────────
echo ""
echo "Assembling sources..."

# Copy Starscream sources
for dir in "$WORK_DIR"/starscream-source/Sources/*/; do
    [ -d "$dir" ] && cp -R "$dir"/* "$BUILD_PKG/Sources/${PREFIX}Starscream/" 2>/dev/null || true
done
cp "$WORK_DIR"/starscream-source/Sources/*.swift "$BUILD_PKG/Sources/${PREFIX}Starscream/" 2>/dev/null || true

# Copy SocketIO sources
if [ ! -d "$WORK_DIR/socketio-source/Source/SocketIO" ]; then
    log_error "SocketIO source directory not found"
    exit 1
fi
cp -R "$WORK_DIR"/socketio-source/Source/SocketIO/* "$BUILD_PKG/Sources/${PREFIX}SocketIO/"

# Copy privacy manifests
if [ -f "$ROOT_DIR/Resources/PrivacyInfo.xcprivacy" ]; then
    cp "$ROOT_DIR/Resources/PrivacyInfo.xcprivacy" "$BUILD_PKG/Sources/${PREFIX}Starscream/"
    cp "$ROOT_DIR/Resources/PrivacyInfo.xcprivacy" "$BUILD_PKG/Sources/${PREFIX}SocketIO/"
fi

# Count and validate files
STARSCREAM_COUNT=$(find "$BUILD_PKG/Sources/${PREFIX}Starscream" -name '*.swift' | wc -l | tr -d ' ')
SOCKETIO_COUNT=$(find "$BUILD_PKG/Sources/${PREFIX}SocketIO" -name '*.swift' | wc -l | tr -d ' ')

if [ "$STARSCREAM_COUNT" -eq 0 ] || [ "$SOCKETIO_COUNT" -eq 0 ]; then
    log_error "No Swift files found"
    exit 1
fi
echo "✓ Assembled $STARSCREAM_COUNT Starscream + $SOCKETIO_COUNT SocketIO files"

# ── Prefix symbols ─────────────────────────────────────────────────
echo ""
echo "Prefixing symbols..."

if python3 "$SCRIPT_DIR/prefix-symbols.py" "$BUILD_PKG/Sources/${PREFIX}Starscream" "$PREFIX" \
    --apply-to "$BUILD_PKG/Sources/${PREFIX}SocketIO" > "$LOG_DIR/prefix-starscream.log" 2>&1; then
    echo "✓ Starscream types prefixed"
else
    log_error "Failed to prefix Starscream types"
    exit 1
fi

if python3 "$SCRIPT_DIR/prefix-symbols.py" "$BUILD_PKG/Sources/${PREFIX}SocketIO" "$PREFIX" > "$LOG_DIR/prefix-socketio.log" 2>&1; then
    echo "✓ SocketIO types prefixed"
else
    log_error "Failed to prefix SocketIO types"
    exit 1
fi

# Fix cross-module references
find "$BUILD_PKG/Sources/${PREFIX}SocketIO" -name '*.swift' -exec \
    sed -i '' "s/import Starscream/import ${PREFIX}Starscream/g" {} +
find "$BUILD_PKG/Sources/${PREFIX}SocketIO" -name '*.swift' -exec \
    sed -i '' "s/Starscream\.\([A-Z]\)/${PREFIX}Starscream.SCX\1/g" {} +
find "$BUILD_PKG/Sources" -name '*.swift' -exec \
    sed -i '' "s/SocketIO\.\([A-Z]\)/${PREFIX}SocketIO.SCX\1/g" {} +
echo "✓ Cross-module references fixed"

# ── Generate Package.swift ─────────────────────────────────────────
echo ""
echo "Generating Package.swift..."

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
            name: "\(prefix)Starscream",
            path: "Sources/\(prefix)Starscream",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "\(prefix)SocketIO",
            dependencies: [.target(name: "\(prefix)Starscream")],
            path: "Sources/\(prefix)SocketIO",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
    ]
)
EOF

cd "$BUILD_PKG"
if swift package resolve > "$LOG_DIR/swift-package-resolve.log" 2>&1; then
    echo "✓ Package resolved"
else
    log_error "Package resolution failed"
    exit 1
fi

# ── Build XCFrameworks ─────────────────────────────────────────────
build_archive() {
    local scheme="$1"
    local platform="$2"
    local destination="$3"
    local archive_path="$4"
    local log_file="$LOG_DIR/archive-${scheme}-${platform}.log"

    if xcodebuild archive \
        -scheme "$scheme" \
        -destination "$destination" \
        -archivePath "$archive_path" \
        -derivedDataPath "$DD" \
        -configuration Release \
        -skipPackagePluginValidation \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO \
        > "$log_file" 2>&1; then
        return 0
    else
        log_error "$platform build failed. Log: $log_file"
        tail -20 "$log_file" >&2
        return 1
    fi
}

copy_swift_modules() {
    local archive="$1"
    local scheme="$2"

    local fw=$(find "$archive" -name "${scheme}.framework" -type d | head -1)
    [ -z "$fw" ] && return 1

    local swiftmod=$(find "$DD" "$archive" -name "${scheme}.swiftmodule" -type d 2>/dev/null | grep -v "PackageFrameworks" | head -1)
    local header=$(find "$DD" "$archive" -name "${scheme}-Swift.h" -type f 2>/dev/null | head -1)
    local modulemap=$(find "$DD" "$archive" -name "${scheme}.modulemap" -path "*/${scheme}.build/*" -type f 2>/dev/null | head -1)

    [ -n "$swiftmod" ] && mkdir -p "$fw/Modules" && cp -R "$swiftmod" "$fw/Modules/"
    [ -n "$header" ] && mkdir -p "$fw/Headers" && cp "$header" "$fw/Headers/"
    [ -n "$modulemap" ] && mkdir -p "$fw/Modules" && cp "$modulemap" "$fw/Modules/module.modulemap"
}

readonly SCHEMES=("${PREFIX}SocketIO")

for SCHEME in "${SCHEMES[@]}"; do
    echo ""
    echo "Building $SCHEME XCFramework..."

    IOS_ARCHIVE="$ARCHIVE_DIR/${SCHEME}-iOS.xcarchive"
    SIM_ARCHIVE="$ARCHIVE_DIR/${SCHEME}-Simulator.xcarchive"

    # Build archives
    build_archive "$SCHEME" "iOS" "generic/platform=iOS" "$IOS_ARCHIVE" || exit 1
    build_archive "$SCHEME" "Simulator" "generic/platform=iOS Simulator" "$SIM_ARCHIVE" || exit 1

    # Locate frameworks
    IOS_FW=$(find "$IOS_ARCHIVE" -name "${SCHEME}.framework" -type d | head -1)
    SIM_FW=$(find "$SIM_ARCHIVE" -name "${SCHEME}.framework" -type d | head -1)

    if [ -z "$IOS_FW" ] || [ -z "$SIM_FW" ]; then
        log_error "Framework not found in archives"
        exit 1
    fi

    # Copy Swift modules
    copy_swift_modules "$IOS_ARCHIVE" "$SCHEME"
    copy_swift_modules "$SIM_ARCHIVE" "$SCHEME"

    # Create XCFramework
    if xcodebuild -create-xcframework \
        -framework "$IOS_FW" \
        -framework "$SIM_FW" \
        -output "$OUTPUT_DIR/${SCHEME}.xcframework" \
        > "$LOG_DIR/create-xcframework-${SCHEME}.log" 2>&1; then
        echo "✓ ${SCHEME}.xcframework"
    else
        log_error "XCFramework creation failed"
        cat "$LOG_DIR/create-xcframework-${SCHEME}.log" >&2
        exit 1
    fi
done

# ── Summary ────────────────────────────────────────────────────────
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "Build complete (${MINUTES}m ${SECONDS}s)"
echo ""

# List XCFrameworks
if ! ls "$OUTPUT_DIR"/*.xcframework 1> /dev/null 2>&1; then
    log_error "No XCFrameworks found"
    exit 1
fi
ls -lh "$OUTPUT_DIR"/*.xcframework

# Generate checksums
echo ""
cd "$OUTPUT_DIR"
for FW in *.xcframework; do
    [ -d "$FW" ] && zip -r -y -q "${FW%.xcframework}.xcframework.zip" "$FW" 2>/dev/null
done

if ls *.zip 1> /dev/null 2>&1; then
    echo "SHA-256 checksums:"
    shasum -a 256 *.zip | tee "$LOG_DIR/checksums.txt"
fi
