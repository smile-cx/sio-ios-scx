#!/bin/bash

# Build XCFramework for iOS and iOS Simulator
set -e

PREFIX=${PREFIX:-SCX}
BUILD_DIR="build"
DERIVED_DATA="DerivedData"

echo "Building XCFramework with prefix: $PREFIX"

# Clean build directory
rm -rf "$BUILD_DIR"
rm -rf "$DERIVED_DATA"
mkdir -p "$BUILD_DIR"

# Build schemes
SCHEMES=("${PREFIX}SocketIO" "${PREFIX}Starscream")

for SCHEME in "${SCHEMES[@]}"; do
    echo ""
    echo "================================================"
    echo "Building $SCHEME"
    echo "================================================"

    # Build for iOS devices
    echo "Building for iOS devices..."
    xcodebuild archive \
        -scheme "$SCHEME" \
        -archivePath "$BUILD_DIR/$SCHEME-iOS.xcarchive" \
        -sdk iphoneos \
        -destination "generic/platform=iOS" \
        -configuration Release \
        -derivedDataPath "$DERIVED_DATA" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO

    # Build for iOS Simulator
    echo "Building for iOS Simulator..."
    xcodebuild archive \
        -scheme "$SCHEME" \
        -archivePath "$BUILD_DIR/$SCHEME-Simulator.xcarchive" \
        -sdk iphonesimulator \
        -destination "generic/platform=iOS Simulator" \
        -configuration Release \
        -derivedDataPath "$DERIVED_DATA" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO

    # Create XCFramework
    echo "Creating XCFramework..."
    xcodebuild -create-xcframework \
        -archive "$BUILD_DIR/$SCHEME-iOS.xcarchive" -framework "$SCHEME.framework" \
        -archive "$BUILD_DIR/$SCHEME-Simulator.xcarchive" -framework "$SCHEME.framework" \
        -output "$BUILD_DIR/$SCHEME.xcframework"

    echo "$SCHEME.xcframework created successfully"
done

echo ""
echo "================================================"
echo "XCFrameworks built successfully!"
echo "Output directory: $BUILD_DIR"
echo "================================================"

ls -lh "$BUILD_DIR"/*.xcframework
