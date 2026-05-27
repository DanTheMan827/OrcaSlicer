# iOS-specific dependencies build for libslic3r only (no GUI deps).
# This is a thin wrapper that sets up the environment and then includes
# only the dependency modules that libslic3r needs, skipping GLEW, GLFW,
# OpenCSG, and wxWidgets which require OpenGL (not available on iOS).
#
# Usage:
#   cmake <path-to-this-dir> \
#     -G Ninja \
#     -DCMAKE_TOOLCHAIN_FILE=<path>/ios.toolchain.cmake \
#     -DCMAKE_OSX_ARCHITECTURES=arm64 \
#     -DCMAKE_BUILD_TYPE=Release \
#     -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
#     -DDESTDIR=<output-path>
#   cmake --build . --target deps

if(${CMAKE_VERSION} VERSION_GREATER_EQUAL "4.0")
    set(CMAKE_POLICY_VERSION_MINIMUM 3.5 CACHE STRING "" FORCE)
endif()

cmake_minimum_required(VERSION 3.2)

if (NOT CMAKE_OSX_DEPLOYMENT_TARGET)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "16.0" CACHE STRING "Minimum iOS deployment version" FORCE)
endif()

if(POLICY CMP0135)
    cmake_policy(SET CMP0135 NEW)
endif()

project(OrcaSlicer-iOS-deps)

include(ExternalProject)
include(ProcessorCount)

ProcessorCount(NPROC)
if (NPROC EQUAL 0)
    set(NPROC 1)
endif()

