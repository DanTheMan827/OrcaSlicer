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
}
