import SwiftUI
import MetalKit

/// SwiftUI view wrapping the Metal-based 3D renderer.
/// Provides full desktop-equivalent rendering with gesture controls for
/// orbit, pan, and zoom (matching GLCanvas3D interaction on desktop).
struct MetalModelView: UIViewRepresentable {
    @Binding var meshData: MeshRenderData?
    @Binding var toolpathData: [ToolpathVertex]?
    @Binding var selectedVolumeIndex: Int?
    @Binding var slopeDetectionEnabled: Bool
    @Binding var clippingZ: Float
    @Binding var currentLayer: Float

    var buildPlateWidth: Float = 256
    var buildPlateDepth: Float = 256
    var onRendererReady: ((OrcaRenderer) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearColor = MTLClearColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.sampleCount = 4 // MSAA 4x

        guard let renderer = OrcaRenderer(device: device) else {
            fatalError("Failed to create OrcaRenderer")
        }

        renderer.buildPlateSize = SIMD2(buildPlateWidth, buildPlateDepth)
        renderer.resetCamera()
        mtkView.delegate = renderer

        context.coordinator.renderer = renderer
        context.coordinator.mtkView = mtkView
        context.coordinator.setupGestures(on: mtkView)

        onRendererReady?(renderer)

        return mtkView
    }

    func updateUIView(_ mtkView: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }

        // Update mesh data if changed
        if let mesh = meshData, mesh.id != context.coordinator.lastMeshId {
            context.coordinator.lastMeshId = mesh.id
            renderer.clearVolumes()

            for volumeData in mesh.volumes {
                if let volume = renderer.loadMesh(
                    vertices: volumeData.vertices,
                    normals: volumeData.normals,
                    color: volumeData.color
                ) {
                    volume.transform = volumeData.transform
                    volume.boundingBoxMin = volumeData.boundingBoxMin
                    volume.boundingBoxMax = volumeData.boundingBoxMax
                    renderer.addVolume(volume)
                }
            }
            renderer.zoomToFit()
        }

        // Update toolpath
        if let toolpath = toolpathData {
            renderer.setToolpath(vertices: toolpath)
            renderer.totalToolpathLayers = Float(toolpath.last?.layerIndex ?? 0)
        }

        // Update state
        renderer.selectedVolumeIndex = selectedVolumeIndex
        renderer.slopeDetectionEnabled = slopeDetectionEnabled
        renderer.zRange = SIMD2(-10000, clippingZ)
        renderer.currentToolpathLayer = currentLayer
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject {
        var renderer: OrcaRenderer?
        var mtkView: MTKView?
        var lastMeshId: UUID?

        // Gesture state
        private var lastPanLocation: CGPoint = .zero
        private var lastScale: CGFloat = 1.0

        func setupGestures(on view: MTKView) {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.minimumNumberOfTouches = 1
            pan.maximumNumberOfTouches = 1
            view.addGestureRecognizer(pan)

            let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
            twoFingerPan.minimumNumberOfTouches = 2
            twoFingerPan.maximumNumberOfTouches = 2
            view.addGestureRecognizer(twoFingerPan)

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            view.addGestureRecognizer(pinch)

            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            view.addGestureRecognizer(doubleTap)
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            renderer?.orbit(deltaX: Float(translation.x), deltaY: Float(translation.y))
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc private func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            renderer?.pan(deltaX: Float(translation.x), deltaY: Float(translation.y))
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            let scale = Float(gesture.scale - 1.0) * 2.0
            renderer?.zoom(delta: scale)
            gesture.scale = 1.0
        }

        @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            renderer?.zoomToFit()
        }
    }
}

// MARK: - Mesh Data Model

/// Data structure holding mesh information for rendering
struct MeshRenderData: Identifiable {
    let id: UUID
    let volumes: [VolumeRenderData]

    init(volumes: [VolumeRenderData]) {
        self.id = UUID()
        self.volumes = volumes
    }
}

/// Single volume (part) of a mesh
struct VolumeRenderData {
    let vertices: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let color: SIMD4<Float>
    var transform: simd_float4x4
    var boundingBoxMin: SIMD3<Float>
    var boundingBoxMax: SIMD3<Float>

    init(vertices: [SIMD3<Float>], normals: [SIMD3<Float>], color: SIMD4<Float>) {
        self.vertices = vertices
        self.normals = normals
        self.color = color
        self.transform = matrix_identity_float4x4

        // Compute bounding box
        var minB = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxB = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for v in vertices {
            minB = min(minB, v)
            maxB = max(maxB, v)
        }
        self.boundingBoxMin = minB
        self.boundingBoxMax = maxB
    }
}
