import Foundation

/// Represents a 3D model imported for slicing.
struct PrintModel: Identifiable, Hashable {
    let id: UUID
    let name: String
    let fileURL: URL
    let fileType: FileType
    let dateAdded: Date
    var thumbnail: Data?

    enum FileType: String, CaseIterable {
        case stl = "STL"
        case obj = "OBJ"
        case threeMF = "3MF"
        case step = "STEP"
        case unknown = "Unknown"

        init(from extension: String) {
            switch `extension`.lowercased() {
            case "stl": self = .stl
            case "obj": self = .obj
            case "3mf": self = .threeMF
            case "step", "stp": self = .step
            default: self = .unknown
            }
        }

        var utTypes: [String] {
            switch self {
            case .stl: return ["public.standard-tesselated-geometry"]
            case .obj: return ["public.geometry-definition-format"]
            case .threeMF: return ["com.3mf.3mf"]
            case .step: return ["public.step"]
            case .unknown: return []
            }
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PrintModel, rhs: PrintModel) -> Bool {
        lhs.id == rhs.id
    }
}
