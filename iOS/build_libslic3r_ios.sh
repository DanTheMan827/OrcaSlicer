#!/bin/bash
#
# build_libslic3r_ios.sh
#
# Builds libslic3r as a static library for iOS (arm64) and iOS Simulator (arm64 + x86_64).
# The output is a pair of static libraries that can be combined into an XCFramework.
#
# Prerequisites:
#   - Xcode 15+ with iOS SDK
#   - CMake 3.13+
#   - Ninja (recommended) or Make
#
# Usage:
#   cd iOS
#   ./build_libslic3r_ios.sh [--device|--simulator|--xcframework]
#
# Output:
#   build/device/lib/liblibslic3r.a          - Device static library
#   build/simulator/lib/liblibslic3r.a       - Simulator static library
#   build/OrcaSlicerCore.xcframework         - Universal XCFramework (when --xcframework)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
TOOLCHAIN="$SCRIPT_DIR/cmake/ios.toolchain.cmake"
DEPS_DIR="$BUILD_DIR/deps"

# Number of parallel jobs
NPROC=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)

# Build type
BUILD_TYPE="${BUILD_TYPE:-Release}"

# Determine what to build
BUILD_DEVICE=false
BUILD_SIMULATOR=false
BUILD_XCFRAMEWORK=false

case "${1:-xcframework}" in
    --device)
        BUILD_DEVICE=true
        ;;
    --simulator)
        BUILD_SIMULATOR=true
        ;;
    --xcframework)
        BUILD_DEVICE=true
        BUILD_SIMULATOR=true
        BUILD_XCFRAMEWORK=true
        ;;
    *)
        BUILD_DEVICE=true
        BUILD_SIMULATOR=true
        BUILD_XCFRAMEWORK=true
        ;;
esac

echo "=== OrcaSlicer iOS Build ==="
echo "Root:       $ROOT_DIR"
echo "Build:      $BUILD_DIR"
echo "Toolchain:  $TOOLCHAIN"
echo "Build Type: $BUILD_TYPE"
echo "Jobs:       $NPROC"
echo ""

# -----------------------------------------------------------------
# Build dependencies for iOS
# -----------------------------------------------------------------
build_deps() {
    local PLATFORM=$1  # "OS" or "SIMULATOR64"
    local ARCH=$2      # "arm64" or "arm64;x86_64"
    local DEPS_BUILD_DIR="$DEPS_DIR/$PLATFORM"

    echo ">>> Building dependencies for iOS ($PLATFORM)..."

    mkdir -p "$DEPS_BUILD_DIR"
    cd "$DEPS_BUILD_DIR"

    cmake "$ROOT_DIR/deps" \
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
        -DIOS_PLATFORM="$PLATFORM" \
        -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
        -DDESTDIR="$DEPS_BUILD_DIR/OrcaSlicer_dep" \
        -DDEP_DOWNLOAD_DIR="$DEPS_DIR/DL_CACHE" \
        -G Ninja

    # Build only the dependencies needed for libslic3r (not wxWidgets, GLEW, etc.)
    if command -v ninja &>/dev/null; then
        ninja -j "$NPROC" dep_boost dep_tbb dep_ZLIB dep_EXPAT dep_PNG dep_JPEG dep_OpenSSL \
            dep_Eigen3 dep_CGAL dep_GMP dep_MPFR dep_NLopt dep_Cereal dep_qhull \
            dep_OCCT dep_OpenCV dep_Draco dep_Clipper2 || \
        cmake --build . --config "$BUILD_TYPE" -j "$NPROC"
    else
        cmake --build . --config "$BUILD_TYPE" -j "$NPROC"
    fi

    echo ">>> Dependencies for $PLATFORM built successfully."
}

