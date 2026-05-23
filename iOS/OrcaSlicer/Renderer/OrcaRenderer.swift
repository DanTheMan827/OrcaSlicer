import MetalKit
import simd

/// Metal-based 3D renderer matching the desktop OrcaSlicer OpenGL pipeline.
/// Implements Gouraud shading with dual light sources, slope detection,
/// clipping planes, build plate grid, toolpath visualization, and model selection.
@MainActor
final class OrcaRenderer: NSObject, MTKViewDelegate {

    // MARK: - Metal State

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var gouraudPipeline: MTLRenderPipelineState!
    private var flatPipeline: MTLRenderPipelineState!
    private var gridPipeline: MTLRenderPipelineState!
    private var toolpathPipeline: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    private var transparentDepthState: MTLDepthStencilState!

    // MARK: - Scene State

    private var sceneUniforms = SceneUniforms()
    private var camera = Camera()
    private(set) var volumes: [RenderVolume] = []
    private var gridBuffer: MTLBuffer?
    private var toolpathBuffer: MTLBuffer?
    private var toolpathVertexCount: Int = 0

    // MARK: - Configuration

    var buildPlateSize: SIMD2<Float> = SIMD2(256, 256) { didSet { rebuildGrid() } }
    var gridSpacing: Float = 10.0
    var backgroundColor: SIMD4<Float> = SIMD4(0.95, 0.95, 0.95, 1.0)
    var slopeDetectionEnabled: Bool = false
    var slopeThreshold: Float = 0.707 // 45 degrees

    // Clipping
    var zRange: SIMD2<Float> = SIMD2(-10000, 10000)
    var clippingPlane: SIMD4<Float> = SIMD4(0, 0, 0, 0)

    // Toolpath
    var currentToolpathLayer: Float = 0
    var totalToolpathLayers: Float = 0
    var showTravelMoves: Bool = false
    var showRetractions: Bool = true

    // Selection
    var selectedVolumeIndex: Int? = nil
    var hoveredVolumeIndex: Int? = nil

    // Callbacks
    var onFrameRendered: (() -> Void)?

    // MARK: - Init

    init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue

        super.init()