# Point to the main deps directory for source modules
set(DEPS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../deps")

set(DEP_DOWNLOAD_DIR ${DEPS_DIR}/DL_CACHE CACHE PATH "Path for downloaded source packages.")

if ("${DESTDIR}" STREQUAL "")
    set(DESTDIR "${CMAKE_BINARY_DIR}/OrcaSlicer_dep" CACHE PATH "Path to dependencies install directory" FORCE)
endif()

# Append /usr/local so the layout matches the main deps build and the
# workflow's DEPS_PREFIX (which points to OrcaSlicer_dep/usr/local).
set(DESTDIR "${DESTDIR}/usr/local")

message(STATUS "iOS deps DESTDIR: ${DESTDIR}")
message(STATUS "iOS deps prefix: ${DESTDIR}")

# --- Platform setup (mirroring main deps/CMakeLists.txt) ---

set(IS_CROSS_COMPILE TRUE)

list(LENGTH CMAKE_OSX_ARCHITECTURES _arch_len)
if(NOT CMAKE_OSX_ARCHITECTURES)
    set(CMAKE_OSX_ARCHITECTURES "arm64")
endif()

set(CMAKE_FIND_FRAMEWORK LAST)
set(CMAKE_FIND_APPBUNDLE LAST)
set(CMAKE_CXX_COMPILER_ID "Clang")
string(REPLACE ";" "$<SEMICOLON>" CMAKE_OSX_ARCHS "${CMAKE_OSX_ARCHITECTURES}")
set(_cmake_osx_arch -DCMAKE_OSX_ARCHITECTURES:STRING=${CMAKE_OSX_ARCHS})
set(_cmake_args_osx_arch CMAKE_ARGS -DCMAKE_OSX_ARCHITECTURES:STRING=${CMAKE_OSX_ARCHS})

# DEP_OSX_TARGET setup
if (CMAKE_OSX_DEPLOYMENT_TARGET)
    set(DEP_OSX_TARGET "${CMAKE_OSX_DEPLOYMENT_TARGET}")
else()
    set(DEP_OSX_TARGET "16.0")
endif()
message(STATUS "iOS Deployment Target: ${DEP_OSX_TARGET}")

# Include platform-specific cmake opts from deps-macos.cmake
# For iOS, we use -target arm64-apple-ios16.0 instead of -mmacosx-version-min
set(DEP_WERRORS_SDK "")
set(IOS_TARGET_FLAG "-target arm64-apple-ios${DEP_OSX_TARGET}")
set(IOS_SYSROOT_FLAG "-isysroot ${CMAKE_OSX_SYSROOT}")
set(DEP_CMAKE_OPTS
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    "-DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT}"
    "-DCMAKE_OSX_DEPLOYMENT_TARGET=${DEP_OSX_TARGET}"
    "-DCMAKE_SYSTEM_NAME=iOS"
    "-DCMAKE_CXX_FLAGS=${IOS_TARGET_FLAG} ${IOS_SYSROOT_FLAG}"
    "-DCMAKE_C_FLAGS=${IOS_TARGET_FLAG} ${IOS_SYSROOT_FLAG}"
    "-DCMAKE_FIND_FRAMEWORK=LAST"
    "-DCMAKE_FIND_APPBUNDLE=LAST"
    # Prevent executables from being treated as macOS/iOS bundles.
    # When CMAKE_SYSTEM_NAME=iOS CMake defaults MACOSX_BUNDLE to ON for
    # executables, but most dep install() commands omit BUNDLE DESTINATION
    # which causes a configure-time error.
    "-DCMAKE_MACOSX_BUNDLE=OFF"
)

find_package(Git REQUIRED)
set(PATCH_CMD ${GIT_EXECUTABLE} apply --verbose --ignore-space-change --whitespace=fix)

# iOS deps build in a nested out-of-tree directory where repo-relative
# git apply --directory=<path> patch flags are not valid. Force dependency
# modules to use plain git apply patch commands.
set(IN_GIT_REPO FALSE)

if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Mark as cross-compiling for deps that check this
set(CMAKE_CROSSCOMPILING TRUE)
# For autotools-based deps (GMP, MPFR) that use --host
set(TOOLCHAIN_PREFIX "aarch64-apple-ios")

# Override linker flags to include sysroot for all builds
set(CMAKE_EXE_LINKER_FLAGS "${IOS_TARGET_FLAG} ${IOS_SYSROOT_FLAG}")

# --- orcaslicer_add_cmake_project function (from main deps/CMakeLists.txt) ---
# Simplified for iOS cross-compilation (always cross-compile path)

function(orcaslicer_add_cmake_project projectname)
    cmake_parse_arguments(P_ARGS "" "INSTALL_DIR;BUILD_COMMAND;INSTALL_COMMAND" "CMAKE_ARGS" ${ARGN})

    set(_configs_line -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE})

    if ($ENV{CMAKE_BUILD_PARALLEL_LEVEL})
        set(_build_j "")
    else()
        set(_build_j "-j${NPROC}")
    endif()

    ExternalProject_Add(
        dep_${projectname}
        EXCLUDE_FROM_ALL    ON
        INSTALL_DIR         ${DESTDIR}
        DOWNLOAD_DIR        ${DEP_DOWNLOAD_DIR}/${projectname}
        CMAKE_ARGS
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5
            -DCMAKE_INSTALL_PREFIX:STRING=${DESTDIR}
            -DCMAKE_PREFIX_PATH:STRING=${DESTDIR}
            -DCMAKE_IGNORE_PREFIX_PATH:STRING=${CMAKE_IGNORE_PREFIX_PATH}
            -DCMAKE_C_COMPILER:STRING=${CMAKE_C_COMPILER}
            -DCMAKE_CXX_COMPILER:STRING=${CMAKE_CXX_COMPILER}
            -DCMAKE_TOOLCHAIN_FILE:STRING=${CMAKE_TOOLCHAIN_FILE}
            -DBUILD_SHARED_LIBS:BOOL=OFF
            ${_cmake_osx_arch}
            "${_configs_line}"
            ${DEP_CMAKE_OPTS}
            ${P_ARGS_CMAKE_ARGS}
        ${P_ARGS_UNPARSED_ARGUMENTS}
        BUILD_COMMAND ${CMAKE_COMMAND} --build . --config Release -- ${_build_j}
        INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install --config Release
    )
endfunction(orcaslicer_add_cmake_project)

# --- Macro for debug deps (no-op on iOS) ---
macro(add_debug_dep _dep)
endmacro()

