#!/bin/bash
set -euo pipefail

# Core XCFramework build logic used by both local builds and GitHub Actions
# Usage: ./build-xcframework-core.sh <scheme> <archive_dir> <output_dir> <derived_data_dir>

readonly SCHEME="${1:?Usage: $0 <scheme> <archive_dir> <output_dir> <derived_data_dir>}"
readonly ARCHIVE_DIR="${2:?}"
readonly OUTPUT_DIR="${3:?}"
readonly DD="${4:?}"

readonly IOS_ARCHIVE="$ARCHIVE_DIR/${SCHEME}-iOS.xcarchive"
readonly SIM_ARCHIVE="$ARCHIVE_DIR/${SCHEME}-Simulator.xcarchive"

echo "Building $SCHEME XCFramework"

# Build for iOS device - use separate DerivedData to avoid module conflicts
xcodebuild archive \
    -scheme "$SCHEME" \
    -destination "generic/platform=iOS" \
    -archivePath "$IOS_ARCHIVE" \
    -derivedDataPath "$DD/iOS" \
    -configuration Release \
    -skipPackagePluginValidation \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO >/dev/null

echo "✓ iOS device archived"

# Build for iOS Simulator - use separate DerivedData to avoid module conflicts
xcodebuild archive \
    -scheme "$SCHEME" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$SIM_ARCHIVE" \
    -derivedDataPath "$DD/Simulator" \
    -configuration Release \
    -skipPackagePluginValidation \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO >/dev/null

echo "✓ iOS Simulator archived"

# Locate frameworks in archives
IOS_FW=$(find "$IOS_ARCHIVE" -name "${SCHEME}.framework" -type d | head -1)
SIM_FW=$(find "$SIM_ARCHIVE" -name "${SCHEME}.framework" -type d | head -1)

if [ -z "$IOS_FW" ] || [ -z "$SIM_FW" ]; then
    echo "ERROR: Framework not found in archives" >&2
    find "$IOS_ARCHIVE" "$SIM_ARCHIVE" -name "*.framework" -type d >&2
    exit 1
fi

# Copy Swift modules from DerivedData into frameworks
SWIFTMOD_IOS=$(find "$DD/iOS/Build/Intermediates.noindex/ArchiveIntermediates" -name "${SCHEME}.swiftmodule" -type d 2>/dev/null | head -1)
[ -n "$SWIFTMOD_IOS" ] || { echo "ERROR: iOS swiftmodule not found" >&2; exit 1; }
mkdir -p "$IOS_FW/Modules"
cp -R "$SWIFTMOD_IOS" "$IOS_FW/Modules/"

SWIFTMOD_SIM=$(find "$DD/Simulator/Build/Intermediates.noindex/ArchiveIntermediates" -name "${SCHEME}.swiftmodule" -type d 2>/dev/null | head -1)
[ -n "$SWIFTMOD_SIM" ] || { echo "ERROR: Simulator swiftmodule not found" >&2; exit 1; }
mkdir -p "$SIM_FW/Modules"
cp -R "$SWIFTMOD_SIM" "$SIM_FW/Modules/"

echo "✓ Swift modules copied"

# Create XCFramework
xcodebuild -create-xcframework \
    -framework "$IOS_FW" \
    -framework "$SIM_FW" \
    -output "$OUTPUT_DIR/${SCHEME}.xcframework" >/dev/null

echo "✓ XCFramework created"

# Verify Swift modules in XCFramework
IOS_MODULES=$(find "$OUTPUT_DIR/${SCHEME}.xcframework/ios-arm64" -name "*.swiftinterface" 2>/dev/null | wc -l | tr -d ' ')
SIM_MODULES=$(find "$OUTPUT_DIR/${SCHEME}.xcframework/ios-arm64_x86_64-simulator" -name "*.swiftinterface" 2>/dev/null | wc -l | tr -d ' ')

if [ "$IOS_MODULES" -gt 0 ] && [ "$SIM_MODULES" -gt 0 ]; then
    echo "✓ Swift modules verified (iOS: $IOS_MODULES, Simulator: $SIM_MODULES)"
else
    echo "ERROR: Swift modules MISSING! (iOS: $IOS_MODULES, Simulator: $SIM_MODULES)" >&2
    exit 1
fi