        guard buildPipelines() else { return nil }
        buildDepthStates()
        rebuildGrid()
        setupDefaultLighting()
    }

    // MARK: - Pipeline Setup

    private func buildPipelines() -> Bool {
        guard let library = device.makeDefaultLibrary() else { return false }

        // Gouraud pipeline (main model rendering)
        let gouraudDesc = MTLRenderPipelineDescriptor()
        gouraudDesc.vertexFunction = library.makeFunction(name: "gouraud_vertex")
        gouraudDesc.fragmentFunction = library.makeFunction(name: "gouraud_fragment")
        gouraudDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        gouraudDesc.colorAttachments[0].isBlendingEnabled = true
        gouraudDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        gouraudDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        gouraudDesc.depthAttachmentPixelFormat = .depth32Float
        gouraudDesc.vertexDescriptor = Self.vertexDescriptor()

        // Flat pipeline (wireframes, outlines)
        let flatDesc = MTLRenderPipelineDescriptor()
        flatDesc.vertexFunction = library.makeFunction(name: "flat_vertex")
        flatDesc.fragmentFunction = library.makeFunction(name: "flat_fragment")
        flatDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        flatDesc.colorAttachments[0].isBlendingEnabled = true
        flatDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        flatDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        flatDesc.depthAttachmentPixelFormat = .depth32Float
        flatDesc.vertexDescriptor = Self.vertexDescriptor()

        // Grid pipeline
        let gridDesc = MTLRenderPipelineDescriptor()
        gridDesc.vertexFunction = library.makeFunction(name: "grid_vertex")
        gridDesc.fragmentFunction = library.makeFunction(name: "grid_fragment")
        gridDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        gridDesc.colorAttachments[0].isBlendingEnabled = true
        gridDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        gridDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        gridDesc.depthAttachmentPixelFormat = .depth32Float
        gridDesc.vertexDescriptor = Self.vertexDescriptor()

        // Toolpath pipeline
        let toolpathDesc = MTLRenderPipelineDescriptor()
        toolpathDesc.vertexFunction = library.makeFunction(name: "toolpath_vertex")
        toolpathDesc.fragmentFunction = library.makeFunction(name: "toolpath_fragment")
        toolpathDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        toolpathDesc.colorAttachments[0].isBlendingEnabled = true
        toolpathDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        toolpathDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        toolpathDesc.depthAttachmentPixelFormat = .depth32Float

        do {
            gouraudPipeline = try device.makeRenderPipelineState(descriptor: gouraudDesc)
            flatPipeline = try device.makeRenderPipelineState(descriptor: flatDesc)
            gridPipeline = try device.makeRenderPipelineState(descriptor: gridDesc)
            toolpathPipeline = try device.makeRenderPipelineState(descriptor: toolpathDesc)
            return true
        } catch {
            print("Failed to create pipeline states: \(error)")
            return false
        }
    }

    private func buildDepthStates() {
        let desc = MTLDepthStencilDescriptor()
        desc.depthCompareFunction = .less
        desc.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: desc)

        let transDesc = MTLDepthStencilDescriptor()
        transDesc.depthCompareFunction = .less
        transDesc.isDepthWriteEnabled = false
        transparentDepthState = device.makeDepthStencilState(descriptor: transDesc)
    }

    private static func vertexDescriptor() -> MTLVertexDescriptor {
        let desc = MTLVertexDescriptor()
        // position
        desc.attributes[0].format = .float3
        desc.attributes[0].offset = 0
        desc.attributes[0].bufferIndex = 0
        // normal
        desc.attributes[1].format = .float3
        desc.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        desc.attributes[1].bufferIndex = 0
        // color
        desc.attributes[2].format = .float4
        desc.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride * 2
        desc.attributes[2].bufferIndex = 0
        // texCoord
        desc.attributes[3].format = .float2
        desc.attributes[3].offset = MemoryLayout<SIMD3<Float>>.stride * 2 + MemoryLayout<SIMD4<Float>>.stride
        desc.attributes[3].bufferIndex = 0
        // layout
        desc.layouts[0].stride = MemoryLayout<OrcaVertex>.stride
        desc.layouts[0].stepRate = 1
        desc.layouts[0].stepFunction = .perVertex
        return desc
    }

    // MARK: - Lighting Setup

    private func setupDefaultLighting() {
        // Match desktop OrcaSlicer gouraud shader constants exactly
        let intensityCorrection: Float = 0.6

        sceneUniforms.lightTopDir = normalize(SIMD3<Float>(-0.4574957, 0.4574957, 0.7624929))
        sceneUniforms.lightTopDiffuse = 0.8 * intensityCorrection
        sceneUniforms.lightTopSpecular = 0.125 * intensityCorrection
        sceneUniforms.lightTopShininess = 20.0
        sceneUniforms.lightFrontDir = normalize(SIMD3<Float>(0.6985074, 0.1397015, 0.6985074))
        sceneUniforms.lightFrontDiffuse = 0.3 * intensityCorrection
        sceneUniforms.ambientIntensity = 0.3
    }

    // MARK: - Grid

    private func rebuildGrid() {
        let hw = buildPlateSize.x / 2
        let hd = buildPlateSize.y / 2
        let vertices: [OrcaVertex] = [
            OrcaVertex(position: SIMD3(-hw, 0, -hd), normal: SIMD3(0, 1, 0), color: SIMD4(0, 0, 0, 0), texCoord: SIMD2(0, 0)),
            OrcaVertex(position: SIMD3( hw, 0, -hd), normal: SIMD3(0, 1, 0), color: SIMD4(0, 0, 0, 0), texCoord: SIMD2(1, 0)),
            OrcaVertex(position: SIMD3(-hw, 0,  hd), normal: SIMD3(0, 1, 0), color: SIMD4(0, 0, 0, 0), texCoord: SIMD2(0, 1)),
            OrcaVertex(position: SIMD3( hw, 0, -hd), normal: SIMD3(0, 1, 0), color: SIMD4(0, 0, 0, 0), texCoord: SIMD2(1, 0)),
            OrcaVertex(position: SIMD3( hw, 0,  hd), normal: SIMD3(0, 1, 0), color: SIMD4(0, 0, 0, 0), texCoord: SIMD2(1, 1)),
            OrcaVertex(position: SIMD3(-hw, 0,  hd), normal: SIMD3(0, 1, 0), color: SIMD4(0, 0, 0, 0), texCoord: SIMD2(0, 1)),
        ]
        gridBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<OrcaVertex>.stride * vertices.count)
    }

    // MARK: - Volume Management

    func addVolume(_ volume: RenderVolume) {
        volumes.append(volume)
    }

    func removeVolume(at index: Int) {
        guard index < volumes.count else { return }
        volumes.remove(at: index)
    }

    func clearVolumes() {
        volumes.removeAll()
    }

    /// Load triangle mesh data into a render volume
    func loadMesh(vertices: [SIMD3<Float>], normals: [SIMD3<Float>], color: SIMD4<Float>) -> RenderVolume? {
        guard vertices.count == normals.count, !vertices.isEmpty else { return nil }

        var orcaVertices: [OrcaVertex] = []
        orcaVertices.reserveCapacity(vertices.count)

        for i in 0..<vertices.count {
            orcaVertices.append(OrcaVertex(
                position: vertices[i],
                normal: normals[i],
                color: SIMD4(0, 0, 0, 0), // Use instance color
                texCoord: SIMD2(0, 0)
            ))
        }

        guard let vertexBuffer = device.makeBuffer(
            bytes: orcaVertices,
            length: MemoryLayout<OrcaVertex>.stride * orcaVertices.count
        ) else { return nil }

        let volume = RenderVolume(
            vertexBuffer: vertexBuffer,
            vertexCount: vertices.count,
            color: color,
            transform: matrix_identity_float4x4
        )

        return volume
    }

    /// Load mesh with per-vertex colors (for multi-color models)
    func loadColoredMesh(vertices: [SIMD3<Float>], normals: [SIMD3<Float>], colors: [SIMD4<Float>]) -> RenderVolume? {
        guard vertices.count == normals.count,
              vertices.count == colors.count,
              !vertices.isEmpty else { return nil }

        var orcaVertices: [OrcaVertex] = []
        orcaVertices.reserveCapacity(vertices.count)

        for i in 0..<vertices.count {
            orcaVertices.append(OrcaVertex(
                position: vertices[i],
                normal: normals[i],
                color: colors[i],
                texCoord: SIMD2(0, 0)
            ))
        }

        guard let vertexBuffer = device.makeBuffer(
            bytes: orcaVertices,
            length: MemoryLayout<OrcaVertex>.stride * orcaVertices.count
        ) else { return nil }

        return RenderVolume(
            vertexBuffer: vertexBuffer,
            vertexCount: vertices.count,
            color: SIMD4(1, 0.5, 0, 1), // Fallback color
            transform: matrix_identity_float4x4
        )
    }

    /// Set toolpath data for G-code visualization
    func setToolpath(vertices: [ToolpathVertex]) {
        guard !vertices.isEmpty else {
            toolpathBuffer = nil
            toolpathVertexCount = 0
            return
        }
        toolpathBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<ToolpathVertex>.stride * vertices.count
        )
        toolpathVertexCount = vertices.count
    }

    // MARK: - Camera

    var cameraState: Camera {
        get { camera }
        set { camera = newValue }
    }

    func resetCamera() {
        camera = Camera()
        camera.position = SIMD3(0, 150, 300)
        camera.target = SIMD3(0, 50, 0)
    }

    func orbit(deltaX: Float, deltaY: Float) {
        camera.orbit(dx: deltaX, dy: deltaY)
    }

    func pan(deltaX: Float, deltaY: Float) {
        camera.pan(dx: deltaX, dy: deltaY)
    }

    func zoom(delta: Float) {
        camera.zoom(delta: delta)
    }

    func zoomToFit() {
        guard !volumes.isEmpty else { return }
        var minBound = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxBound = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)

        for volume in volumes {
            let vMin = volume.boundingBoxMin
            let vMax = volume.boundingBoxMax
            minBound = min(minBound, vMin)
            maxBound = max(maxBound, vMax)
        }

        let center = (minBound + maxBound) * 0.5
        let size = length(maxBound - minBound)
        camera.target = center
        camera.position = center + SIMD3(0, size * 0.4, size * 0.8)
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        camera.aspectRatio = Float(size.width / size.height)
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let passDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        // Set clear color
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: Double(backgroundColor.x),
            green: Double(backgroundColor.y),
            blue: Double(backgroundColor.z),
            alpha: Double(backgroundColor.w)
        )

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }

        // Update scene uniforms
        updateSceneUniforms()

        // 1. Render build plate grid
        renderGrid(encoder: encoder)

        // 2. Render opaque volumes
        encoder.setDepthStencilState(depthState)
        encoder.setRenderPipelineState(gouraudPipeline)

        for (index, volume) in volumes.enumerated() where volume.isVisible && volume.color.w >= 1.0 {
            renderVolume(volume, index: index, encoder: encoder)
        }

        // 3. Render transparent volumes
        encoder.setDepthStencilState(transparentDepthState)
        for (index, volume) in volumes.enumerated() where volume.isVisible && volume.color.w < 1.0 {
            renderVolume(volume, index: index, encoder: encoder)
        }

        // 4. Render toolpath
        if toolpathBuffer != nil {
            renderToolpath(encoder: encoder)
        }

        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()

        onFrameRendered?()
    }

    // MARK: - Render Passes

    private func updateSceneUniforms() {
        sceneUniforms.viewMatrix = camera.viewMatrix
        sceneUniforms.projectionMatrix = camera.projectionMatrix
        sceneUniforms.viewProjectionMatrix = camera.projectionMatrix * camera.viewMatrix
        sceneUniforms.cameraPosition = camera.position
        sceneUniforms.zRange = zRange
        sceneUniforms.clippingPlane = clippingPlane
        sceneUniforms.slopeActive = slopeDetectionEnabled ? 1 : 0
        sceneUniforms.slopeNormalZ = slopeThreshold
    }

    private func renderVolume(_ volume: RenderVolume, index: Int, encoder: MTLRenderCommandEncoder) {
        var instanceUniforms = InstanceUniforms(
            modelMatrix: volume.transform,
            normalMatrix: volume.normalMatrix,
            color: volume.color,
            selected: (selectedVolumeIndex == index) ? 1 : 0,
            hovered: (hoveredVolumeIndex == index) ? 1 : 0,
            padding: SIMD2(0, 0)
        )

        encoder.setVertexBuffer(volume.vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&sceneUniforms, length: MemoryLayout<SceneUniforms>.stride, index: 1)
        encoder.setVertexBytes(&instanceUniforms, length: MemoryLayout<InstanceUniforms>.stride, index: 2)
        encoder.setFragmentBytes(&sceneUniforms, length: MemoryLayout<SceneUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&instanceUniforms, length: MemoryLayout<InstanceUniforms>.stride, index: 2)

        if let indexBuffer = volume.indexBuffer {
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: volume.indexCount,
                indexType: .uint32,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0
            )
        } else {
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: volume.vertexCount)
        }
    }

    private func renderGrid(encoder: MTLRenderCommandEncoder) {
        guard let buffer = gridBuffer else { return }

        encoder.setRenderPipelineState(gridPipeline)
        encoder.setDepthStencilState(depthState)

        var gridUniforms = GridUniforms(
            modelViewProjection: sceneUniforms.viewProjectionMatrix,
            gridColor: SIMD4(0.4, 0.4, 0.4, 0.8),
            gridSpacing: gridSpacing,
            gridLineWidth: 0.3,
            plateWidth: buildPlateSize.x,
            plateDepth: buildPlateSize.y
        )

        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setVertexBytes(&gridUniforms, length: MemoryLayout<GridUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&gridUniforms, length: MemoryLayout<GridUniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }

    private func renderToolpath(encoder: MTLRenderCommandEncoder) {
        guard let buffer = toolpathBuffer, toolpathVertexCount > 0 else { return }

        encoder.setRenderPipelineState(toolpathPipeline)
        encoder.setDepthStencilState(depthState)

        var uniforms = ToolpathUniforms(
            viewProjection: sceneUniforms.viewProjectionMatrix,
            lineWidth: 1.0,
            layerHeight: 0.2,
            currentLayer: currentToolpathLayer,
            totalLayers: totalToolpathLayers,
            showTravel: showTravelMoves ? 1 : 0,
            showRetractions: showRetractions ? 1 : 0,
            _pad: SIMD2(0, 0)
        )

        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<ToolpathUniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: toolpathVertexCount)
    }
}

