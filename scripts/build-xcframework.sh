#!/bin/bash
set -euo pipefail

# Build XCFrameworks from prefixed SPM package
# This script builds modified versions of third-party source code.
# See LICENSE and NOTICE files for licensing and attribution information.
# Usage: ./build-xcframework.sh <package_dir> <output_dir> <scheme1> [scheme2 ...]

PACKAGE_DIR="${1:?Usage: $0 <package_dir> <output_dir> <scheme1> [scheme2 ...]}"
OUTPUT_DIR="${2:?Usage: $0 <package_dir> <output_dir> <scheme1> [scheme2 ...]}"
shift 2
SCHEMES=("$@")

if [ ${#SCHEMES[@]} -eq 0 ]; then
    echo "Error: at least one scheme is required"
    exit 1
fi

ARCHIVE_DIR="$OUTPUT_DIR/archives"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR" "$ARCHIVE_DIR"

echo "================================================"
echo "Building XCFrameworks"
echo "Package: $PACKAGE_DIR"
echo "Output:  $OUTPUT_DIR"
echo "Schemes: ${SCHEMES[*]}"
echo "================================================"

for SCHEME in "${SCHEMES[@]}"; do
    echo ""
    echo "--- Building $SCHEME ---"

    IOS_ARCHIVE="$ARCHIVE_DIR/${SCHEME}-iOS.xcarchive"
    SIM_ARCHIVE="$ARCHIVE_DIR/${SCHEME}-Simulator.xcarchive"

    # Build for iOS device
    echo "  Building for iOS..."
    xcodebuild archive \
        -workspace "$PACKAGE_DIR" \
        -scheme "$SCHEME" \
        -destination "generic/platform=iOS" \
        -archivePath "$IOS_ARCHIVE" \
        -configuration Release \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO \
        2>&1 | tail -5

    # Build for iOS Simulator
    echo "  Building for iOS Simulator..."
    xcodebuild archive \
        -workspace "$PACKAGE_DIR" \
        -scheme "$SCHEME" \
        -destination "generic/platform=iOS Simulator" \
        -archivePath "$SIM_ARCHIVE" \
        -configuration Release \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO \
        2>&1 | tail -5

    # Locate frameworks inside archives
    IOS_FW=$(find "$IOS_ARCHIVE" -name "${SCHEME}.framework" -type d | head -1)
    SIM_FW=$(find "$SIM_ARCHIVE" -name "${SCHEME}.framework" -type d | head -1)

    if [ -z "$IOS_FW" ] || [ -z "$SIM_FW" ]; then
        echo "Error: Could not find ${SCHEME}.framework in archives"
        echo "iOS archive contents:"
        find "$IOS_ARCHIVE" -name "*.framework" -type d
        echo "Simulator archive contents:"
        find "$SIM_ARCHIVE" -name "*.framework" -type d
        exit 1
    fi

    echo "  Found iOS framework: $IOS_FW"
    echo "  Found Sim framework: $SIM_FW"

    # Create XCFramework
    echo "  Creating XCFramework..."
    xcodebuild -create-xcframework \
        -framework "$IOS_FW" \
        -framework "$SIM_FW" \
        -output "$OUTPUT_DIR/${SCHEME}.xcframework"

    echo "  ${SCHEME}.xcframework created"
done

echo ""
echo "================================================"
echo "All XCFrameworks built successfully!"
ls -lh "$OUTPUT_DIR"/*.xcframework
echo "================================================"
