import Foundation

/// Result of a slicing operation.
struct SliceResult {
    let gcodeURL: URL?
    let estimatedTime: TimeInterval
    let estimatedFilament: Double // meters
    let layerCount: Int
    let error: String?

    var isSuccess: Bool { error == nil && gcodeURL != nil }

    var formattedTime: String {
        let hours = Int(estimatedTime) / 3600
        let minutes = (Int(estimatedTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedFilament: String {
        String(format: "%.2fm", estimatedFilament)
    }
}
