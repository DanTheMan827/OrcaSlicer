import Foundation

/// Print settings profile that maps to libslic3r's PrintConfig.
struct PrintProfile: Codable {
    var layerHeight: Double
    var firstLayerHeight: Double
    var wallLoops: Int
    var topShellLayers: Int
    var bottomShellLayers: Int
    var infillDensity: Double
    var infillPattern: InfillPattern
    var printSpeed: Double
    var travelSpeed: Double
    var supportEnabled: Bool
    var supportType: SupportType
    var adhesionType: AdhesionType
    var nozzleTemperature: Int
    var bedTemperature: Int
    var firstLayerNozzleTemperature: Int
    var firstLayerBedTemperature: Int
    var fanSpeed: Int
    var retractionLength: Double
    var retractionSpeed: Double

    enum InfillPattern: String, Codable, CaseIterable, Identifiable {
        case grid = "Grid"
        case triangles = "Triangles"
        case cubic = "Cubic"
        case gyroid = "Gyroid"
        case honeycomb = "Honeycomb"
        case line = "Line"
        case concentric = "Concentric"
        case adaptiveCubic = "Adaptive Cubic"
        case lightning = "Lightning"

        var id: String { rawValue }
    }

    enum SupportType: String, Codable, CaseIterable, Identifiable {
        case normal = "Normal"
        case tree = "Tree"
        case organic = "Organic"

        var id: String { rawValue }
    }

    enum AdhesionType: String, Codable, CaseIterable, Identifiable {
        case none = "None"
        case skirt = "Skirt"
        case brim = "Brim"
        case raft = "Raft"

        var id: String { rawValue }
    }

    static var `default`: PrintProfile {
        PrintProfile(
            layerHeight: 0.2,
            firstLayerHeight: 0.28,
            wallLoops: 2,
            topShellLayers: 4,
            bottomShellLayers: 4,
            infillDensity: 15.0,
            infillPattern: .grid,
            printSpeed: 100.0,
            travelSpeed: 200.0,
            supportEnabled: false,
            supportType: .normal,
            adhesionType: .skirt,
            nozzleTemperature: 220,
            bedTemperature: 60,
            firstLayerNozzleTemperature: 225,
            firstLayerBedTemperature: 65,
            fanSpeed: 100,
            retractionLength: 0.8,
            retractionSpeed: 30.0
        )
    }

    /// Quality presets
    static var draft: PrintProfile {
        var profile = PrintProfile.default
        profile.layerHeight = 0.3
        profile.firstLayerHeight = 0.35
        profile.wallLoops = 2
        profile.topShellLayers = 3
        profile.bottomShellLayers = 3
        profile.printSpeed = 150.0
        return profile
    }

    static var standard: PrintProfile {
        .default
    }

    static var quality: PrintProfile {
        var profile = PrintProfile.default
        profile.layerHeight = 0.12
        profile.firstLayerHeight = 0.2
        profile.wallLoops = 3
        profile.topShellLayers = 5
        profile.bottomShellLayers = 5
        profile.printSpeed = 60.0
        return profile
    }
}
