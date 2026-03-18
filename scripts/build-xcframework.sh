#!/bin/bash
set -euo pipefail

# Build XCFrameworks from prefixed SPM package
# This script builds modified versions of third-party source code.
# See LICENSE and NOTICE files for licensing and attribution information.
# Usage: ./build-xcframework.sh <package_dir> <output_dir> <scheme1> [scheme2 ...]

readonly PACKAGE_DIR="${1:?Usage: $0 <package_dir> <output_dir> <scheme1> [scheme2 ...]}"
readonly OUTPUT_DIR="${2:?Usage: $0 <package_dir> <output_dir> <scheme1> [scheme2 ...]}"
shift 2
readonly SCHEMES=("$@")

# Validation
if [ ${#SCHEMES[@]} -eq 0 ]; then
    echo "Error: at least one scheme is required" >&2
    exit 1
fi

if [ ! -e "$PACKAGE_DIR" ]; then
    echo "Error: Package directory not found: $PACKAGE_DIR" >&2
    exit 1
fi

readonly ARCHIVE_DIR="$OUTPUT_DIR/archives"
readonly LOG_DIR="$OUTPUT_DIR/logs"
readonly START_TIME=$(date +%s)

# Clean and setup directories
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR" "$ARCHIVE_DIR" "$LOG_DIR"

echo "Building XCFrameworks: ${SCHEMES[*]}"

# Build archive for a platform
build_archive() {
    local scheme="$1"
    local platform="$2"
    local destination="$3"
    local archive_path="$4"
    local log_file="$LOG_DIR/${scheme}-${platform}.log"

    if xcodebuild archive \
        -workspace "$PACKAGE_DIR" \
        -scheme "$scheme" \
        -destination "$destination" \
        -archivePath "$archive_path" \
        -configuration Release \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO \
        > "$log_file" 2>&1; then
        return 0
    else
        echo "✗ $platform build failed. Log: $log_file" >&2
        tail -20 "$log_file" >&2
        return 1
    fi
}

# Build all schemes
for SCHEME in "${SCHEMES[@]}"; do
    echo ""
    echo "Building $SCHEME..."

    IOS_ARCHIVE="$ARCHIVE_DIR/${SCHEME}-iOS.xcarchive"
    SIM_ARCHIVE="$ARCHIVE_DIR/${SCHEME}-Simulator.xcarchive"

    # Build for both platforms
    build_archive "$SCHEME" "iOS" "generic/platform=iOS" "$IOS_ARCHIVE" || exit 1
    build_archive "$SCHEME" "Simulator" "generic/platform=iOS Simulator" "$SIM_ARCHIVE" || exit 1

    # Locate frameworks inside archives
    IOS_FW=$(find "$IOS_ARCHIVE" -name "${SCHEME}.framework" -type d | head -1)
    SIM_FW=$(find "$SIM_ARCHIVE" -name "${SCHEME}.framework" -type d | head -1)

    if [ -z "$IOS_FW" ] || [ -z "$SIM_FW" ]; then
        echo "✗ Framework not found in archives" >&2
        find "$IOS_ARCHIVE" -name "*.framework" -type d >&2
        find "$SIM_ARCHIVE" -name "*.framework" -type d >&2
        exit 1
    fi

    # Create XCFramework
    if xcodebuild -create-xcframework \
        -framework "$IOS_FW" \
        -framework "$SIM_FW" \
        -output "$OUTPUT_DIR/${SCHEME}.xcframework" \
        > "$LOG_DIR/${SCHEME}-xcframework.log" 2>&1; then
        echo "✓ ${SCHEME}.xcframework"
    else
        echo "✗ XCFramework creation failed. Log: $LOG_DIR/${SCHEME}-xcframework.log" >&2
        exit 1
    fi
done

# Calculate build time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "✓ Build complete (${DURATION}s)"
ls -lh "$OUTPUT_DIR"/*.xcframework 2>/dev/null || echo "No XCFrameworks found"
