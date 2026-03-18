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

echo ""
echo "=========================================="
echo "Building $SCHEME XCFramework"
echo "=========================================="

# Build for iOS device - use separate DerivedData to avoid module conflicts
echo "Archiving for iOS device..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -destination "generic/platform=iOS" \
    -archivePath "$IOS_ARCHIVE" \
    -derivedDataPath "$DD/iOS" \
    -configuration Release \
    -skipPackagePluginValidation \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO

echo "✓ iOS device archive complete"

# Build for iOS Simulator - use separate DerivedData to avoid module conflicts
echo "Archiving for iOS Simulator..."
xcodebuild archive \
    -scheme "$SCHEME" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$SIM_ARCHIVE" \
    -derivedDataPath "$DD/Simulator" \
    -configuration Release \
    -skipPackagePluginValidation \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO

echo "✓ iOS Simulator archive complete"

# Locate frameworks in archives
IOS_FW=$(find "$IOS_ARCHIVE" -name "${SCHEME}.framework" -type d | head -1)
SIM_FW=$(find "$SIM_ARCHIVE" -name "${SCHEME}.framework" -type d | head -1)

if [ -z "$IOS_FW" ] || [ -z "$SIM_FW" ]; then
    echo "ERROR: Framework not found in archives" >&2
    echo "iOS archive:" >&2
    find "$IOS_ARCHIVE" -name "*.framework" -type d >&2
    echo "Simulator archive:" >&2
    find "$SIM_ARCHIVE" -name "*.framework" -type d >&2
    exit 1
fi

echo "Found frameworks:"
echo "  iOS: $IOS_FW"
echo "  Simulator: $SIM_FW"

# Copy Swift modules from DerivedData into frameworks
echo ""
echo "Copying Swift modules..."

# iOS device modules
SWIFTMOD_IOS=$(find "$DD/iOS/Build/Intermediates.noindex/ArchiveIntermediates" -name "${SCHEME}.swiftmodule" -type d 2>/dev/null | head -1)
if [ -n "$SWIFTMOD_IOS" ]; then
    mkdir -p "$IOS_FW/Modules"
    cp -R "$SWIFTMOD_IOS" "$IOS_FW/Modules/"
    MODULE_COUNT=$(ls "$SWIFTMOD_IOS" 2>/dev/null | wc -l | tr -d ' ')
    echo "  ✓ iOS modules copied ($MODULE_COUNT files)"
else
    echo "  ✗ ERROR: iOS swiftmodule not found in $DD/iOS" >&2
    exit 1
fi

# Simulator modules
SWIFTMOD_SIM=$(find "$DD/Simulator/Build/Intermediates.noindex/ArchiveIntermediates" -name "${SCHEME}.swiftmodule" -type d 2>/dev/null | head -1)
if [ -n "$SWIFTMOD_SIM" ]; then
    mkdir -p "$SIM_FW/Modules"
    cp -R "$SWIFTMOD_SIM" "$SIM_FW/Modules/"
    MODULE_COUNT=$(ls "$SWIFTMOD_SIM" 2>/dev/null | wc -l | tr -d ' ')
    echo "  ✓ Simulator modules copied ($MODULE_COUNT files)"
else
    echo "  ✗ ERROR: Simulator swiftmodule not found in $DD/Simulator" >&2
    exit 1
fi

# Create XCFramework
echo ""
echo "Creating XCFramework..."
xcodebuild -create-xcframework \
    -framework "$IOS_FW" \
    -framework "$SIM_FW" \
    -output "$OUTPUT_DIR/${SCHEME}.xcframework"

echo "✓ ${SCHEME}.xcframework created"

# Verify Swift modules in XCFramework
echo ""
echo "Verifying Swift modules in XCFramework..."
IOS_MODULES=$(find "$OUTPUT_DIR/${SCHEME}.xcframework/ios-arm64" -name "*.swiftinterface" 2>/dev/null | wc -l | tr -d ' ')
SIM_MODULES=$(find "$OUTPUT_DIR/${SCHEME}.xcframework/ios-arm64_x86_64-simulator" -name "*.swiftinterface" 2>/dev/null | wc -l | tr -d ' ')

if [ "$IOS_MODULES" -gt 0 ] && [ "$SIM_MODULES" -gt 0 ]; then
    echo "  ✓ iOS device modules: $IOS_MODULES files"
    echo "  ✓ Simulator modules: $SIM_MODULES files"

    # Show samples
    echo ""
    echo "Sample iOS module files:"
    find "$OUTPUT_DIR/${SCHEME}.xcframework/ios-arm64" -name "*.swiftinterface" 2>/dev/null | head -2
    echo ""
    echo "Sample Simulator module files:"
    find "$OUTPUT_DIR/${SCHEME}.xcframework/ios-arm64_x86_64-simulator" -name "*.swiftinterface" 2>/dev/null | head -2
else
    echo "  ✗ ERROR: Swift modules MISSING from XCFramework!" >&2
    echo "    iOS modules found: $IOS_MODULES" >&2
    echo "    Simulator modules found: $SIM_MODULES" >&2
    exit 1
fi

echo ""
echo "✓ ${SCHEME}.xcframework build complete"
