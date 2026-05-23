import SwiftUI

/// App settings view for preferences, storage management, and app info.
struct AppSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @AppStorage("defaultLayerHeight") private var defaultLayerHeight: Double = 0.2
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedback: Bool = true
    @AppStorage("showTravelMoves") private var showTravelMoves: Bool = false
    @AppStorage("autoSliceOnChange") private var autoSliceOnChange: Bool = false
    @State private var showingAbout = false
    @State private var showingClearConfirmation = false
    @State private var storageUsed: String = "Calculating..."

    enum AppAppearance: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        var id: String { rawValue }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                displaySection
                slicingSection
                gcodeSection
                storageSection
                aboutSection
            }
            .navigationTitle("App Settings")
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .onAppear {
                calculateStorageUsage()
            }
        }
    }

    private var displaySection: some View {
        Section("Display") {
            Picker("Appearance", selection: $appearance) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            Toggle("Haptic Feedback", isOn: $hapticFeedback)
        }
    }

    private var slicingSection: some View {
        Section {
            Picker("Default Layer Height", selection: $defaultLayerHeight) {
                Text("0.08 mm (Ultra Fine)").tag(0.08)
                Text("0.12 mm (Fine)").tag(0.12)
                Text("0.16 mm (Optimal)").tag(0.16)
                Text("0.20 mm (Standard)").tag(0.20)
                Text("0.28 mm (Draft)").tag(0.28)
                Text("0.32 mm (Fast)").tag(0.32)
            }
            Toggle("Auto-Slice on Settings Change", isOn: $autoSliceOnChange)
        } header: {
            Text("Slicing")
        } footer: {
            Text("Auto-slice will automatically re-slice when print settings are modified.")
        }
    }

    private var gcodeSection: some View {
        Section("G-code Viewer") {
            Toggle("Show Travel Moves", isOn: $showTravelMoves)
        }
    }

    private var storageSection: some View {
        Section {
            HStack {
                Text("Models & G-code")
                Spacer()
                Text(storageUsed)
                    .foregroundStyle(.secondary)
            }
            Button("Clear All Cached Data", role: .destructive) {
                showingClearConfirmation = true
            }
            .confirmationDialog(
                "Clear All Data",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    clearStorageData()
                }
            } message: {
                Text("This will remove all imported models and cached G-code files. This action cannot be undone.")
            }
        } header: {
            Text("Storage")
        }
    }

    private var aboutSection: some View {
        Section {
            Button {
                showingAbout = true
            } label: {
                HStack {
                    Label("About OrcaSlicer", systemImage: "info.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .tint(.primary)
        }
    }

    private func calculateStorageUsage() {
        Task {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let tmpURL = FileManager.default.temporaryDirectory

            var totalSize: Int64 = 0
            for dir in [documentsURL, tmpURL] {
                if let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
                    for case let fileURL as URL in enumerator {
                        let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
                        totalSize += Int64(attrs?.fileSize ?? 0)
                    }
                }
            }

            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            storageUsed = formatter.string(fromByteCount: totalSize)
        }
    }

    private func clearStorageData() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        try? FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            .forEach { try? FileManager.default.removeItem(at: $0) }

        appState.importedModels.removeAll()
        appState.selectedModel = nil
        appState.sliceResult = nil
        calculateStorageUsage()
    }
}

#Preview {
    AppSettingsView()
        .environmentObject(AppState())
}
