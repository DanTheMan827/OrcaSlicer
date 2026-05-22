import SwiftUI

struct PrintersView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingAddPrinter = false
    @State private var editingPrinter: Printer?

    var body: some View {
        NavigationStack {
            Group {
                if appState.printers.isEmpty {
                    emptyState
                } else {
                    printerList
                }
            }
            .navigationTitle("Printers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddPrinter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Printer")
                }
            }
            .sheet(isPresented: $showingAddPrinter) {
                AddPrinterView()
            }
            .sheet(item: $editingPrinter) { printer in
                EditPrinterView(printer: printer)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Printers", systemImage: "printer")
        } description: {
            Text("Add a printer to configure bed size, nozzle diameter, and connection settings.")
        } actions: {
            Button("Add Printer") {
                showingAddPrinter = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var printerList: some View {
        List(selection: $appState.selectedPrinter) {
            ForEach(appState.printers) { printer in
                PrinterRowView(
                    printer: printer,
                    isSelected: appState.selectedPrinter?.id == printer.id
                )
                .tag(printer)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.selectedPrinter = printer
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        appState.removePrinter(printer)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        editingPrinter = printer
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct PrinterRowView: View {
    let printer: Printer
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 48, height: 48)
                Image(systemName: "printer.fill")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .accent : .secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(printer.name)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.accent)
                    }
                }
                HStack(spacing: 8) {
                    Text("\(printer.bedSize.width, specifier: "%.0f")×\(printer.bedSize.depth, specifier: "%.0f")×\(printer.bedSize.height, specifier: "%.0f") mm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text("\(printer.nozzleDiameter, specifier: "%.1f") mm nozzle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Printer

struct AddPrinterView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var bedWidth: Double = 220
    @State private var bedDepth: Double = 220
    @State private var bedHeight: Double = 250
    @State private var nozzleDiameter: Double = 0.4
    @State private var bedShape: Printer.BedShape = .rectangular
    @State private var connectionType: Printer.ConnectionType = .none
    @State private var maxBedTemp: Int = 110
    @State private var maxNozzleTemp: Int = 300

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    TextField("Printer Name", text: $name)
                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Model", text: $model)
                }

                Section("Build Volume") {
                    Picker("Bed Shape", selection: $bedShape) {
                        ForEach(Printer.BedShape.allCases, id: \.self) { shape in
                            Text(shape.rawValue).tag(shape)
                        }
                    }
                    HStack {
                        Text("Width")
                        Spacer()
                        TextField("Width", value: $bedWidth, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("mm")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Depth")
                        Spacer()
                        TextField("Depth", value: $bedDepth, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("mm")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("Height", value: $bedHeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("mm")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Nozzle") {
                    Picker("Nozzle Diameter", selection: $nozzleDiameter) {
                        Text("0.2 mm").tag(0.2)
                        Text("0.4 mm").tag(0.4)
                        Text("0.6 mm").tag(0.6)
                        Text("0.8 mm").tag(0.8)
                    }
                }

                Section("Temperature Limits") {
                    Stepper("Max Nozzle: \(maxNozzleTemp)°C", value: $maxNozzleTemp, in: 200...500, step: 10)
                    Stepper("Max Bed: \(maxBedTemp)°C", value: $maxBedTemp, in: 0...200, step: 10)
                }

                Section("Connection") {
                    Picker("Connection Type", selection: $connectionType) {
                        ForEach(Printer.ConnectionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("Add Printer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let printer = Printer(
                            id: UUID(),
                            name: name.isEmpty ? "New Printer" : name,
                            manufacturer: manufacturer,
                            model: model,
                            bedShape: bedShape,
                            nozzleDiameter: nozzleDiameter,
                            maxBedTemperature: maxBedTemp,
                            maxNozzleTemperature: maxNozzleTemp,
                            connectionType: connectionType,
                            bedSize: Printer.BedSize(
                                width: bedWidth,
                                depth: bedDepth,
                                height: bedHeight
                            )
                        )
                        appState.addPrinter(printer)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Edit Printer

struct EditPrinterView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let printer: Printer

    @State private var name: String = ""
    @State private var manufacturer: String = ""
    @State private var model: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    TextField("Printer Name", text: $name)
                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Model", text: $model)
                }
            }
            .navigationTitle("Edit Printer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let idx = appState.printers.firstIndex(where: { $0.id == printer.id }) {
                            appState.printers[idx].name = name
                            appState.printers[idx].manufacturer = manufacturer
                            appState.printers[idx].model = model
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                name = printer.name
                manufacturer = printer.manufacturer
                model = printer.model
            }
        }
    }
}

#Preview {
    PrintersView()
        .environmentObject(AppState())
}