// MARK: - RenderVolume

/// Represents a single 3D volume (model part) to be rendered.
final class RenderVolume {
    let vertexBuffer: MTLBuffer
    let vertexCount: Int
    var indexBuffer: MTLBuffer?
    var indexCount: Int = 0
    var color: SIMD4<Float>
    var transform: simd_float4x4
    var isVisible: Bool = true
    var boundingBoxMin: SIMD3<Float> = .zero
    var boundingBoxMax: SIMD3<Float> = .zero

    var normalMatrix: simd_float3x3 {
        let upper3x3 = simd_float3x3(
            SIMD3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
            SIMD3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
            SIMD3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        )
        return upper3x3.inverse.transpose
    }

    init(vertexBuffer: MTLBuffer, vertexCount: Int, color: SIMD4<Float>, transform: simd_float4x4) {
        self.vertexBuffer = vertexBuffer
        self.vertexCount = vertexCount
        self.color = color
        self.transform = transform
    }
}

// MARK: - Camera

struct Camera {
    var position: SIMD3<Float> = SIMD3(0, 150, 300)
    var target: SIMD3<Float> = SIMD3(0, 50, 0)
    var up: SIMD3<Float> = SIMD3(0, 1, 0)
    var fov: Float = 45.0 // degrees
    var aspectRatio: Float = 1.0
    var nearPlane: Float = 0.1
    var farPlane: Float = 10000.0

