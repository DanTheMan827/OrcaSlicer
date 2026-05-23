# iOS CMake Toolchain File
# Used to cross-compile libslic3r and dependencies for iOS (arm64)
#
# Usage:
#   cmake -DCMAKE_TOOLCHAIN_FILE=<path>/ios.toolchain.cmake \
#         -DIOS_PLATFORM=OS \
#         -DCMAKE_OSX_ARCHITECTURES=arm64 \
#         ..

set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# Target iOS platform (OS = device, SIMULATOR64 = simulator)
if(NOT DEFINED IOS_PLATFORM)
    set(IOS_PLATFORM "OS")
endif()

# Minimum iOS deployment target
if(NOT DEFINED CMAKE_OSX_DEPLOYMENT_TARGET)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "16.0" CACHE STRING "Minimum iOS version")
endif()

# Architecture
if(NOT DEFINED CMAKE_OSX_ARCHITECTURES)
    if(IOS_PLATFORM STREQUAL "SIMULATOR64")
        set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "iOS Simulator architectures")
    else()
        set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "iOS device architecture")
    endif()
endif()

# Find the iOS SDK
execute_process(
    COMMAND xcrun --sdk iphoneos --show-sdk-path
    OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)

if(IOS_PLATFORM STREQUAL "SIMULATOR64")
    execute_process(
        COMMAND xcrun --sdk iphonesimulator --show-sdk-path
        OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
endif()

if(NOT CMAKE_OSX_SYSROOT OR CMAKE_OSX_SYSROOT STREQUAL "")
    message(FATAL_ERROR "iOS SDK not found. Ensure Xcode is installed and xcode-select points to a valid Xcode installation.")
endif()

# Compiler settings
set(CMAKE_C_COMPILER_WORKS TRUE)
set(CMAKE_CXX_COMPILER_WORKS TRUE)

# Force static libraries
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build static libraries for iOS" FORCE)

# Position independent code
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Bitcode is deprecated in Xcode 14+, disable it
set(CMAKE_XCODE_ATTRIBUTE_ENABLE_BITCODE "NO")

# Standard library
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")

# Don't search host paths
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Disable GUI-related dependencies that aren't needed for iOS
set(SLIC3R_GUI OFF CACHE BOOL "Disable GUI for iOS static library" FORCE)
set(BUILD_TESTS OFF CACHE BOOL "Disable tests for iOS" FORCE)
set(SLIC3R_BUILD_SANDBOXES OFF CACHE BOOL "Disable sandboxes for iOS" FORCE)
set(ORCA_TOOLS OFF CACHE BOOL "Disable tools for iOS" FORCE)
set(SLIC3R_STATIC ON CACHE BOOL "Build static for iOS" FORCE)

message(STATUS "iOS Toolchain:")
message(STATUS "  Platform: ${IOS_PLATFORM}")
message(STATUS "  SDK: ${CMAKE_OSX_SYSROOT}")
message(STATUS "  Architectures: ${CMAKE_OSX_ARCHITECTURES}")
message(STATUS "  Deployment Target: ${CMAKE_OSX_DEPLOYMENT_TARGET}")
