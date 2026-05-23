import SwiftUI

struct ModelDetailView: View {
    @EnvironmentObject private var appState: AppState
    let model: PrintModel
    @State private var showDeleteConfirmation = false
    @State private var showTransformPanel = false
    @State private var transform: ModelTransform = .identity
    @State private var modelInfo: ModelInfo?

    struct ModelInfo {
        let vertexCount: Int
        let faceCount: Int
        let dimensions: (x: Float, y: Float, z: Float)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 3D Preview
            ModelViewer(modelURL: model.fileURL)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    viewerControls
                }
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
        VStack(spacing: 8) {
            Button {
                // Reset camera
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.body)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            Button {
                // Toggle wireframe
            } label: {
                Image(systemName: "square.grid.3x3")
                    .font(.body)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            Button {
                withAnimation {
                    showTransformPanel.toggle()
                }
            } label: {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.body)
                    .padding(10)
                    .background(showTransformPanel ? AnyShapeStyle(.accent.opacity(0.2)) : AnyShapeStyle(.ultraThinMaterial))
                    .clipShape(Circle())
            }
        }
        .padding()
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
        } catch {
            // Model info not available
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
