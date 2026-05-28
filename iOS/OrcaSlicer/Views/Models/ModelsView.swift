import SwiftUI
import UniformTypeIdentifiers

struct ModelsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isImporting = false
    @State private var searchText = ""

    private var filteredModels: [PrintModel] {
        if searchText.isEmpty {
            return appState.importedModels
        }
        return appState.importedModels.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if appState.importedModels.isEmpty {
                    emptyState
                } else {
                    modelList
                }
            }
            .navigationTitle("Models")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isImporting = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Import Model")
                }
            }
            .searchable(text: $searchText, prompt: "Search models")
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: supportedFileTypes,
                allowsMultipleSelection: true
            ) { result in
                handleImportResult(result)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Models", systemImage: "cube")
        } description: {
            Text("Import 3D models to get started with slicing.")
        } actions: {
            Button("Import Model") {
                isImporting = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var modelList: some View {
        List(selection: $appState.selectedModel) {
            ForEach(filteredModels) { model in
                ModelRowView(model: model)
                    .tag(model)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            appState.removeModel(model)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var supportedFileTypes: [UTType] {
        [
            UTType(filenameExtension: "stl") ?? .data,
            UTType(filenameExtension: "obj") ?? .data,
            UTType(filenameExtension: "3mf") ?? .data,
            UTType(filenameExtension: "step") ?? .data,
            UTType(filenameExtension: "stp") ?? .data,
        ]
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                // Copy to app's documents directory
                let documentsURL = FileManager.default.urls(
                    for: .documentDirectory, in: .userDomainMask
                ).first!
                let destination = documentsURL.appendingPathComponent(url.lastPathComponent)

                do {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: url, to: destination)
                    appState.importModel(from: destination)
                } catch {
                    // Handle error silently for now
                }
            }
        case .failure:
            break
        }
    }
}

struct ModelRowView: View {
    let model: PrintModel

    var body: some View {
        HStack(spacing: 12) {
            modelIcon
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(model.fileType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                    Text(model.dateAdded, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var modelIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.1))
                .frame(width: 48, height: 48)
            Image(systemName: "cube.fill")
                .font(.title2)
                .foregroundStyle(.accent)
        }
    }
}

#Preview {
    ModelsView()
        .environmentObject(AppState())
}
