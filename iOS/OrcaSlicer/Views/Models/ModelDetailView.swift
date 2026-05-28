import SwiftUI

struct ModelDetailView: View {
    @EnvironmentObject private var appState: AppState
    let model: PrintModel
    @State private var showDeleteConfirmation = false
    @State private var showTransformPanel = false
    @State private var transform: ModelTransform = .identity
    @State private var modelInfo: ModelInfo?

    @State private var meshRenderData: MeshRenderData?

    struct ModelInfo {
        let vertexCount: Int
        let faceCount: Int
        let dimensions: (x: Float, y: Float, z: Float)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 3D Preview - use Metal renderer when mesh data available
            Group {
                if meshRenderData != nil {
                    ModelViewer3D(
                        meshData: meshRenderData,
                        buildPlateWidth: Float(appState.selectedPrinter?.buildPlateWidth ?? 256),
                        buildPlateDepth: Float(appState.selectedPrinter?.buildPlateDepth ?? 256)
                    )
                } else {
                    ModelViewer(modelURL: model.fileURL)
                }
            }
            .frame(maxHeight: .infinity)
            .overlay(alignment: .bottomLeading) {
                if let info = modelInfo {
                    modelDimensionsOverlay(info)
                }
            }

            // Transform panel (collapsible)
            if showTransformPanel {
                ModelTransformView(transform: $transform)
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Model info bar
            modelInfoBar
        }
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        withAnimation {
                            showTransformPanel.toggle()
                        }
                    } label: {
                        Label(
                            showTransformPanel ? "Hide Transform" : "Transform",
                            systemImage: "arrow.up.and.down.and.arrow.left.and.right"
                        )
                    }
                    Button {
                        // Share the model file
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        // Duplicate model
                        appState.importModel(from: model.fileURL)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Delete Model",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                appState.removeModel(model)
            }
        } message: {
            Text("Are you sure you want to remove \"\(model.name)\" from your library?")
        }
        .task {
            await loadModelInfo()
        }
    }

    private var viewerControls: some View {
        EmptyView() // Controls are now part of ModelViewer3D
    }

    private func modelDimensionsOverlay(_ info: ModelInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(info.faceCount) faces")
                .font(.caption2.monospacedDigit())
            Text(String(format: "%.1f × %.1f × %.1f mm", info.dimensions.x, info.dimensions.y, info.dimensions.z))
                .font(.caption2.monospacedDigit())
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
        .padding(8)
    }

    private var modelInfoBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.headline)
                Text(model.fileType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Slice") {
                appState.selectedModel = model
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding()
        .background(.bar)
    }

    private func loadModelInfo() async {
        guard model.fileType == .stl else { return }
        do {
            let mesh = try STLParser.parse(url: model.fileURL)
            modelInfo = ModelInfo(
                vertexCount: mesh.vertexCount,
                faceCount: mesh.faceCount,
                dimensions: (mesh.dimensions.x, mesh.dimensions.y, mesh.dimensions.z)
            )

            // Build Metal render data from parsed STL
            var vertices: [SIMD3<Float>] = []
            var normals: [SIMD3<Float>] = []
            vertices.reserveCapacity(mesh.triangles.count * 3)
            normals.reserveCapacity(mesh.triangles.count * 3)

            for triangle in mesh.triangles {
                let n = SIMD3<Float>(triangle.normal.x, triangle.normal.y, triangle.normal.z)
                for vertex in triangle.vertices {
                    vertices.append(SIMD3<Float>(vertex.x, vertex.y, vertex.z))
                    normals.append(n)
                }
            }

            let volumeData = VolumeRenderData(
                vertices: vertices,
                normals: normals,
                color: SIMD4<Float>(1.0, 0.5, 0.0, 1.0) // OrcaSlicer orange
            )
            meshRenderData = MeshRenderData(volumes: [volumeData])
        } catch {
            // Model info not available, fallback to SceneKit viewer
        }
    }
}

#Preview {
    NavigationStack {
        ModelDetailView(model: PrintModel(
            id: UUID(),
            name: "Benchy",
            fileURL: URL(fileURLWithPath: "/tmp/benchy.stl"),
            fileType: .stl,
            dateAdded: Date(),
            thumbnail: nil
        ))
    }
    .environmentObject(AppState())
}