# -----------------------------------------------------------------
# Build libslic3r for iOS
# -----------------------------------------------------------------
build_libslic3r() {
    local PLATFORM=$1  # "OS" or "SIMULATOR64"
    local ARCH=$2
    local PLATFORM_NAME=$3  # "device" or "simulator"
    local LIBSLIC3R_BUILD_DIR="$BUILD_DIR/$PLATFORM_NAME"
    local DEPS_PREFIX="$DEPS_DIR/$PLATFORM/OrcaSlicer_dep/usr/local"

    echo ">>> Building libslic3r for iOS ($PLATFORM_NAME, $ARCH)..."

    mkdir -p "$LIBSLIC3R_BUILD_DIR"
    cd "$LIBSLIC3R_BUILD_DIR"

    cmake "$ROOT_DIR" \
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
        -DIOS_PLATFORM="$PLATFORM" \
        -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
        -DCMAKE_PREFIX_PATH="$DEPS_PREFIX" \
        -DSLIC3R_GUI=OFF \
        -DSLIC3R_STATIC=ON \
        -DBUILD_TESTS=OFF \
        -DORCA_TOOLS=OFF \
        -DSLIC3R_BUILD_SANDBOXES=OFF \
        -G Ninja

    # Build only libslic3r (not the GUI or executables)
    ninja -j "$NPROC" libslic3r libslic3r_cgal

    echo ">>> libslic3r for $PLATFORM_NAME built successfully."
    echo "    Static lib: $LIBSLIC3R_BUILD_DIR/src/libslic3r/liblibslic3r.a"
}

# -----------------------------------------------------------------
# Create XCFramework
# -----------------------------------------------------------------
create_xcframework() {
    echo ">>> Creating XCFramework..."

    local DEVICE_LIB="$BUILD_DIR/device/src/libslic3r/liblibslic3r.a"
    local DEVICE_CGAL_LIB="$BUILD_DIR/device/src/libslic3r/liblibslic3r_cgal.a"
    local SIMULATOR_LIB="$BUILD_DIR/simulator/src/libslic3r/liblibslic3r.a"
    local SIMULATOR_CGAL_LIB="$BUILD_DIR/simulator/src/libslic3r/liblibslic3r_cgal.a"

    # Merge libslic3r and libslic3r_cgal into a single archive for each platform
    local DEVICE_MERGED="$BUILD_DIR/device/libOrcaSlicerCore.a"
    local SIMULATOR_MERGED="$BUILD_DIR/simulator/libOrcaSlicerCore.a"

    echo "  Merging device libraries..."
    libtool -static -o "$DEVICE_MERGED" "$DEVICE_LIB" "$DEVICE_CGAL_LIB"

    echo "  Merging simulator libraries..."
    libtool -static -o "$SIMULATOR_MERGED" "$SIMULATOR_LIB" "$SIMULATOR_CGAL_LIB"

    # Create header directory with public headers
    local HEADERS_DIR="$BUILD_DIR/include"
    mkdir -p "$HEADERS_DIR"
    cp "$ROOT_DIR/src/libslic3r/libslic3r.h" "$HEADERS_DIR/"
    cp "$ROOT_DIR/src/libslic3r/Print.hpp" "$HEADERS_DIR/"
    cp "$ROOT_DIR/src/libslic3r/PrintConfig.hpp" "$HEADERS_DIR/"
    cp "$ROOT_DIR/src/libslic3r/Model.hpp" "$HEADERS_DIR/"
    cp "$ROOT_DIR/src/libslic3r/GCode.hpp" "$HEADERS_DIR/"

    # Remove old framework if exists
    rm -rf "$BUILD_DIR/OrcaSlicerCore.xcframework"

    # Create XCFramework
    xcodebuild -create-xcframework \
        -library "$DEVICE_MERGED" \
        -headers "$HEADERS_DIR" \
        -library "$SIMULATOR_MERGED" \
        -headers "$HEADERS_DIR" \
        -output "$BUILD_DIR/OrcaSlicerCore.xcframework"

    echo ">>> XCFramework created at: $BUILD_DIR/OrcaSlicerCore.xcframework"
}

# -----------------------------------------------------------------
# Main
# -----------------------------------------------------------------

if $BUILD_DEVICE; then
    build_deps "OS" "arm64"
    build_libslic3r "OS" "arm64" "device"
fi

if $BUILD_SIMULATOR; then
    build_deps "SIMULATOR64" "arm64;x86_64"
    build_libslic3r "SIMULATOR64" "arm64;x86_64" "simulator"
fi

if $BUILD_XCFRAMEWORK; then
    create_xcframework
fi

echo ""
echo "=== Build Complete ==="
echo ""
echo "To use in Xcode:"
echo "  1. Drag OrcaSlicerCore.xcframework into your Xcode project"
echo "  2. Set 'Objective-C Bridging Header' to OrcaSlicer/Bridge/BridgingHeader.h"
echo "  3. Add libslic3r header search path to 'Header Search Paths'"
echo "  4. Link against: libc++, libz, Foundation, ModelIO"
echo ""
