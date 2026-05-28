import SwiftUI

/// iPad-optimized layout using a sidebar navigation pattern.
/// On iPhone, falls back to the standard tab bar.
struct AdaptiveContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedSection: SidebarSection = .models
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    enum SidebarSection: String, CaseIterable, Identifiable {
        case models = "Models"
        case settings = "Print Settings"
        case slice = "Slice"
        case gcode = "G-code Preview"
        case printers = "Printers"
        case appSettings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .models: return "cube"
            case .settings: return "slider.horizontal.3"
            case .slice: return "layers.3d"
            case .gcode: return "doc.text"
            case .printers: return "printer"
            case .appSettings: return "gear"
            }
        }

        var group: SidebarGroup {
            switch self {
            case .models, .settings, .slice, .gcode: return .workspace
            case .printers: return .hardware
            case .appSettings: return .app
            }
        }
    }

    enum SidebarGroup: String, CaseIterable {
        case workspace = "Workspace"
        case hardware = "Hardware"
        case app = "Application"
    }

    var body: some View {
        if sizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPad Sidebar Layout

    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detailView(for: selectedSection)
        }
    }

    private var sidebar: some View {
        List(selection: $selectedSection) {
            Section("Workspace") {
                ForEach(SidebarSection.allCases.filter { $0.group == .workspace }) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }

            Section("Hardware") {
                ForEach(SidebarSection.allCases.filter { $0.group == .hardware }) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }

            Section("Application") {
                ForEach(SidebarSection.allCases.filter { $0.group == .app }) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }
        }
        .navigationTitle("OrcaSlicer")
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func detailView(for section: SidebarSection) -> some View {
        switch section {
        case .models:
            ModelsView()
        case .settings:
            SettingsView()
        case .slice:
            SliceView()
        case .gcode:
            GCodeView(gcodeURL: appState.sliceResult?.gcodeURL)
        case .printers:
            PrintersView()
        case .appSettings:
            AppSettingsView()
        }
    }

    // MARK: - iPhone Tab Layout

    private var iPhoneLayout: some View {
        TabView {
            ModelsView()
                .tabItem {
                    Label("Models", systemImage: "cube")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }

            SliceView()
                .tabItem {
                    Label("Slice", systemImage: "layers.3d")
                }

            PrintersView()
                .tabItem {
                    Label("Printers", systemImage: "printer")
                }

            AppSettingsView()
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
        }
    }
}

#Preview("iPad") {
    AdaptiveContentView()
        .environmentObject(AppState())
        .previewDevice("iPad Pro (12.9-inch) (6th generation)")
}

#Preview("iPhone") {
    AdaptiveContentView()
        .environmentObject(AppState())
        .previewDevice("iPhone 15 Pro")
}
