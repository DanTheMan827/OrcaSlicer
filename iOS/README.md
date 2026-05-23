# OrcaSlicer for iOS/iPadOS

A native SwiftUI application for iOS and iPadOS that provides 3D model slicing capabilities powered by the libslic3r engine.

## Requirements

- Xcode 15.0+
- iOS 16.0+ / iPadOS 16.0+
- Swift 5.9+
- CMake 3.13+ (for building libslic3r)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)

## Building

### Option 1: Full Build (with libslic3r linking)

This builds libslic3r and all dependencies as static libraries for iOS, then links
them into the app, enabling real slicing functionality.

```bash
cd iOS

# Build libslic3r for iOS (device + simulator) and create XCFramework
chmod +x build_libslic3r_ios.sh
./build_libslic3r_ios.sh

# Generate Xcode project with libslic3r enabled
# Edit project.yml: change ORCA_HAS_LIBSLIC3R=0 to ORCA_HAS_LIBSLIC3R=1
xcodegen generate
open OrcaSlicer.xcodeproj
```

The build script:
1. Cross-compiles all required C++ dependencies (Boost, TBB, CGAL, OpenCASCADE, etc.) for iOS ARM64
2. Builds libslic3r as a static library targeting iOS 16+
3. Creates an `OrcaSlicerCore.xcframework` containing device and simulator slices

### Option 2: UI Development (stub mode)

For rapid SwiftUI development without waiting for the full C++ build:

```bash
cd iOS
brew install xcodegen
xcodegen generate
open OrcaSlicer.xcodeproj
```

In stub mode (`ORCA_HAS_LIBSLIC3R=0`), the bridge returns placeholder data and
the app is fully functional for UI iteration.

### Option 3: CMake-based build

```bash
cd iOS

# Build libslic3r first
./build_libslic3r_ios.sh --device

# Generate Xcode project via CMake
mkdir xcode_build && cd xcode_build
cmake .. -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
    -DLIBSLIC3R_ROOT=../build/device \
    -DDEPS_PREFIX=../build/deps/OS/OrcaSlicer_dep/usr/local
```

## Architecture

```
iOS/
├── CMakeLists.txt                 # CMake build (links libslic3r)
├── Package.swift                  # SPM manifest (Swift-only validation)
├── project.yml                    # XcodeGen project specification
├── build_libslic3r_ios.sh         # Cross-compilation script
├── cmake/
│   └── ios.toolchain.cmake        # CMake iOS cross-compilation toolchain
└── OrcaSlicer/
    ├── App/
    │   ├── OrcaSlicerApp.swift        # @main entry point
    │   ├── AppState.swift             # Central state management
    │   ├── ContentView.swift          # Tab-based root (iPhone)
    │   └── AdaptiveContentView.swift  # Sidebar layout (iPad) / Tabs (iPhone)
    ├── Views/
    │   ├── Models/
    │   │   ├── ModelsView.swift           # Model library with import
    │   │   ├── ModelDetailView.swift      # Model detail + transforms
    │   │   ├── ModelViewer.swift          # SceneKit 3D viewer
    │   │   └── ModelTransformView.swift   # Move/rotate/scale controls
    │   ├── Settings/
    │   │   └── SettingsView.swift         # Print profile configuration
    │   ├── Slice/
    │   │   └── SliceView.swift            # Slicing + G-code export
    │   ├── GCode/
    │   │   └── GCodeView.swift            # Layer-by-layer G-code viewer
    │   ├── Printers/
    │   │   ├── PrintersView.swift         # Printer management
    │   │   └── PrinterDiscoveryView.swift # Bonjour network discovery
    │   ├── About/
    │   │   ├── AboutView.swift            # App info and licenses
    │   │   └── AppSettingsView.swift      # App preferences
    │   └── Onboarding/
    │       └── OnboardingView.swift       # First-launch walkthrough
    ├── Services/
    │   ├── PrintModel.swift           # Model data type
    │   ├── Printer.swift              # Printer configuration
    │   ├── PrintProfile.swift         # Print settings (→ libslic3r config)
    │   ├── SliceResult.swift          # Slicing output
    │   ├── SlicerService.swift        # Bridge caller (Swift → ObjC++ → C++)
    │   ├── STLParser.swift            # Pure Swift STL parser (binary + ASCII)
    │   ├── ProfileManager.swift       # Profile save/load/export
    │   └── PrinterDiscoveryService.swift  # Bonjour/mDNS printer discovery
    ├── Bridge/
    │   ├── BridgingHeader.h           # Swift-ObjC bridging header
    │   ├── OrcaSlicerBridge.h         # ObjC++ bridge interface
    │   └── OrcaSlicerBridge.mm        # ObjC++ bridge → libslic3r (conditional)
    ├── Resources/
    │   └── Assets.xcassets/           # App icons and colors
    ├── Info.plist                      # App configuration + UTType declarations
    └── OrcaSlicer.entitlements        # App capabilities
```

