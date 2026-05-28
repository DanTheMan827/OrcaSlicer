import SwiftUI

@main
struct OrcaSlicerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var profileManager = ProfileManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appearance") private var appearance: AppSettingsView.AppAppearance = .system
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            AdaptiveContentView()
                .environmentObject(appState)
                .environmentObject(profileManager)
                .preferredColorScheme(appearance.colorScheme)
                .onAppear {
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                        .onDisappear {
                            hasCompletedOnboarding = true
                        }
                }
                .onOpenURL { url in
                    handleIncomingFile(url)
                }
        }
    }

    private func handleIncomingFile(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let ext = url.pathExtension.lowercased()
        if ["stl", "obj", "3mf", "step", "stp"].contains(ext) {
            // Import as a model
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destination = documentsURL.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: destination)
            appState.importModel(from: destination)
        } else if ext == "json" && url.lastPathComponent.contains("orcaprofile") {
            // Import as a profile
            _ = profileManager.importProfile(from: url)
        }
    }
}
