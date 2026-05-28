import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: Tab = .models

    enum Tab: String, CaseIterable {
        case models = "Models"
        case settings = "Settings"
        case slice = "Slice"
        case printers = "Printers"

        var icon: String {
            switch self {
            case .models: return "cube"
            case .settings: return "slider.horizontal.3"
            case .slice: return "layers.3d"
            case .printers: return "printer"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ModelsView()
                .tabItem {
                    Label(Tab.models.rawValue, systemImage: Tab.models.icon)
                }
                .tag(Tab.models)

            SettingsView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)

            SliceView()
                .tabItem {
                    Label(Tab.slice.rawValue, systemImage: Tab.slice.icon)
                }
                .tag(Tab.slice)

            PrintersView()
                .tabItem {
                    Label(Tab.printers.rawValue, systemImage: Tab.printers.icon)
                }
                .tag(Tab.printers)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
