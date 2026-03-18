#!/bin/bash
set -euo pipefail

# Build prefixed Socket.IO XCFrameworks locally
# Usage: ./scripts/build-local.sh <socket-io-version>
# Example: ./scripts/build-local.sh v15.2.0

VERSION="${1:?Usage: $0 <socket-io-version> (e.g. v15.2.0)}"
PREFIX="SCX"
SOCKETIO_REPO="https://github.com/socketio/socket.io-client-swift.git"
STARSCREAM_REPO="https://github.com/daltoniam/Starscream.git"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
WORK_DIR="$ROOT_DIR/build-local"
BUILD_PKG="$WORK_DIR/build-pkg"
ARCHIVE_DIR="$WORK_DIR/archives"
OUTPUT_DIR="$WORK_DIR/output"
DD="$WORK_DIR/DerivedData"

echo "=========================================="
echo "Building SCXSocketIO from Socket.IO $VERSION"
echo "=========================================="

# Clean
rm -rf "$WORK_DIR"
mkdir -p "$BUILD_PKG/Sources/${PREFIX}Starscream" "$BUILD_PKG/Sources/${PREFIX}SocketIO"
mkdir -p "$ARCHIVE_DIR" "$OUTPUT_DIR"

# ── Clone sources ──────────────────────────────────────────────────
echo "Cloning Socket.IO $VERSION..."
git clone --depth 1 --branch "$VERSION" "$SOCKETIO_REPO" "$WORK_DIR/socketio-source"

