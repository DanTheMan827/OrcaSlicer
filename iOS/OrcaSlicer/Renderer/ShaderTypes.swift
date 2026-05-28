// Metal shader types shared between Metal shaders and Swift code.
// Matches the desktop OrcaSlicer OpenGL rendering pipeline (Gouraud shading,
// dual light sources, slope detection, clipping planes).

import simd

/// Vertex data sent to Metal shaders
struct OrcaVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var color: SIMD4<Float>
    var texCoord: SIMD2<Float>
}

/// Per-instance uniforms for each rendered volume
struct InstanceUniforms {
    var modelMatrix: simd_float4x4
    var normalMatrix: simd_float3x3
    var color: SIMD4<Float>
    var selected: Int32
    var hovered: Int32
    var padding: SIMD2<Float>
}

/// Scene-level uniforms (camera, lights, clipping)
struct SceneUniforms {
    var viewMatrix: simd_float4x4
    var projectionMatrix: simd_float4x4
    var viewProjectionMatrix: simd_float4x4
    var cameraPosition: SIMD3<Float>
    var _pad0: Float

    // Light matching desktop OrcaSlicer gouraud shader
    var lightTopDir: SIMD3<Float>        // normalized (-0.4574957, 0.4574957, 0.7624929)
    var lightTopDiffuse: Float           // 0.8 * 0.6 = 0.48
    var lightTopSpecular: Float          // 0.125 * 0.6 = 0.075
    var lightTopShininess: Float         // 20.0
    var lightFrontDir: SIMD3<Float>      // normalized (0.6985074, 0.1397015, 0.6985074)
    var lightFrontDiffuse: Float         // 0.3 * 0.6 = 0.18
    var ambientIntensity: Float          // 0.3
    var _pad1: SIMD3<Float>

    // Clipping planes (matching desktop z_range and clipping_plane)
    var zRange: SIMD2<Float>             // x = min z, y = max z
    var clippingPlane: SIMD4<Float>      // general orientation clipping plane
    var colorClipPlane: SIMD4<Float>     // used by cut gizmo

    // Slope detection
    var slopeActive: Int32
    var slopeNormalZ: Float
    var _pad2: SIMD2<Float>
}

/// Build plate grid uniforms
struct GridUniforms {
    var modelViewProjection: simd_float4x4
    var gridColor: SIMD4<Float>
    var gridSpacing: Float
    var gridLineWidth: Float
    var plateWidth: Float
    var plateDepth: Float
}

/// Toolpath rendering uniforms
struct ToolpathUniforms {
    var viewProjection: simd_float4x4
    var lineWidth: Float
    var layerHeight: Float
    var currentLayer: Float
    var totalLayers: Float
    var showTravel: Int32
    var showRetractions: Int32
    var _pad: SIMD2<Float>
}

/// Toolpath vertex with additional metadata
struct ToolpathVertex {
    var position: SIMD3<Float>
    var extrusionWidth: Float
    var feedRate: Float
    var layerIndex: Float
    var type: Int32       // 0=perimeter, 1=infill, 2=support, 3=travel, 4=retraction
    var extruder: Int32   // extruder/filament index
}
