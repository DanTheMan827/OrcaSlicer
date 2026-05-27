#
# CMakeLists.txt for the OrcaSlicer iOS target
#
# This CMake file builds just the iOS app target, linking against
# a pre-built libslic3r static library (built via build_libslic3r_ios.sh).
#
# Usage:
#   # First, build libslic3r for iOS:
#   cd iOS && ./build_libslic3r_ios.sh
#
#   # Then generate the Xcode project:
#   mkdir xcode_build && cd xcode_build
#   cmake .. -G Xcode \
#       -DCMAKE_SYSTEM_NAME=iOS \
#       -DCMAKE_OSX_DEPLOYMENT_TARGET=18.0 \
#       -DLIBSLIC3R_ROOT=../build/device
#

cmake_minimum_required(VERSION 3.21)

project(OrcaSlicerIOS LANGUAGES C CXX Swift OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_Swift_LANGUAGE_VERSION 5.9)

# iOS deployment target
set(CMAKE_OSX_DEPLOYMENT_TARGET "18.0" CACHE STRING "Minimum iOS deployment target")
set(CMAKE_XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "18.0")

# Paths to pre-built libslic3r
if(NOT DEFINED LIBSLIC3R_ROOT)
    set(LIBSLIC3R_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/build/device" CACHE PATH "Path to libslic3r build directory")
endif()

# The root OrcaSlicer source (for headers)
set(ORCASLICER_SRC_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../src")

# Dependencies prefix (from build_libslic3r_ios.sh)
if(NOT DEFINED DEPS_PREFIX)
    set(DEPS_PREFIX "${CMAKE_CURRENT_SOURCE_DIR}/build/deps/OS/OrcaSlicer_dep/usr/local" CACHE PATH "Path to deps prefix")
endif()

# --- Find pre-built libslic3r ---

find_library(LIBSLIC3R_LIBRARY
    NAMES libslic3r
    PATHS "${LIBSLIC3R_ROOT}/src/libslic3r"
    NO_DEFAULT_PATH
)

find_library(LIBSLIC3R_CGAL_LIBRARY
    NAMES libslic3r_cgal
    PATHS "${LIBSLIC3R_ROOT}/src/libslic3r"
    NO_DEFAULT_PATH
)

if(NOT LIBSLIC3R_LIBRARY)
    message(WARNING "libslic3r not found at ${LIBSLIC3R_ROOT}/src/libslic3r. "
                    "Run ./build_libslic3r_ios.sh first. Using stub implementation.")
    set(USE_LIBSLIC3R_STUB ON)
else()
    set(USE_LIBSLIC3R_STUB OFF)
    message(STATUS "Found libslic3r: ${LIBSLIC3R_LIBRARY}")
    message(STATUS "Found libslic3r_cgal: ${LIBSLIC3R_CGAL_LIBRARY}")
endif()

# --- iOS App Target ---

set(SWIFT_SOURCES
    OrcaSlicer/App/OrcaSlicerApp.swift
    OrcaSlicer/App/AppState.swift
    OrcaSlicer/App/ContentView.swift
    OrcaSlicer/App/AdaptiveContentView.swift
    OrcaSlicer/Views/Models/ModelsView.swift
    OrcaSlicer/Views/Models/ModelDetailView.swift
    OrcaSlicer/Views/Models/ModelViewer.swift
    OrcaSlicer/Views/Models/ModelTransformView.swift
    OrcaSlicer/Views/Settings/SettingsView.swift
    OrcaSlicer/Views/Slice/SliceView.swift
    OrcaSlicer/Views/GCode/GCodeView.swift
    OrcaSlicer/Views/Printers/PrintersView.swift
    OrcaSlicer/Views/Printers/PrinterDiscoveryView.swift
    OrcaSlicer/Views/About/AboutView.swift
    OrcaSlicer/Views/About/AppSettingsView.swift
    OrcaSlicer/Views/Onboarding/OnboardingView.swift
    OrcaSlicer/Services/PrintModel.swift
    OrcaSlicer/Services/Printer.swift
    OrcaSlicer/Services/PrintProfile.swift
    OrcaSlicer/Services/SliceResult.swift
    OrcaSlicer/Services/SlicerService.swift
    OrcaSlicer/Services/STLParser.swift
    OrcaSlicer/Services/ProfileManager.swift
    OrcaSlicer/Services/PrinterDiscoveryService.swift
)

set(OBJCXX_SOURCES
    OrcaSlicer/Bridge/OrcaSlicerBridge.mm
)

set(HEADERS
    OrcaSlicer/Bridge/OrcaSlicerBridge.h
    OrcaSlicer/Bridge/BridgingHeader.h
)

add_executable(OrcaSlicer
    ${SWIFT_SOURCES}
    ${OBJCXX_SOURCES}
    ${HEADERS}
)

# App bundle configuration
set_target_properties(OrcaSlicer PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.orcaslicer.ios"
    MACOSX_BUNDLE_BUNDLE_VERSION "1"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "2.4.0"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/OrcaSlicer/Info.plist"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.orcaslicer.ios"
    XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/OrcaSlicer/Bridge/BridgingHeader.h"
    XCODE_ATTRIBUTE_SWIFT_VERSION "5.9"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"  # iPhone + iPad
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
    XCODE_ATTRIBUTE_DEVELOPMENT_TEAM ""
)

# Header search paths for libslic3r
target_include_directories(OrcaSlicer PRIVATE
    "${ORCASLICER_SRC_ROOT}"
    "${ORCASLICER_SRC_ROOT}/libslic3r"
    "${LIBSLIC3R_ROOT}"
    "${LIBSLIC3R_ROOT}/src/libslic3r"  # For generated headers (libslic3r_version.h)
    "${DEPS_PREFIX}/include"
    "${DEPS_PREFIX}/include/eigen3"
)

# Link libslic3r if available
if(NOT USE_LIBSLIC3R_STUB)
    target_link_libraries(OrcaSlicer PRIVATE
        ${LIBSLIC3R_LIBRARY}
        ${LIBSLIC3R_CGAL_LIBRARY}
    )

    # Link dependency libraries
    file(GLOB DEP_STATIC_LIBS "${DEPS_PREFIX}/lib/*.a")
    target_link_libraries(OrcaSlicer PRIVATE ${DEP_STATIC_LIBS})

    # Compile definition to enable real libslic3r code paths
    target_compile_definitions(OrcaSlicer PRIVATE ORCA_HAS_LIBSLIC3R=1)
else()
    target_compile_definitions(OrcaSlicer PRIVATE ORCA_HAS_LIBSLIC3R=0)
endif()

# System frameworks
find_library(FOUNDATION Foundation REQUIRED)
find_library(UIKIT UIKit REQUIRED)
find_library(SCENEKIT SceneKit REQUIRED)
find_library(MODELIO ModelIO REQUIRED)
find_library(METAL Metal REQUIRED)
find_library(NETWORK Network REQUIRED)

target_link_libraries(OrcaSlicer PRIVATE
    ${FOUNDATION}
    ${UIKIT}
    ${SCENEKIT}
    ${MODELIO}
    ${METAL}
    ${NETWORK}
    "-lz"
    "-lc++"
)

# Resources
set(RESOURCE_FILES
    OrcaSlicer/Resources/Assets.xcassets
    OrcaSlicer/Preview\ Content/Preview\ Assets.xcassets
)
set_target_properties(OrcaSlicer PROPERTIES
    RESOURCE "${RESOURCE_FILES}"
)

message(STATUS "")
message(STATUS "OrcaSlicer iOS Configuration:")
message(STATUS "  libslic3r linked: ${NOT USE_LIBSLIC3R_STUB}")
message(STATUS "  Source root: ${ORCASLICER_SRC_ROOT}")
message(STATUS "  Deps prefix: ${DEPS_PREFIX}")
message(STATUS "  Deployment target: ${CMAKE_OSX_DEPLOYMENT_TARGET}")
message(STATUS "")
