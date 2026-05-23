// Metal shaders for OrcaSlicer iOS 3D rendering.
// Port of the desktop OpenGL gouraud/flat shaders to Metal Shading Language.
// Implements: Gouraud shading, dual light sources, slope detection,
// clipping planes, per-vertex color, toolpath rendering, and build plate grid.

#include <metal_stdlib>
using namespace metal;

// --- Shared Types (must match Swift ShaderTypes) ---

struct Vertex {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float4 color    [[attribute(2)]];
    float2 texCoord [[attribute(3)]];
};

struct InstanceUniforms {
    float4x4 modelMatrix;
    float3x3 normalMatrix;
    float4 color;
    int selected;
    int hovered;
    float2 padding;
};

struct SceneUniforms {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 viewProjectionMatrix;
    float3 cameraPosition;
    float _pad0;

    float3 lightTopDir;
    float lightTopDiffuse;
    float lightTopSpecular;
    float lightTopShininess;
    float3 lightFrontDir;
    float lightFrontDiffuse;
    float ambientIntensity;
    float3 _pad1;

    float2 zRange;
    float4 clippingPlane;
    float4 colorClipPlane;

    int slopeActive;
    float slopeNormalZ;
    float2 _pad2;
};

struct GridUniforms {
    float4x4 modelViewProjection;
    float4 gridColor;
    float gridSpacing;
    float gridLineWidth;
    float plateWidth;
    float plateDepth;
};

struct ToolpathUniforms {
    float4x4 viewProjection;
    float lineWidth;
    float layerHeight;
    float currentLayer;
    float totalLayers;
    int showTravel;
    int showRetractions;
    float2 _pad;
};

// --- Gouraud Shader (main model rendering) ---
// Matches desktop's gouraud.vs / gouraud.fs

struct GouraudVertexOut {
    float4 position [[position]];
    float2 intensity;           // x = diffuse, y = specular
    float3 clipping_planes_dots;
    float color_clip_plane_dot;
    float4 world_pos;
    float world_normal_z;
    float3 eye_normal;
    float4 vertexColor;
};

vertex GouraudVertexOut gouraud_vertex(
    Vertex in [[stage_in]],
    constant SceneUniforms &scene [[buffer(1)]],
    constant InstanceUniforms &instance [[buffer(2)]]
) {
    GouraudVertexOut out;

    float4 worldPos = instance.modelMatrix * float4(in.position, 1.0);
    float4 viewPos = scene.viewMatrix * worldPos;
    out.position = scene.projectionMatrix * viewPos;

    // Transform normal to view space
    float3 viewNormal = normalize(instance.normalMatrix * in.normal);
    out.eye_normal = viewNormal;

    // Gouraud lighting calculation (matching desktop exactly)
    float NdotL_top = max(dot(viewNormal, scene.lightTopDir), 0.0);
    out.intensity.x = scene.ambientIntensity + NdotL_top * scene.lightTopDiffuse;

    // Specular (top light only)
    float3 viewDir = -normalize(viewPos.xyz);
    float3 reflectDir = reflect(-scene.lightTopDir, viewNormal);
    out.intensity.y = scene.lightTopSpecular *
        pow(max(dot(viewDir, reflectDir), 0.0), scene.lightTopShininess);

    // Front light diffuse
    float NdotL_front = max(dot(viewNormal, scene.lightFrontDir), 0.0);
    out.intensity.x += NdotL_front * scene.lightFrontDiffuse;

    // World position for clipping
    out.world_pos = worldPos;

    // Slope detection
    if (scene.slopeActive != 0) {
        float3 worldNormal = normalize(instance.normalMatrix * in.normal);
        out.world_normal_z = worldNormal.z;
    } else {
        out.world_normal_z = 0.0;
    }

    // Clipping planes
    out.clipping_planes_dots = float3(
        dot(worldPos, scene.clippingPlane),
        worldPos.z - scene.zRange.x,
        scene.zRange.y - worldPos.z
    );
    out.color_clip_plane_dot = dot(worldPos, scene.colorClipPlane);

    // Use instance color, allow per-vertex color override
    out.vertexColor = (in.color.a > 0.0) ? in.color : instance.color;

    return out;
}

fragment float4 gouraud_fragment(
    GouraudVertexOut in [[stage_in]],
    constant SceneUniforms &scene [[buffer(1)]],
    constant InstanceUniforms &instance [[buffer(2)]]
) {
    // Clipping
    if (in.clipping_planes_dots.x < 0.0 ||
        in.clipping_planes_dots.y < 0.0 ||
        in.clipping_planes_dots.z < 0.0) {
        discard_fragment();
    }

    float4 baseColor = in.vertexColor;

    // Selection/hover highlighting (matching desktop behavior)
    if (instance.selected != 0) {
        baseColor = mix(baseColor, float4(0.2, 0.6, 1.0, 1.0), 0.3);
    } else if (instance.hovered != 0) {
        baseColor = mix(baseColor, float4(1.0, 1.0, 1.0, 1.0), 0.15);
    }

    // Slope detection coloring
    if (scene.slopeActive != 0 && in.world_normal_z < scene.slopeNormalZ) {
        baseColor = mix(baseColor, float4(1.0, 0.0, 0.0, 1.0), 0.4);
    }

    // Apply Gouraud lighting
    float3 litColor = baseColor.rgb * in.intensity.x + float3(in.intensity.y);

    return float4(litColor, baseColor.a);
}