STAR_VER=$(grep -A5 'Starscream' "$WORK_DIR/socketio-source/Package.swift" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
STAR_VER="${STAR_VER:-4.0.8}"
echo "Cloning Starscream $STAR_VER..."
git clone --depth 1 --branch "$STAR_VER" "$STARSCREAM_REPO" "$WORK_DIR/starscream-source" \
  || git clone --depth 1 "$STARSCREAM_REPO" "$WORK_DIR/starscream-source"

# ── Assemble sources ───────────────────────────────────────────────
echo "Assembling sources..."
for dir in "$WORK_DIR"/starscream-source/Sources/*/; do
  cp -R "$dir"/* "$BUILD_PKG/Sources/${PREFIX}Starscream/" 2>/dev/null || true
done
cp "$WORK_DIR"/starscream-source/Sources/*.swift "$BUILD_PKG/Sources/${PREFIX}Starscream/" 2>/dev/null || true

cp -R "$WORK_DIR"/socketio-source/Source/SocketIO/* "$BUILD_PKG/Sources/${PREFIX}SocketIO/"

cp "$ROOT_DIR/Resources/PrivacyInfo.xcprivacy" "$BUILD_PKG/Sources/${PREFIX}Starscream/"
cp "$ROOT_DIR/Resources/PrivacyInfo.xcprivacy" "$BUILD_PKG/Sources/${PREFIX}SocketIO/"

echo "  Starscream files: $(find "$BUILD_PKG/Sources/${PREFIX}Starscream" -name '*.swift' | wc -l)"
echo "  SocketIO files:   $(find "$BUILD_PKG/Sources/${PREFIX}SocketIO" -name '*.swift' | wc -l)"

# ── Step 1: Prefix Starscream types in Starscream AND SocketIO ─────
echo ""
echo "Step 1: Prefixing Starscream types (in both libraries)..."
python3 "$SCRIPT_DIR/prefix-symbols.py" "$BUILD_PKG/Sources/${PREFIX}Starscream" "$PREFIX" \
  --apply-to "$BUILD_PKG/Sources/${PREFIX}SocketIO"

# ── Step 2: Prefix SocketIO's own types ────────────────────────────
echo ""
echo "Step 2: Prefixing SocketIO types..."
python3 "$SCRIPT_DIR/prefix-symbols.py" "$BUILD_PKG/Sources/${PREFIX}SocketIO" "$PREFIX"

# ── Step 3: Fix cross-module references ────────────────────────────
echo ""
echo "Step 3: Fixing cross-module references..."
find "$BUILD_PKG/Sources/${PREFIX}SocketIO" -name '*.swift' -exec \
  sed -i '' "s/import Starscream/import ${PREFIX}Starscream/g" {} +

find "$BUILD_PKG/Sources/${PREFIX}SocketIO" -name '*.swift' -exec \
  sed -i '' "s/Starscream\.\([A-Z]\)/${PREFIX}Starscream.SCX\1/g" {} +

find "$BUILD_PKG/Sources" -name '*.swift' -exec \
  sed -i '' "s/SocketIO\.\([A-Z]\)/${PREFIX}SocketIO.SCX\1/g" {} +

# ── Generate Package.swift ─────────────────────────────────────────
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
        .library(name: "\(prefix)Starscream", type: .dynamic, targets: ["\(prefix)Starscream"]),
        .library(name: "\(prefix)SocketIO",   type: .dynamic, targets: ["\(prefix)SocketIO"]),
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

echo ""
echo "Resolving package..."
cd "$BUILD_PKG"
swift package resolve

# ── Build XCFrameworks ─────────────────────────────────────────────
SCHEMES=("${PREFIX}Starscream" "${PREFIX}SocketIO")

for SCHEME in "${SCHEMES[@]}"; do
  echo ""
  echo "=========================================="
  echo "Building $SCHEME"
  echo "=========================================="

  IOS_ARCHIVE="$ARCHIVE_DIR/${SCHEME}-iOS.xcarchive"
  SIM_ARCHIVE="$ARCHIVE_DIR/${SCHEME}-Simulator.xcarchive"

  echo "  Archiving for iOS device..."
  xcodebuild archive \
    -scheme "$SCHEME" \
    -destination "generic/platform=iOS" \
    -archivePath "$IOS_ARCHIVE" \
    -derivedDataPath "$DD" \
    -configuration Release \
    -skipPackagePluginValidation \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO \
    2>&1 | tail -3

  echo "  Archiving for iOS Simulator..."
  xcodebuild archive \
    -scheme "$SCHEME" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$SIM_ARCHIVE" \
    -derivedDataPath "$DD" \
    -configuration Release \
    -skipPackagePluginValidation \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO \
    2>&1 | tail -3

  IOS_FW=$(find "$IOS_ARCHIVE" -name "${SCHEME}.framework" -type d | head -1)
  SIM_FW=$(find "$SIM_ARCHIVE" -name "${SCHEME}.framework" -type d | head -1)

  if [ -z "$IOS_FW" ] || [ -z "$SIM_FW" ]; then
    echo "  ERROR: framework not found!"
    exit 1
  fi

  # Copy Swift modules into frameworks
  for ARCHIVE in "$IOS_ARCHIVE" "$SIM_ARCHIVE"; do
    FW=$(find "$ARCHIVE" -name "${SCHEME}.framework" -type d | head -1)
    [ -z "$FW" ] && continue

    SWIFTMOD=$(find "$DD" "$ARCHIVE" -name "${SCHEME}.swiftmodule" -type d 2>/dev/null | grep -v "PackageFrameworks" | head -1)
    HEADER=$(find "$DD" "$ARCHIVE" -name "${SCHEME}-Swift.h" -type f 2>/dev/null | head -1)
    MODULEMAP=$(find "$DD" "$ARCHIVE" -name "${SCHEME}.modulemap" -path "*/${SCHEME}.build/*" -type f 2>/dev/null | head -1)

    [ -n "$SWIFTMOD" ] && mkdir -p "$FW/Modules" && cp -R "$SWIFTMOD" "$FW/Modules/"
    [ -n "$HEADER" ] && mkdir -p "$FW/Headers" && cp "$HEADER" "$FW/Headers/"
    [ -n "$MODULEMAP" ] && mkdir -p "$FW/Modules" && cp "$MODULEMAP" "$FW/Modules/module.modulemap"
  done

  xcodebuild -create-xcframework \
    -framework "$IOS_FW" \
    -framework "$SIM_FW" \
    -output "$OUTPUT_DIR/${SCHEME}.xcframework"

  echo "  ${SCHEME}.xcframework created"

  # Verify modules
  if find "$OUTPUT_DIR/${SCHEME}.xcframework" -name "*.swiftmodule" -type d | grep -q .; then
    echo "  Modules: OK"
  else
    echo "  WARNING: Modules missing!"
  fi
done

# ── Summary ────────────────────────────────────────────────────────
echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="
echo "Output: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"/*.xcframework
echo ""
echo "Checksums:"
cd "$OUTPUT_DIR"
for FW in *.xcframework; do
  zip -r -y -q "${FW%.xcframework}.xcframework.zip" "$FW"
done
shasum -a 256 *.zip
