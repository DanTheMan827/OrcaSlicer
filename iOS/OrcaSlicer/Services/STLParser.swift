import Foundation

/// Pure Swift STL file parser for loading 3D models without libslic3r dependency.
/// Supports both ASCII and binary STL formats.
struct STLParser {

    struct Triangle {
        let normal: SIMD3<Float>
        let vertex1: SIMD3<Float>
        let vertex2: SIMD3<Float>
        let vertex3: SIMD3<Float>
    }

    struct STLMesh {
        let triangles: [Triangle]
        let boundingBoxMin: SIMD3<Float>
        let boundingBoxMax: SIMD3<Float>

        var vertexCount: Int { triangles.count * 3 }
        var faceCount: Int { triangles.count }

        var dimensions: SIMD3<Float> {
            boundingBoxMax - boundingBoxMin
        }

        var center: SIMD3<Float> {
            (boundingBoxMin + boundingBoxMax) / 2
        }
    }

    enum STLError: Error, LocalizedError {
        case fileNotFound
        case invalidFormat
        case readError(String)
        case emptyMesh

        var errorDescription: String? {
            switch self {
            case .fileNotFound: return "STL file not found"
            case .invalidFormat: return "Invalid STL file format"
            case .readError(let msg): return "Error reading STL: \(msg)"
            case .emptyMesh: return "STL file contains no triangles"
            }
        }
    }

    /// Parse an STL file at the given URL.
    /// Automatically detects binary vs ASCII format.
    static func parse(url: URL) throws -> STLMesh {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw STLError.fileNotFound
        }

        guard let data = try? Data(contentsOf: url) else {
            throw STLError.readError("Could not read file data")
        }

        if isBinarySTL(data) {
            return try parseBinary(data)
        } else {
            return try parseASCII(data)
        }
    }

    /// Detect if the STL is binary format.
    /// Binary STL has an 80-byte header + 4-byte triangle count.
    /// ASCII STL starts with "solid".
    private static func isBinarySTL(_ data: Data) -> Bool {
        // Binary STL requires at least 84 bytes (header + triangle count)
        guard data.count >= 84 else { return false }

        // Check if starts with "solid" (ASCII indicator)
        let header = String(data: data.prefix(5), encoding: .ascii) ?? ""
        if header.lowercased() == "solid" {
            // Could still be binary if the header happens to start with "solid"
            // Validate against the binary format equation: size == 84 + triangleCount * 50
            let triangleCount = data.withUnsafeBytes { buffer in
                buffer.load(fromByteOffset: 80, as: UInt32.self)
            }
            let expectedSize = 84 + Int(triangleCount) * 50
            if data.count == expectedSize && triangleCount > 0 {
                return true
            }
            // Check if the file contains "endsolid" (ASCII indicator)
            if let str = String(data: data, encoding: .ascii),
               str.contains("endsolid") {
                return false
            }
            // File doesn't match binary size and has no endsolid — likely corrupt ASCII
            return data.count == expectedSize
        }
        return true
    }

    /// Parse binary STL format.
    /// Format: 80 bytes header, 4 bytes triangle count, then 50 bytes per triangle.
    private static func parseBinary(_ data: Data) throws -> STLMesh {
        guard data.count >= 84 else {
            throw STLError.invalidFormat
        }

        let triangleCount: UInt32 = data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: 80, as: UInt32.self)
        }

        let expectedSize = 84 + Int(triangleCount) * 50
        guard data.count >= expectedSize else {
            throw STLError.invalidFormat
        }

        var triangles: [Triangle] = []
        triangles.reserveCapacity(Int(triangleCount))

        var minBound = SIMD3<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxBound = SIMD3<Float>(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)

        data.withUnsafeBytes { buffer in
            for i in 0..<Int(triangleCount) {
                let offset = 84 + i * 50

                let nx = buffer.load(fromByteOffset: offset + 0, as: Float.self)
                let ny = buffer.load(fromByteOffset: offset + 4, as: Float.self)
                let nz = buffer.load(fromByteOffset: offset + 8, as: Float.self)

                let v1x = buffer.load(fromByteOffset: offset + 12, as: Float.self)
                let v1y = buffer.load(fromByteOffset: offset + 16, as: Float.self)
                let v1z = buffer.load(fromByteOffset: offset + 20, as: Float.self)

                let v2x = buffer.load(fromByteOffset: offset + 24, as: Float.self)
                let v2y = buffer.load(fromByteOffset: offset + 28, as: Float.self)
                let v2z = buffer.load(fromByteOffset: offset + 32, as: Float.self)

                let v3x = buffer.load(fromByteOffset: offset + 36, as: Float.self)
                let v3y = buffer.load(fromByteOffset: offset + 40, as: Float.self)
                let v3z = buffer.load(fromByteOffset: offset + 44, as: Float.self)

                let normal = SIMD3<Float>(nx, ny, nz)
                let v1 = SIMD3<Float>(v1x, v1y, v1z)
                let v2 = SIMD3<Float>(v2x, v2y, v2z)
                let v3 = SIMD3<Float>(v3x, v3y, v3z)

                triangles.append(Triangle(normal: normal, vertex1: v1, vertex2: v2, vertex3: v3))

                // Update bounding box
                for v in [v1, v2, v3] {
                    minBound = SIMD3<Float>(min(minBound.x, v.x), min(minBound.y, v.y), min(minBound.z, v.z))
                    maxBound = SIMD3<Float>(max(maxBound.x, v.x), max(maxBound.y, v.y), max(maxBound.z, v.z))
                }
            }
        }

        guard !triangles.isEmpty else {
            throw STLError.emptyMesh
        }

        return STLMesh(triangles: triangles, boundingBoxMin: minBound, boundingBoxMax: maxBound)
    }

    /// Parse ASCII STL format.
    private static func parseASCII(_ data: Data) throws -> STLMesh {
        guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw STLError.invalidFormat
        }

        var triangles: [Triangle] = []
        var minBound = SIMD3<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxBound = SIMD3<Float>(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)

        var currentNormal = SIMD3<Float>(0, 0, 0)
        var vertices: [SIMD3<Float>] = []

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()

            if trimmed.hasPrefix("facet normal") {
                let parts = trimmed.split(separator: " ")
                if parts.count >= 5 {
                    let nx = Float(parts[2]) ?? 0
                    let ny = Float(parts[3]) ?? 0
                    let nz = Float(parts[4]) ?? 0
                    currentNormal = SIMD3<Float>(nx, ny, nz)
                }
                vertices = []
            } else if trimmed.hasPrefix("vertex") {
                let parts = trimmed.split(separator: " ")
                if parts.count >= 4 {
                    let x = Float(parts[1]) ?? 0
                    let y = Float(parts[2]) ?? 0
                    let z = Float(parts[3]) ?? 0
                    let v = SIMD3<Float>(x, y, z)
                    vertices.append(v)

                    minBound = SIMD3<Float>(min(minBound.x, v.x), min(minBound.y, v.y), min(minBound.z, v.z))
                    maxBound = SIMD3<Float>(max(maxBound.x, v.x), max(maxBound.y, v.y), max(maxBound.z, v.z))
                }
            } else if trimmed.hasPrefix("endfacet") {
                if vertices.count == 3 {
                    triangles.append(Triangle(
                        normal: currentNormal,
                        vertex1: vertices[0],
                        vertex2: vertices[1],
                        vertex3: vertices[2]
                    ))
                }
            }
        }

        guard !triangles.isEmpty else {
            throw STLError.emptyMesh
        }

        return STLMesh(triangles: triangles, boundingBoxMin: minBound, boundingBoxMax: maxBound)
    }
}
