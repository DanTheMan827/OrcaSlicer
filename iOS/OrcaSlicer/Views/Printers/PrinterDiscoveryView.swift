import SwiftUI

/// Printer discovery sheet that scans for printers on the local network via Bonjour.
struct PrinterDiscoveryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var discoveryService = PrinterDiscoveryService()
    @State private var testingPrinter: PrinterDiscoveryService.DiscoveredPrinter?
    @State private var connectionResult: ConnectionResult?

    enum ConnectionResult {
        case success(PrinterDiscoveryService.DiscoveredPrinter)
        case failure(PrinterDiscoveryService.DiscoveredPrinter, String)
    }

    var body: some View {
        NavigationStack {
            List {
                statusSection

                if !discoveryService.discoveredPrinters.isEmpty {
                    discoveredSection
                }

                manualSection
            }
            .navigationTitle("Find Printers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                discoveryService.startDiscovery()
            }
            .onDisappear {
                discoveryService.stopDiscovery()
            }
        }
    }

    private var statusSection: some View {
        Section {
            if discoveryService.isSearching {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Searching for printers on your network...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if discoveryService.discoveredPrinters.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No printers found")
                            .font(.subheadline)
                        Text("Make sure your printer is on the same network.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Found \(discoveryService.discoveredPrinters.count) printer(s)")
                        .font(.subheadline)
                }
            }

            if !discoveryService.isSearching {
                Button("Scan Again") {
                    discoveryService.startDiscovery()
                }
            }
        }
    }

    private var discoveredSection: some View {
        Section("Discovered Printers") {
            ForEach(discoveryService.discoveredPrinters) { printer in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(printer.name)
                            .font(.body)
                        Text("\(printer.type.rawValue) • \(printer.host):\(printer.port)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    if testingPrinter?.id == printer.id {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Add") {
                            addDiscoveredPrinter(printer)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private var manualSection: some View {
        Section {
            NavigationLink {
                ManualPrinterEntryView()
            } label: {
                Label("Enter IP Address Manually", systemImage: "keyboard")
            }
        } header: {
            Text("Manual Setup")
        } footer: {
            Text("If your printer doesn't appear automatically, you can enter its IP address manually.")
        }
    }

    private func addDiscoveredPrinter(_ discovered: PrinterDiscoveryService.DiscoveredPrinter) {
        testingPrinter = discovered

        Task {
            let success = await discoveryService.testConnection(to: discovered)

            if success {
                let connectionType: Printer.ConnectionType
                switch discovered.type {
                case .octoprint: connectionType = .octoprint
                default: connectionType = .network
                }

                let printer = Printer(
                    id: UUID(),
                    name: discovered.name,
                    manufacturer: "",
                    model: discovered.type.rawValue,
                    bedShape: .rectangular,
                    nozzleDiameter: 0.4,
                    maxBedTemperature: 110,
                    maxNozzleTemperature: 300,
                    connectionType: connectionType,
                    bedSize: Printer.BedSize(width: 220, depth: 220, height: 250)
                )
                appState.addPrinter(printer)
                connectionResult = .success(discovered)
                dismiss()
            } else {
                connectionResult = .failure(discovered, "Could not connect to printer")
            }

            testingPrinter = nil
        }
    }
}

/// Manual printer entry for when Bonjour discovery doesn't find the printer.
struct ManualPrinterEntryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var ipAddress = ""
    @State private var port = "80"
    @State private var printerName = ""
    @State private var protocol_: Printer.ConnectionType = .network

    var body: some View {
        Form {
            Section("Connection") {
                TextField("IP Address", text: $ipAddress)
                    .keyboardType(.decimalPad)
                    .textContentType(.URL)
                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
                Picker("Protocol", selection: $protocol_) {
                    Text("Network").tag(Printer.ConnectionType.network)
                    Text("OctoPrint").tag(Printer.ConnectionType.octoprint)
                }
            }

            Section("Printer Info") {
                TextField("Name (optional)", text: $printerName)
            }

            Section {
                Button("Add Printer") {
                    let printer = Printer(
                        id: UUID(),
                        name: printerName.isEmpty ? ipAddress : printerName,
                        manufacturer: "",
                        model: "",
                        bedShape: .rectangular,
                        nozzleDiameter: 0.4,
                        maxBedTemperature: 110,
                        maxNozzleTemperature: 300,
                        connectionType: protocol_,
                        bedSize: Printer.BedSize(width: 220, depth: 220, height: 250)
                    )
                    appState.addPrinter(printer)
                    dismiss()
                }
                .disabled(ipAddress.isEmpty)
            }
        }
        .navigationTitle("Manual Entry")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    PrinterDiscoveryView()
        .environmentObject(AppState())
}
