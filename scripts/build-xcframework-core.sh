#!/bin/bash
set -euo pipefail

# Core XCFramework build logic used by both local builds and GitHub Actions
# Usage: ./build-xcframework-core.sh <scheme> <archive_dir> <output_dir> <derived_data_dir>

readonly SCHEME="${1:?Usage: $0 <scheme> <archive_dir> <output_dir> <derived_data_dir>}"
readonly ARCHIVE_DIR="${2:?}"
readonly OUTPUT_DIR="${3:?}"
readonly DD="${4:?}"

# name|xcodebuild destination
readonly SLICES=(
    "iOS|generic/platform=iOS"
    "iOS-Simulator|generic/platform=iOS Simulator"
    "watchOS|generic/platform=watchOS"
    "watchOS-Simulator|generic/platform=watchOS Simulator"
)

echo "Building $SCHEME XCFramework"

FRAMEWORK_ARGS=()

for SLICE in "${SLICES[@]}"; do
    IFS='|' read -r NAME DESTINATION <<< "$SLICE"
    ARCHIVE="$ARCHIVE_DIR/${SCHEME}-${NAME}.xcarchive"

    # Separate DerivedData per platform to avoid module conflicts
    xcodebuild archive \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -archivePath "$ARCHIVE" \
        -derivedDataPath "$DD/$NAME" \
        -configuration Release \
        -skipPackagePluginValidation \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO >/dev/null

    echo "✓ $NAME archived"

    FW=$(find "$ARCHIVE" -name "${SCHEME}.framework" -type d | head -1)
    if [ -z "$FW" ]; then
        echo "ERROR: Framework not found in $NAME archive" >&2
        find "$ARCHIVE" -name "*.framework" -type d >&2
        exit 1
    fi

    # Copy Swift module from DerivedData into framework
    SWIFTMOD=$(find "$DD/$NAME/Build/Intermediates.noindex/ArchiveIntermediates" -name "${SCHEME}.swiftmodule" -type d 2>/dev/null | head -1)
    [ -n "$SWIFTMOD" ] || { echo "ERROR: $NAME swiftmodule not found" >&2; exit 1; }
    mkdir -p "$FW/Modules"
    cp -R "$SWIFTMOD" "$FW/Modules/"

    FRAMEWORK_ARGS+=(-framework "$FW")
done

echo "✓ Swift modules copied"

# Create XCFramework
xcodebuild -create-xcframework \
    "${FRAMEWORK_ARGS[@]}" \
    -output "$OUTPUT_DIR/${SCHEME}.xcframework" >/dev/null

echo "✓ XCFramework created"

# Verify every XCFramework slice is present and carries Swift modules
XCFW="$OUTPUT_DIR/${SCHEME}.xcframework"
SLICE_COUNT=0
for SLICE_DIR in "$XCFW"/*/; do
    SLICE_DIR="${SLICE_DIR%/}"
    SLICE_COUNT=$((SLICE_COUNT + 1))
    MODULES=$(find "$SLICE_DIR" -name "*.swiftinterface" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$MODULES" -gt 0 ]; then
        echo "✓ Swift modules verified ($(basename "$SLICE_DIR"): $MODULES)"
    else
        echo "ERROR: Swift modules MISSING in $(basename "$SLICE_DIR")" >&2
        exit 1
    fi
done

if [ "$SLICE_COUNT" -ne "${#SLICES[@]}" ]; then
    echo "ERROR: expected ${#SLICES[@]} slices, found $SLICE_COUNT" >&2
    ls "$XCFW" >&2
    exit 1
fi
