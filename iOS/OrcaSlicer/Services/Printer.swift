import Foundation

/// Represents a configured 3D printer.
struct Printer: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var manufacturer: String
    var model: String
    var bedShape: BedShape
    var nozzleDiameter: Double
    var maxBedTemperature: Int
    var maxNozzleTemperature: Int
    var connectionType: ConnectionType

    enum BedShape: String, Codable, CaseIterable {
        case rectangular = "Rectangular"
        case circular = "Circular"
    }

    enum ConnectionType: String, Codable, CaseIterable {
        case network = "Network"
        case octoprint = "OctoPrint"
        case none = "None (Export Only)"
    }

    struct BedSize: Codable, Hashable {
        var width: Double
        var depth: Double
        var height: Double
    }

    var bedSize: BedSize

    /// Build plate width in mm (convenience for rendering)
    var buildPlateWidth: Double { bedSize.width }
    /// Build plate depth in mm (convenience for rendering)
    var buildPlateDepth: Double { bedSize.depth }

    static var `default`: Printer {
        Printer(
            id: UUID(),
            name: "Generic FDM Printer",
            manufacturer: "Generic",
            model: "FDM",
            bedShape: .rectangular,
            nozzleDiameter: 0.4,
            maxBedTemperature: 110,
            maxNozzleTemperature: 300,
            connectionType: .none,
            bedSize: BedSize(width: 220, depth: 220, height: 250)
        )
    }

    /// Convert to a dictionary of libslic3r printer config key-value pairs
    /// for passing through the ObjC++ bridge.
    func toConfigDictionary() -> [String: Any] {
        return [
            "printer_model": model,
            "nozzle_diameter": nozzleDiameter,
            "printable_area": "\(bedSize.width)x\(bedSize.depth)",
            "printable_height": bedSize.height,
            "bed_shape": bedShapeConfigValue,
            "max_bed_temp": maxBedTemperature,
            "max_nozzle_temp": maxNozzleTemperature,
        ]
    }

    private var bedShapeConfigValue: String {
        switch bedShape {
        case .rectangular:
            return "0x0,\(bedSize.width)x0,\(bedSize.width)x\(bedSize.depth),0x\(bedSize.depth)"
        case .circular:
            return "0x0"  // Circular beds use different representation
        }
    }
}
