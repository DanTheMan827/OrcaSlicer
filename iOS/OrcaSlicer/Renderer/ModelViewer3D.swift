import SwiftUI
import MetalKit

/// Full-featured 3D model viewer using the Metal renderer.
/// Provides desktop-equivalent rendering with Gouraud shading, build plate,
/// toolpath visualization, and interactive camera controls.
///
/// Gesture controls:
/// - Single finger drag: Orbit camera
/// - Two finger drag: Pan camera
/// - Pinch: Zoom in/out
/// - Double tap: Zoom to fit model
struct ModelViewer3D: View {
    let meshData: MeshRenderData?
    var toolpathData: [ToolpathVertex]? = nil
    var buildPlateWidth: Float = 256
    var buildPlateDepth: Float = 256

    @State private var selectedVolume: Int? = nil
    @State private var slopeDetection: Bool = false
    @State private var clippingZ: Float = 10000
    @State private var currentLayer: Float = 0
    @State private var showControls: Bool = false
    @State private var renderer: OrcaRenderer?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MetalModelView(
                meshData: .constant(meshData),
                toolpathData: .constant(toolpathData),
                selectedVolumeIndex: $selectedVolume,
                slopeDetectionEnabled: $slopeDetection,
                clippingZ: $clippingZ,
                currentLayer: $currentLayer,
                buildPlateWidth: buildPlateWidth,
                buildPlateDepth: buildPlateDepth,
                onRendererReady: { r in renderer = r }
            )

            // Overlay controls
            VStack(spacing: 8) {
                Button(action: { showControls.toggle() }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }

                if showControls {
                    viewControlsPanel
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var viewControlsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // View mode buttons
            HStack(spacing: 12) {
                viewButton(icon: "cube", label: "Reset") {
                    renderer?.resetCamera()
                }
                viewButton(icon: "arrow.up.left.and.arrow.down.right", label: "Fit") {
                    renderer?.zoomToFit()
                }
            }

            Divider()

            // Slope detection
            Toggle(isOn: $slopeDetection) {
                Label("Slope Detection", systemImage: "mountain.2")
                    .font(.caption)
            }
            .toggleStyle(.switch)

            // Clipping plane (if model loaded)
            if meshData != nil {
                VStack(alignment: .leading) {
                    Text("Clip Z: \(Int(clippingZ))")
                        .font(.caption2)
                    Slider(value: $clippingZ, in: 0...500)
                }
            }

            // Layer slider (if toolpath loaded)
            if toolpathData != nil {
                VStack(alignment: .leading) {
                    Text("Layer: \(Int(currentLayer))")
                        .font(.caption2)
                    Slider(value: $currentLayer, in: 0...max(1, Float(toolpathData?.last?.layerIndex ?? 1)))
                }
            }
        }
        .padding()
        .frame(width: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func viewButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(width: 50, height: 50)
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - Legacy ModelViewer (SceneKit fallback)

import SceneKit

/// Fallback SceneKit-based viewer for simple model display
/// when Metal renderer is not needed (thumbnails, etc.)
struct ModelViewer: UIViewRepresentable {
    let modelURL: URL?

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = .systemBackground
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = true
        sceneView.antialiasingMode = .multisampling4X

        let scene = SCNScene()

        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 500
        scene.rootNode.addChildNode(ambientLight)

        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 800
        directionalLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(directionalLight)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 10000
        cameraNode.position = SCNVector3(0, 150, 300)
        cameraNode.look(at: SCNVector3(0, 50, 0))
        scene.rootNode.addChildNode(cameraNode)

        sceneView.scene = scene
        sceneView.pointOfView = cameraNode

        return sceneView
    }

    func updateUIView(_ sceneView: SCNView, context: Context) {
        sceneView.scene?.rootNode.childNodes
            .filter { $0.name == "importedModel" }
            .forEach { $0.removeFromParentNode() }

        guard let url = modelURL else { return }
        loadModel(url: url, into: sceneView)
    }

    private func loadModel(url: URL, into sceneView: SCNView) {
        let ext = url.pathExtension.lowercased()

        if ext == "obj" || ext == "dae" || ext == "usdz" {
            if let scene = try? SCNScene(url: url, options: [.checkConsistency: true]) {
                let modelNode = SCNNode()
                modelNode.name = "importedModel"
                for child in scene.rootNode.childNodes {
                    modelNode.addChildNode(child.clone())
                }
                sceneView.scene?.rootNode.addChildNode(modelNode)
            }
        }
    }
}

#Preview {
    ModelViewer3D(meshData: nil)
}
