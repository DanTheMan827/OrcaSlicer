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

    /// Convert to a dictionary of libslic3r config key-value pairs
    /// for passing through the ObjC++ bridge.
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "layer_height": layerHeight,
            "first_layer_height": firstLayerHeight,
            "wall_loops": wallLoops,
            "top_shell_layers": topShellLayers,
            "bottom_shell_layers": bottomShellLayers,
            "sparse_infill_density": infillDensity,
            "sparse_infill_pattern": infillPatternConfigValue,
            "outer_wall_speed": printSpeed,
            "travel_speed": travelSpeed,
            "enable_support": supportEnabled ? "1" : "0",
            "nozzle_temperature": nozzleTemperature,
            "bed_temperature": bedTemperature,
            "nozzle_temperature_initial_layer": firstLayerNozzleTemperature,
            "bed_temperature_initial_layer": firstLayerBedTemperature,
            "fan_max_speed": fanSpeed,
            "retraction_length": retractionLength,
            "retraction_speed": retractionSpeed,
        ]

        if supportEnabled {
            dict["support_type"] = supportTypeConfigValue
        }

        dict["skirt_loops"] = adhesionType == .skirt ? "1" : "0"
        dict["brim_type"] = adhesionType == .brim ? "outer_only" : "no_brim"
        dict["raft_layers"] = adhesionType == .raft ? "3" : "0"

        return dict
    }

    private var infillPatternConfigValue: String {
        switch infillPattern {
        case .grid: return "grid"
        case .triangles: return "triangles"
        case .cubic: return "cubic"
        case .gyroid: return "gyroid"
        case .honeycomb: return "honeycomb"
        case .line: return "line"
        case .concentric: return "concentric"
        case .adaptiveCubic: return "adaptivecubic"
        case .lightning: return "lightning"
        }
    }

    private var supportTypeConfigValue: String {
        switch supportType {
        case .normal: return "normal(auto)"
        case .tree: return "tree(auto)"
        case .organic: return "tree(auto)"
        }
    }
}