// --- Flat Shader (for wireframes, outlines, simple geometry) ---

struct FlatVertexOut {
    float4 position [[position]];
    float4 color;
};

vertex FlatVertexOut flat_vertex(
    Vertex in [[stage_in]],
    constant SceneUniforms &scene [[buffer(1)]],
    constant InstanceUniforms &instance [[buffer(2)]]
) {
    FlatVertexOut out;
    float4 worldPos = instance.modelMatrix * float4(in.position, 1.0);
    out.position = scene.viewProjectionMatrix * worldPos;
    out.color = (in.color.a > 0.0) ? in.color : instance.color;
    return out;
}

fragment float4 flat_fragment(FlatVertexOut in [[stage_in]]) {
    return in.color;
}

// --- Build Plate Grid Shader ---

struct GridVertexOut {
    float4 position [[position]];
    float2 worldXZ;
};

vertex GridVertexOut grid_vertex(
    Vertex in [[stage_in]],
    constant GridUniforms &grid [[buffer(1)]]
) {
    GridVertexOut out;
    out.position = grid.modelViewProjection * float4(in.position, 1.0);
    out.worldXZ = in.position.xz;
    return out;
}

fragment float4 grid_fragment(
    GridVertexOut in [[stage_in]],
    constant GridUniforms &grid [[buffer(1)]]
) {
    float2 pos = in.worldXZ;

    // Generate grid lines
    float2 gridPos = fmod(abs(pos), float2(grid.gridSpacing));
    float2 delta = fwidth(pos);
    float2 gridLines = smoothstep(
        float2(grid.gridLineWidth) - delta,
        float2(grid.gridLineWidth) + delta,
        gridPos
    );
    float line = 1.0 - min(gridLines.x, gridLines.y);

    // Fade at plate edges
    float2 plateHalf = float2(grid.plateWidth, grid.plateDepth) * 0.5;
    float2 edgeDist = plateHalf - abs(pos);
    float edgeFade = min(smoothstep(0.0, 5.0, edgeDist.x), smoothstep(0.0, 5.0, edgeDist.y));

    // Stronger lines at origin axes
    float axisLine = 0.0;
    if (abs(pos.x) < grid.gridLineWidth * 2.0) axisLine = 0.8;
    if (abs(pos.y) < grid.gridLineWidth * 2.0) axisLine = 0.8;

    float alpha = max(line * 0.4, axisLine) * edgeFade;
    return float4(grid.gridColor.rgb, alpha * grid.gridColor.a);
}

// --- Toolpath Shader (G-code preview) ---

// Toolpath colors by type (matching desktop color scheme)
constant float4 TOOLPATH_COLORS[] = {
    float4(1.0, 0.73, 0.0, 1.0),    // 0: Perimeter (orange)
    float4(0.78, 0.15, 0.15, 1.0),   // 1: Infill (red)
    float4(0.0, 0.8, 0.0, 1.0),      // 2: Support (green)
    float4(0.0, 0.6, 1.0, 0.6),      // 3: Travel (blue, semi-transparent)
    float4(1.0, 0.0, 1.0, 1.0),      // 4: Retraction (magenta)
    float4(0.5, 0.5, 0.5, 1.0),      // 5: Default (gray)
};

struct ToolpathVertex_In {
    float3 position [[attribute(0)]];
    float extrusionWidth [[attribute(1)]];
    float feedRate [[attribute(2)]];
    float layerIndex [[attribute(3)]];
    int type [[attribute(4)]];
    int extruder [[attribute(5)]];
};

struct ToolpathVertexOut {
    float4 position [[position]];
    float4 color;
    float pointSize [[point_size]];
};

vertex ToolpathVertexOut toolpath_vertex(
    ToolpathVertex_In in [[stage_in]],
    constant ToolpathUniforms &uniforms [[buffer(1)]]
) {
    ToolpathVertexOut out;
    out.position = uniforms.viewProjection * float4(in.position, 1.0);

    // Layer-based visibility
    float layerAlpha = 1.0;
    if (in.layerIndex > uniforms.currentLayer) {
        discard_fragment();
        layerAlpha = 0.0;
    } else if (in.layerIndex < uniforms.currentLayer - 1.0) {
        layerAlpha = 0.3; // Dim previous layers
    }

    // Filter by type
    if (in.type == 3 && uniforms.showTravel == 0) {
        layerAlpha = 0.0;
    }
    if (in.type == 4 && uniforms.showRetractions == 0) {
        layerAlpha = 0.0;
    }

    int colorIndex = clamp(in.type, 0, 5);
    out.color = TOOLPATH_COLORS[colorIndex];
    out.color.a *= layerAlpha;

    // Point size for retraction markers
    out.pointSize = (in.type == 4) ? 6.0 : 2.0;

    return out;
}

fragment float4 toolpath_fragment(ToolpathVertexOut in [[stage_in]]) {
    if (in.color.a < 0.01) discard_fragment();
    return in.color;
}
