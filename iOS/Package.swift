// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift Package Manager needed.
//
// NOTE: This Package.swift is provided for building the pure-Swift portions of the iOS app.
// The full app requires Xcode to build due to the bridging header, asset catalog, and
// Info.plist integration. Use the project.yml with XcodeGen or open in Xcode directly.
//
// For Xcode:
//   1. Install XcodeGen: brew install xcodegen
//   2. cd iOS && xcodegen generate
//   3. Open OrcaSlicer.xcodeproj

import PackageDescription

let package = Package(
    name: "OrcaSlicerIOS",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "OrcaSlicerIOS",
            targets: ["OrcaSlicerIOS"]
        ),
    ],
    targets: [
        .target(
            name: "OrcaSlicerIOS",
            dependencies: [],
            path: "OrcaSlicer",
            exclude: [
                "Bridge/OrcaSlicerBridge.mm",
                "Bridge/OrcaSlicerBridge.h",
                "Bridge/BridgingHeader.h",
                "Info.plist",
                "OrcaSlicer.entitlements",
                "Preview Content",
                "Resources/Assets.xcassets",
                "Renderer/Shaders.metal"
            ],
            sources: [
                "App/",
                "Views/",
                "Services/",
                "Renderer/"
            ]
        ),
    ]
)
