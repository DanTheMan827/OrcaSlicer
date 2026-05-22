# OrcaSlicer for iOS/iPadOS

A native SwiftUI application for iOS and iPadOS that provides 3D model slicing capabilities powered by the libslic3r engine.

## Requirements

- Xcode 15.0+
- iOS 16.0+ / iPadOS 16.0+
- Swift 5.9+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)

## Project Setup

### Quick Start

1. Install XcodeGen:
   ```bash
   brew install xcodegen
   ```

2. Generate the Xcode project:
   ```bash
   cd iOS
   xcodegen generate
   ```

3. Open in Xcode:
   ```bash
   open OrcaSlicer.xcodeproj
   ```

4. Select an iOS Simulator or device and build (⌘B).

### Building with libslic3r (Full Slicing Support)

The app currently includes a bridge layer (`Bridge/OrcaSlicerBridge.mm`) that is ready to link against the libslic3r static library. To enable full slicing:

1. Build libslic3r for iOS/ARM64:
   ```bash
   # From the repository root
   cd deps
   mkdir -p build/ios-arm64 && cd build/ios-arm64
   cmake ../.. \
     -G "Unix Makefiles" \
     -DCMAKE_SYSTEM_NAME=iOS \
     -DCMAKE_OSX_ARCHITECTURES=arm64 \
     -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
     -DCMAKE_BUILD_TYPE=Release
   cmake --build . --target deps
   ```

2. Build the slicer library:
   ```bash
   cd src/libslic3r
   mkdir -p build/ios-arm64 && cd build/ios-arm64
   cmake ../.. \
     -G "Unix Makefiles" \
     -DCMAKE_SYSTEM_NAME=iOS \
     -DCMAKE_OSX_ARCHITECTURES=arm64 \
     -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
     -DCMAKE_BUILD_TYPE=Release \
     -DSLIC3R_GUI=OFF
   cmake --build .
   ```

3. Add the built `libslic3r.a` to the Xcode project's "Link Binary With Libraries" build phase.

4. Uncomment the `#include` directives in `Bridge/OrcaSlicerBridge.mm`.

## Architecture

```
iOS/
├── Package.swift              # SPM manifest (for Swift-only compilation)
├── project.yml                # XcodeGen project specification
├── README.md
└── OrcaSlicer/
    ├── App/
    │   ├── OrcaSlicerApp.swift    # @main entry point
    │   ├── AppState.swift         # Central state management
    │   └── ContentView.swift      # Tab-based root view
    ├── Views/
    │   ├── Models/
    │   │   ├── ModelsView.swift       # Model library with import
    │   │   ├── ModelDetailView.swift   # Individual model view
    │   │   └── ModelViewer.swift       # SceneKit 3D viewer
    │   ├── Settings/
    │   │   └── SettingsView.swift     # Print profile configuration
    │   ├── Slice/
    │   │   └── SliceView.swift        # Slicing interface
    │   └── Printers/
    │       └── PrintersView.swift     # Printer management
    ├── Services/
    │   ├── PrintModel.swift       # Model data type
    │   ├── Printer.swift          # Printer configuration
    │   ├── PrintProfile.swift     # Print settings
    │   ├── SliceResult.swift      # Slicing output
    │   └── SlicerService.swift    # Slicing service interface
    ├── Bridge/
    │   ├── BridgingHeader.h       # Swift-ObjC bridging header
    │   ├── OrcaSlicerBridge.h     # ObjC++ bridge interface
    │   └── OrcaSlicerBridge.mm    # ObjC++ bridge implementation
    ├── Resources/
    │   └── Assets.xcassets/       # App icons and colors
    ├── Info.plist                  # App configuration
    └── OrcaSlicer.entitlements    # App capabilities
```

## Design Principles

This app follows Apple's Human Interface Guidelines:

- **Tab-based navigation** for top-level sections
- **NavigationStack** for hierarchical navigation within tabs
- **Form-based settings** with proper grouping and disclosure
- **ContentUnavailableView** for empty states
- **System SF Symbols** for consistent iconography
- **Dynamic Type** support throughout
- **Dark Mode** support via semantic colors
- **iPad multitasking** and multi-scene support
- **Document-based** file handling with proper UTType declarations
- **SceneKit/Metal** for 3D model rendering (no OpenGL)
- **Async/await** for non-blocking slicing operations

## Key Differences from Desktop Version

| Feature | Desktop (macOS) | iOS |
|---------|----------------|-----|
| GUI Framework | wxWidgets | SwiftUI |
| 3D Rendering | OpenGL | SceneKit (Metal) |
| File Access | Direct filesystem | Document picker + security-scoped URLs |
| Build System | CMake | Xcode / SPM |
| Language | C++ | Swift + C++ bridge |
| Printer Connection | Direct USB/Network | Network only |

## Future Work

- [ ] Complete libslic3r integration for actual slicing
- [ ] STL/3MF file parser in Metal compute shaders for fast model loading
- [ ] G-code preview with layer-by-layer visualization
- [ ] Network printer discovery via Bonjour/mDNS
- [ ] iCloud Drive sync for models and profiles
- [ ] Shortcuts/Intents integration for automation
- [ ] Widget for print progress monitoring
- [ ] Apple Watch companion for print status
- [ ] SharePlay for collaborative model review
