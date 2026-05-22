import SwiftUI

struct ModelDetailView: View {
    @EnvironmentObject private var appState: AppState
    let model: PrintModel
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // 3D Preview
            ModelViewer(modelURL: model.fileURL)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    viewerControls
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
                        // Share the model file
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        // Duplicate model
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
        }
        .padding()
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
