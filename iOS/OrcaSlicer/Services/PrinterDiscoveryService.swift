import Foundation
import Network

/// Discovers 3D printers on the local network via Bonjour/mDNS.
/// Supports OctoPrint, Moonraker (Klipper), and other network printer protocols.
@MainActor
final class PrinterDiscoveryService: ObservableObject {
    @Published var discoveredPrinters: [DiscoveredPrinter] = []
    @Published var isSearching: Bool = false

    private var browser: NWBrowser?
    private var listeners: [NWBrowser.Result] = []

    struct DiscoveredPrinter: Identifiable, Hashable {
        let id: UUID = UUID()
        let name: String
        let host: String
        let port: Int
        let type: PrinterProtocol

        enum PrinterProtocol: String {
            case octoprint = "OctoPrint"
            case moonraker = "Moonraker"
            case bambulab = "Bambu Lab"
            case unknown = "Unknown"
        }
    }

    /// Start scanning for printers on the local network.
    func startDiscovery() {
        isSearching = true
        discoveredPrinters = []

        // Search for OctoPrint instances
        searchForService(type: "_octoprint._tcp")

        // Search for Moonraker (Klipper) instances
        searchForService(type: "_moonraker._tcp")

        // Search for generic HTTP services that might be printers
        searchForService(type: "_http._tcp")

        // Auto-stop after 10 seconds
        Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            stopDiscovery()
        }
    }

    /// Stop scanning.
    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    /// Attempt to connect to a discovered printer and validate the connection.
    func testConnection(to printer: DiscoveredPrinter) async -> Bool {
        let urlString: String
        switch printer.type {
        case .octoprint:
            urlString = "http://\(printer.host):\(printer.port)/api/version"
        case .moonraker:
            urlString = "http://\(printer.host):\(printer.port)/server/info"
        default:
            urlString = "http://\(printer.host):\(printer.port)/"
        }

        guard let url = URL(string: urlString) else { return false }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Private

    private func searchForService(type: String) {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: type, domain: nil), using: parameters)

        browser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                break
            case .failed:
                Task { @MainActor in
                    self?.isSearching = false
                }
            default:
                break
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                for result in results {
                    if case let .service(name, serviceType, _, _) = result.endpoint {
                        let printerType: DiscoveredPrinter.PrinterProtocol
                        if serviceType.contains("octoprint") {
                            printerType = .octoprint
                        } else if serviceType.contains("moonraker") {
                            printerType = .moonraker
                        } else {
                            printerType = .unknown
                        }

                        let printer = DiscoveredPrinter(
                            name: name,
                            host: name,
                            port: 80,
                            type: printerType
                        )

                        if self?.discoveredPrinters.contains(where: { $0.name == name }) == false {
                            self?.discoveredPrinters.append(printer)
                        }
                    }
                }
            }
        }

        browser.start(queue: .main)
        self.browser = browser
    }
}