# --- Include dependency modules ---

# ZLIB, PNG, EXPAT - check system first
set(ZLIB_PKG "")
find_package(ZLIB QUIET)
if (NOT ZLIB_FOUND)
    include("${DEPS_DIR}/ZLIB/ZLIB.cmake")
    set(ZLIB_PKG "dep_ZLIB")
endif()

set(PNG_PKG "")
find_package(PNG QUIET)
if (NOT PNG_FOUND)
    include("${DEPS_DIR}/PNG/PNG.cmake")
    set(PNG_PKG "dep_PNG")
endif()

set(EXPAT_PKG "")
find_package(EXPAT QUIET)
if (NOT EXPAT_FOUND)
    include("${DEPS_DIR}/EXPAT/EXPAT.cmake")
    set(EXPAT_PKG "dep_EXPAT")
endif()

# Core dependencies needed by libslic3r
set(DEP_Boost_COMPONENTS system iostreams filesystem thread log locale regex date_time)
include("${DEPS_DIR}/Boost/Boost.cmake")

include("${DEPS_DIR}/Cereal/Cereal.cmake")
include("${DEPS_DIR}/Qhull/Qhull.cmake")

# Skip GLEW - requires OpenGL (not available on iOS)
# Skip GLFW - requires OpenGL (not available on iOS)
# Skip OpenCSG - requires OpenGL (not available on iOS)

include("${DEPS_DIR}/TBB/TBB.cmake")

include("${DEPS_DIR}/Blosc/Blosc.cmake")
include("${DEPS_DIR}/OpenEXR/OpenEXR.cmake")
include("${DEPS_DIR}/OpenVDB/OpenVDB.cmake")

include("${DEPS_DIR}/GMP/GMP.cmake")
include("${DEPS_DIR}/MPFR/MPFR.cmake")
include("${DEPS_DIR}/Eigen/Eigen.cmake")
include("${DEPS_DIR}/CGAL/CGAL.cmake")

include("${DEPS_DIR}/NLopt/NLopt.cmake")
include("${DEPS_DIR}/libnoise/libnoise.cmake")

include("${DEPS_DIR}/Draco/Draco.cmake")

# OpenSSL
set(OPENSSL_PKG "")
if(NOT OPENSSL_FOUND)
    include("${DEPS_DIR}/OpenSSL/OpenSSL.cmake")
    set(OPENSSL_PKG dep_OpenSSL)
endif()

# CURL
set(CURL_PKG "")
if (NOT OPENSSL_FOUND OR NOT CURL_FOUND)
    include("${DEPS_DIR}/CURL/CURL.cmake")
    set(CURL_PKG dep_CURL)
endif()

# JPEG
set(JPEG_PKG "")
if (NOT JPEG_FOUND)
    include("${DEPS_DIR}/JPEG/JPEG.cmake")
    set(JPEG_PKG dep_JPEG)
endif()

# Skip wxWidgets - GUI dependency, not needed for iOS

# FREETYPE (needed by OCCT)
set(FREETYPE_PKG "")
if(NOT FREETYPE_FOUND)
    include("${DEPS_DIR}/FREETYPE/FREETYPE.cmake")
    set(FREETYPE_PKG "dep_FREETYPE")
endif()

include("${DEPS_DIR}/OCCT/OCCT.cmake")
include("${DEPS_DIR}/OpenCV/OpenCV.cmake")

# iOS deps target - only what libslic3r needs (no GUI deps)
set(_dep_list
    dep_Boost
    dep_TBB
    ${OPENSSL_PKG}
    ${CURL_PKG}
    dep_Cereal
    dep_Draco
    dep_NLopt
    dep_OpenVDB
    dep_OpenCV
    dep_Eigen
    dep_CGAL
    dep_OCCT
    ${FREETYPE_PKG}
    ${JPEG_PKG}
    ${PNG_PKG}
    ${ZLIB_PKG}
    ${EXPAT_PKG}
    dep_libnoise
    dep_Qhull
)

add_custom_target(deps ALL DEPENDS ${_dep_list})