## libslic3r Integration

The bridge layer (`OrcaSlicerBridge.mm`) conditionally compiles against libslic3r
using the `ORCA_HAS_LIBSLIC3R` preprocessor flag:

```objc
#if ORCA_HAS_LIBSLIC3R
#include "libslic3r/Model.hpp"
#include "libslic3r/Print.hpp"
#include "libslic3r/PrintConfig.hpp"
// ... real implementation using Slic3r:: namespace
#else
// Stub implementation returning placeholder data
#endif
```

**Data flow:**

```
Swift UI → SlicerService.swift → OrcaSlicerBridge (ObjC++) → libslic3r (C++)
                                         ↓
                              PrintProfile.toDictionary()
                              → DynamicPrintConfig.set_deserialize()
                              → Print.apply(model, config)
                              → Print.process()
                              → Print.export_gcode()
```

**Key libslic3r APIs used:**
- `Slic3r::Model::read_from_file()` — model loading (STL, OBJ, 3MF, STEP)
- `Slic3r::DynamicPrintConfig` — runtime configuration
- `Slic3r::Print::apply()` / `process()` / `export_gcode()` — slicing pipeline
- `Slic3r::FullPrintConfig::defaults()` — default values
- Profile JSON loading from `resources/profiles/`

## Design Principles

This app follows Apple's Human Interface Guidelines:

- **Adaptive layout** — Sidebar on iPad, tab bar on iPhone
- **NavigationStack** for hierarchical navigation
- **Form-based settings** with proper grouping and disclosure
- **ContentUnavailableView** for empty states
- **System SF Symbols** for consistent iconography
- **Dynamic Type** support throughout
- **Dark Mode** support via semantic colors
- **iPad multitasking** and multi-scene support
- **Document-based** file handling with proper UTType declarations
- **SceneKit/Metal** for 3D model rendering (no OpenGL)
- **Async/await** for non-blocking slicing operations
- **Bonjour** for network printer discovery

## Key Differences from Desktop Version

| Feature | Desktop (macOS) | iOS |
|---------|----------------|-----|
| GUI Framework | wxWidgets | SwiftUI |
| 3D Rendering | OpenGL | SceneKit (Metal) |
| File Access | Direct filesystem | Document picker + security-scoped URLs |
| Build System | CMake | Xcode + CMake (for libslic3r) |
| Language | C++ | Swift + ObjC++ bridge + C++ engine |
| Printer Connection | USB + Network | Network only (Bonjour discovery) |
| Layout | Single window | Tab bar (iPhone) / Sidebar (iPad) |

## Future Work

- [ ] iCloud Drive sync for models and profiles
- [ ] Metal compute shader-based STL mesh processing
- [ ] Shortcuts/Intents integration for automation
- [ ] Widget for print progress monitoring
- [ ] Apple Watch companion for print status
- [ ] SharePlay for collaborative model review
- [ ] Live Activity for active print monitoring
