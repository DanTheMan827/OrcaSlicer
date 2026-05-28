import Foundation

/// Service that interfaces with the libslic3r C++ engine for slicing operations.
/// Calls through OrcaSlicerBridge (ObjC++) which links against the native libslic3r library.
final class SlicerService: Sendable {

    /// Initialize the slicing engine. Should be called on app launch.
    func initializeEngine() -> Bool {
        return OrcaSlicerBridge.shared.initializeEngine()
    }

    /// Slice a model with the given profile and printer configuration.
    /// - Parameters:
    ///   - model: The 3D model to slice
    ///   - profile: Print settings profile
    ///   - printer: Target printer configuration
    ///   - progressHandler: Called with progress value 0.0...1.0
    /// - Returns: The slice result containing G-code path and statistics
    func slice(
        model: PrintModel,
        profile: PrintProfile,
        printer: Printer,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> SliceResult {
        // Build config dictionaries for the bridge
        let printConfig = profile.toDictionary()
        let printerConfig = printer.toConfigDictionary()

        // Determine output path
        let outputDir = FileManager.default.temporaryDirectory
        let gcodeURL = outputDir.appendingPathComponent("\(model.name).gcode")

        // Call through the ObjC++ bridge to libslic3r
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var bridgeError: NSError?
                let result = OrcaSlicerBridge.shared.sliceModel(
                    atPath: model.fileURL.path,
                    outputPath: gcodeURL.path,
                    config: printConfig,
                    printerConfig: printerConfig,
                    progressHandler: { progress in
                        progressHandler(progress)
                    },
                    error: &bridgeError
                )

                if let error = bridgeError {
                    continuation.resume(throwing: error)
                    return
                }

                let sliceResult = SliceResult(
                    gcodeURL: gcodeURL,
                    estimatedTime: result?["estimatedTime"]?.doubleValue ?? 0,
                    estimatedFilament: result?["estimatedFilament"]?.doubleValue ?? 0,
                    layerCount: result?["layerCount"]?.intValue ?? 0,
                    error: nil
                )
                continuation.resume(returning: sliceResult)
            }
        }
    }

    /// Load and validate a model file using libslic3r.
    /// Returns model metadata (vertices, faces, dimensions).
    func loadModelInfo(at url: URL) -> [String: Any]? {
        var error: NSError?
        let info = OrcaSlicerBridge.shared.loadModel(atPath: url.path, error: &error)
        return info as? [String: Any]
    }

    /// Validate that a model file can be loaded.
    func validateModel(at url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["stl", "obj", "3mf", "step", "stp"].contains(ext)
    }

    /// Get available printer profiles from the bundled resources.
    func availablePrinterProfiles() -> [[String: Any]] {
        return OrcaSlicerBridge.shared.availablePrinterProfiles() as? [[String: Any]] ?? []
    }

    /// Get available print quality profiles.
    func availablePrintProfiles() -> [[String: Any]] {
        return OrcaSlicerBridge.shared.availablePrintProfiles() as? [[String: Any]] ?? []
    }

    /// Get the engine version string.
    var engineVersion: String {
        return OrcaSlicerBridge.shared.engineVersion
    }
}