    var viewMatrix: simd_float4x4 {
        lookAt(eye: position, center: target, up: up)
    }

    var projectionMatrix: simd_float4x4 {
        perspective(fovRadians: fov * .pi / 180.0, aspect: aspectRatio, near: nearPlane, far: farPlane)
    }

    mutating func orbit(dx: Float, dy: Float) {
        let sensitivity: Float = 0.005
        let offset = position - target
        let radius = length(offset)

        // Spherical coordinates
        var theta = atan2(offset.x, offset.z) + dx * sensitivity
        var phi = acos(clamp(offset.y / radius, -1, 1)) + dy * sensitivity

        // Clamp phi to avoid gimbal lock
        phi = clamp(phi, 0.01, .pi - 0.01)

        position = target + SIMD3(
            radius * sin(phi) * sin(theta),
            radius * cos(phi),
            radius * sin(phi) * cos(theta)
        )
    }

    mutating func pan(dx: Float, dy: Float) {
        let sensitivity: Float = 0.5
        let forward = normalize(target - position)
        let right = normalize(cross(forward, up))
        let upVec = cross(right, forward)

        let offset = right * (-dx * sensitivity) + upVec * (dy * sensitivity)
        position += offset
        target += offset
    }

    mutating func zoom(delta: Float) {
        let direction = normalize(target - position)
        let distance = length(target - position)
        let moveAmount = delta * distance * 0.1
        let newPos = position + direction * moveAmount

        // Don't zoom past target
        if length(newPos - target) > 1.0 {
            position = newPos
        }
    }

    // MARK: - Matrix Math

    private func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let f = normalize(center - eye)
        let s = normalize(cross(f, up))
        let u = cross(s, f)

        var result = matrix_identity_float4x4
        result.columns.0 = SIMD4(s.x, u.x, -f.x, 0)
        result.columns.1 = SIMD4(s.y, u.y, -f.y, 0)
        result.columns.2 = SIMD4(s.z, u.z, -f.z, 0)
        result.columns.3 = SIMD4(-dot(s, eye), -dot(u, eye), dot(f, eye), 1)
        return result
    }

    private func perspective(fovRadians: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let y = 1 / tan(fovRadians * 0.5)
        let x = y / aspect
        let z = far / (near - far)

        var result = simd_float4x4(0)
        result.columns.0.x = x
        result.columns.1.y = y
        result.columns.2.z = z
        result.columns.2.w = -1
        result.columns.3.z = z * near
        return result
    }
}

// MARK: - Utility

private func clamp<T: Comparable>(_ value: T, _ minimum: T, _ maximum: T) -> T {
    min(max(value, minimum), maximum)
}
