import SwiftUI
import Combine

/// Central application state that manages the lifecycle of the slicer engine
/// and coordinates between different views.
@MainActor
final class AppState: ObservableObject {
    @Published var importedModels: [PrintModel] = []
    @Published var selectedModel: PrintModel?
    @Published var printers: [Printer] = []
    @Published var selectedPrinter: Printer?
    @Published var currentProfile: PrintProfile = .default
    @Published var sliceResult: SliceResult?
    @Published var isSlicing: Bool = false
    @Published var sliceProgress: Double = 0.0

    private let slicerService = SlicerService()

    init() {
        loadSavedPrinters()
    }

    func importModel(from url: URL) {
        let model = PrintModel(
            id: UUID(),
            name: url.deletingPathExtension().lastPathComponent,
            fileURL: url,
            fileType: PrintModel.FileType(from: url.pathExtension),
            dateAdded: Date(),
            thumbnail: nil
        )
        importedModels.append(model)
        selectedModel = model
    }

    func removeModel(_ model: PrintModel) {
        importedModels.removeAll { $0.id == model.id }
        if selectedModel?.id == model.id {
            selectedModel = importedModels.first
        }
    }

    func slice() async {
        guard let model = selectedModel, let printer = selectedPrinter else { return }

        isSlicing = true
        sliceProgress = 0.0
        sliceResult = nil

        do {
            let result = try await slicerService.slice(
                model: model,
                profile: currentProfile,
                printer: printer
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.sliceProgress = progress
                }
            }
            sliceResult = result
        } catch {
            sliceResult = SliceResult(
                gcodeURL: nil,
                estimatedTime: 0,
                estimatedFilament: 0,
                layerCount: 0,
                error: error.localizedDescription
            )
        }

        isSlicing = false
    }

    func addPrinter(_ printer: Printer) {
        printers.append(printer)
        if selectedPrinter == nil {
            selectedPrinter = printer
        }
        savePrinters()
    }

    func removePrinter(_ printer: Printer) {
        printers.removeAll { $0.id == printer.id }
        if selectedPrinter?.id == printer.id {
            selectedPrinter = printers.first
        }
        savePrinters()
    }

    private func loadSavedPrinters() {
        guard let data = UserDefaults.standard.data(forKey: "savedPrinters"),
              let saved = try? JSONDecoder().decode([Printer].self, from: data) else {
            return
        }
        printers = saved
        selectedPrinter = printers.first
    }

    private func savePrinters() {
        if let data = try? JSONEncoder().encode(printers) {
            UserDefaults.standard.set(data, forKey: "savedPrinters")
        }
    }
}
