import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedPreset: ProfilePreset = .standard
    @State private var showingCustomProfile = false

    enum ProfilePreset: String, CaseIterable, Identifiable {
        case draft = "Draft"
        case standard = "Standard"
        case quality = "Quality"
        case custom = "Custom"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .draft: return "0.3mm layers, fast print"
            case .standard: return "0.2mm layers, balanced"
            case .quality: return "0.12mm layers, fine detail"
            case .custom: return "Custom settings"
            }
        }

        var icon: String {
            switch self {
            case .draft: return "hare"
            case .standard: return "equal.circle"
            case .quality: return "sparkles"
            case .custom: return "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                qualitySection
                strengthSection
                speedSection
                temperatureSection
                supportSection
                adhesionSection
                retractionSection
            }
            .navigationTitle("Print Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Save Profile") {}
                        Button("Load Profile") {}
                        Divider()
                        Button("Reset to Default") {
                            appState.currentProfile = .default
                            selectedPreset = .standard
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section {
            Picker("Quality Preset", selection: $selectedPreset) {
                ForEach(ProfilePreset.allCases) { preset in
                    Label {
                        VStack(alignment: .leading) {
                            Text(preset.rawValue)
                            Text(preset.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: preset.icon)
                    }
                    .tag(preset)
                }
            }
            .pickerStyle(.inline)
            .onChange(of: selectedPreset) { _, newValue in
                applyPreset(newValue)
            }
        } header: {
            Text("Profile")
        }
    }

    private var qualitySection: some View {
        Section {
            HStack {
                Text("Layer Height")
                Spacer()
                Text("\(appState.currentProfile.layerHeight, specifier: "%.2f") mm")
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: $appState.currentProfile.layerHeight,
                in: 0.04...0.4,
                step: 0.02
            )

            HStack {
                Text("First Layer Height")
                Spacer()
                Text("\(appState.currentProfile.firstLayerHeight, specifier: "%.2f") mm")
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: $appState.currentProfile.firstLayerHeight,
                in: 0.1...0.4,
                step: 0.02
            )
        } header: {
            Text("Quality")
        } footer: {
            Text("Smaller layer heights produce finer details but increase print time.")
        }
    }

    private var strengthSection: some View {
        Section {
            Stepper("Wall Loops: \(appState.currentProfile.wallLoops)",
                    value: $appState.currentProfile.wallLoops, in: 1...10)

            Stepper("Top Layers: \(appState.currentProfile.topShellLayers)",
                    value: $appState.currentProfile.topShellLayers, in: 1...20)

            Stepper("Bottom Layers: \(appState.currentProfile.bottomShellLayers)",
                    value: $appState.currentProfile.bottomShellLayers, in: 1...20)

            HStack {
                Text("Infill Density")
                Spacer()
                Text("\(appState.currentProfile.infillDensity, specifier: "%.0f")%")
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: $appState.currentProfile.infillDensity,
                in: 0...100,
                step: 5
            )

            Picker("Infill Pattern", selection: $appState.currentProfile.infillPattern) {
                ForEach(PrintProfile.InfillPattern.allCases) { pattern in
                    Text(pattern.rawValue).tag(pattern)
                }
            }
        } header: {
            Text("Strength")
        }
    }

    private var speedSection: some View {
        Section {
            HStack {
                Text("Print Speed")
                Spacer()
                Text("\(appState.currentProfile.printSpeed, specifier: "%.0f") mm/s")
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: $appState.currentProfile.printSpeed,
                in: 20...300,
                step: 10
            )

            HStack {
                Text("Travel Speed")
                Spacer()
                Text("\(appState.currentProfile.travelSpeed, specifier: "%.0f") mm/s")
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: $appState.currentProfile.travelSpeed,
                in: 50...500,
                step: 10
            )
        } header: {
            Text("Speed")
        }
    }

    private var temperatureSection: some View {
        Section {
            Stepper("Nozzle: \(appState.currentProfile.nozzleTemperature)°C",
                    value: $appState.currentProfile.nozzleTemperature, in: 170...350)

            Stepper("First Layer Nozzle: \(appState.currentProfile.firstLayerNozzleTemperature)°C",
                    value: $appState.currentProfile.firstLayerNozzleTemperature, in: 170...350)

            Stepper("Bed: \(appState.currentProfile.bedTemperature)°C",
                    value: $appState.currentProfile.bedTemperature, in: 0...150)

            Stepper("First Layer Bed: \(appState.currentProfile.firstLayerBedTemperature)°C",
                    value: $appState.currentProfile.firstLayerBedTemperature, in: 0...150)

            HStack {
                Text("Fan Speed")
                Spacer()
                Text("\(appState.currentProfile.fanSpeed)%")
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(appState.currentProfile.fanSpeed) },
                    set: { appState.currentProfile.fanSpeed = Int($0) }
                ),
                in: 0...100,
                step: 5
            )
        } header: {
            Text("Temperature")
        }
    }

    private var supportSection: some View {
        Section {
            Toggle("Enable Support", isOn: $appState.currentProfile.supportEnabled)

            if appState.currentProfile.supportEnabled {
                Picker("Support Type", selection: $appState.currentProfile.supportType) {
                    ForEach(PrintProfile.SupportType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }
        } header: {
            Text("Support")
        } footer: {
            Text("Supports are temporary structures that hold up overhanging parts of the model.")
        }
    }

    private var adhesionSection: some View {
        Section {
            Picker("Adhesion Type", selection: $appState.currentProfile.adhesionType) {
                ForEach(PrintProfile.AdhesionType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Bed Adhesion")
        }
    }

    private var retractionSection: some View {
        Section {
            HStack {
                Text("Retraction Length")
                Spacer()
                Text("\(appState.currentProfile.retractionLength, specifier: "%.1f") mm")
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: $appState.currentProfile.retractionLength,
                in: 0...10,
                step: 0.1
            )

            HStack {
                Text("Retraction Speed")
                Spacer()
                Text("\(appState.currentProfile.retractionSpeed, specifier: "%.0f") mm/s")
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: $appState.currentProfile.retractionSpeed,
                in: 10...100,
                step: 5
            )
        } header: {
            Text("Retraction")
        }
    }

    // MARK: - Actions

    private func applyPreset(_ preset: ProfilePreset) {
        switch preset {
        case .draft:
            appState.currentProfile = .draft
        case .standard:
            appState.currentProfile = .standard
        case .quality:
            appState.currentProfile = .quality
        case .custom:
            break
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
