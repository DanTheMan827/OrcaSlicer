import SwiftUI
import SceneKit

/// A 3D model viewer using SceneKit (Metal-based rendering).
/// Displays STL/OBJ models with standard 3D interaction gestures.
struct ModelViewer: UIViewRepresentable {
    let modelURL: URL?

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = .systemBackground
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = true
        sceneView.antialiasingMode = .multisampling4X

        let scene = SCNScene()

        // Add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 500
        ambientLight.light?.color = UIColor.white
        scene.rootNode.addChildNode(ambientLight)

        // Add directional light
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 800
        directionalLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(directionalLight)

        // Add build plate (grid)
        let gridNode = createBuildPlate()
        scene.rootNode.addChildNode(gridNode)

        // Camera
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
        // Remove existing model nodes
        sceneView.scene?.rootNode.childNodes
            .filter { $0.name == "importedModel" }
            .forEach { $0.removeFromParentNode() }

        // Load model if URL is available
        guard let url = modelURL else { return }

        loadModel(url: url, into: sceneView)
    }

    private func loadModel(url: URL, into sceneView: SCNView) {
        // For STL files, use a basic geometry loader
        // SceneKit natively supports .obj and .dae files
        let ext = url.pathExtension.lowercased()

        if ext == "obj" || ext == "dae" || ext == "usdz" {
            if let scene = try? SCNScene(url: url, options: [
                .checkConsistency: true
            ]) {
                let modelNode = SCNNode()
                modelNode.name = "importedModel"
                for child in scene.rootNode.childNodes {
                    modelNode.addChildNode(child.clone())
                }
                applyDefaultMaterial(to: modelNode)
                sceneView.scene?.rootNode.addChildNode(modelNode)
                centerModel(modelNode, in: sceneView)
            }
        } else {
            // For STL/3MF, we'd use the bridge to libslic3r to convert
            // For now, show a placeholder geometry
            let placeholder = SCNBox(width: 40, height: 40, length: 40, chamferRadius: 2)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemOrange
            material.lightingModel = .physicallyBased
            material.roughness.contents = 0.4
            material.metalness.contents = 0.1
            placeholder.materials = [material]

            let node = SCNNode(geometry: placeholder)
            node.name = "importedModel"
            node.position = SCNVector3(0, 20, 0)
            sceneView.scene?.rootNode.addChildNode(node)
        }
    }

    private func createBuildPlate() -> SCNNode {
        let plate = SCNBox(width: 220, height: 1, length: 220, chamferRadius: 0)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemGray5
        material.lightingModel = .physicallyBased
        plate.materials = [material]

        let node = SCNNode(geometry: plate)
        node.position = SCNVector3(0, -0.5, 0)
        return node
    }

    private func applyDefaultMaterial(to node: SCNNode) {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemOrange
        material.lightingModel = .physicallyBased
        material.roughness.contents = 0.4
        material.metalness.contents = 0.1

        node.enumerateChildNodes { child, _ in
            child.geometry?.materials = [material]
        }
    }

    private func centerModel(_ node: SCNNode, in sceneView: SCNView) {
        let (min, max) = node.boundingBox
        let center = SCNVector3(
            (min.x + max.x) / 2,
            min.y,
            (min.z + max.z) / 2
        )
        node.position = SCNVector3(-center.x, -center.y, -center.z)
    }
}

#Preview {
    ModelViewer(modelURL: nil)
        .frame(height: 400)
}
