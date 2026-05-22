import SwiftUI

struct SliceView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingExportSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let model = appState.selectedModel {
                    // 3D Preview area
                    ModelViewer(modelURL: model.fileURL)
                        .frame(maxHeight: .infinity)
                        .overlay(alignment: .top) {
                            if appState.isSlicing {
                                slicingProgressOverlay
                            }
                        }

                    // Bottom control panel
                    sliceControlPanel(for: model)
                } else {
                    noModelSelected
                }
            }
            .navigationTitle("Slice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if appState.sliceResult?.isSuccess == true {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingExportSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                if let gcodeURL = appState.sliceResult?.gcodeURL {
                    ShareSheet(items: [gcodeURL])
                }
            }
        }
    }

    private var noModelSelected: some View {
        ContentUnavailableView {
            Label("No Model Selected", systemImage: "cube.transparent")
        } description: {
            Text("Select a model from the Models tab to begin slicing.")
        }
    }

    private var slicingProgressOverlay: some View {
        VStack(spacing: 12) {
            ProgressView(value: appState.sliceProgress) {
                Text("Slicing...")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(Int(appState.sliceProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .progressViewStyle(.linear)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    private func sliceControlPanel(for model: PrintModel) -> some View {
        VStack(spacing: 12) {
            // Slice result summary
            if let result = appState.sliceResult {
                if result.isSuccess {
                    sliceResultSummary(result)
                } else if let error = result.error {
                    errorBanner(error)
                }
            }

            // Model and printer info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.headline)
                    if let printer = appState.selectedPrinter {
                        Text(printer.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No printer selected")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
                sliceButton
            }
        }
        .padding()
        .background(.bar)
    }

    private func sliceResultSummary(_ result: SliceResult) -> some View {
        HStack(spacing: 16) {
            Label(result.formattedTime, systemImage: "clock")
                .font(.subheadline)
            Label(result.formattedFilament, systemImage: "line.3.crossed.swirl.circle")
                .font(.subheadline)
            Label("\(result.layerCount) layers", systemImage: "square.stack.3d.up")
                .font(.subheadline)
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func errorBanner(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var sliceButton: some View {
        Button {
            Task {
                await appState.slice()
            }
        } label: {
            if appState.isSlicing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, 8)
            } else {
                Text("Slice")
                    .fontWeight(.semibold)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(appState.isSlicing || appState.selectedPrinter == nil)
    }
}

/// UIKit share sheet wrapper for SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SliceView()
        .environmentObject(AppState())
}
