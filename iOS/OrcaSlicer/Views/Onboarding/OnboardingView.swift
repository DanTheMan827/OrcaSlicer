import SwiftUI

/// First-launch onboarding flow introducing the app's features.
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "cube.fill",
            iconColor: .orange,
            title: "Import 3D Models",
            description: "Import STL, 3MF, OBJ, and STEP files from Files, iCloud, or other apps."
        ),
        OnboardingPage(
            icon: "slider.horizontal.3",
            iconColor: .blue,
            title: "Configure Settings",
            description: "Fine-tune layer height, infill, speed, temperature, and supports for your prints."
        ),
        OnboardingPage(
            icon: "layers.3d",
            iconColor: .green,
            title: "Slice & Preview",
            description: "Generate G-code with detailed layer-by-layer preview and time estimates."
        ),
        OnboardingPage(
            icon: "printer.fill",
            iconColor: .purple,
            title: "Send to Printer",
            description: "Connect to your 3D printer over the network and start printing directly."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            bottomControls
        }
        .background(Color(.systemBackground))
        .interactiveDismissDisabled()
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 72))
                .foregroundStyle(page.iconColor)
                .padding(.bottom, 8)

            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }

    private var bottomControls: some View {
        HStack {
            if currentPage > 0 {
                Button("Back") {
                    withAnimation {
                        currentPage -= 1
                    }
                }
                .tint(.secondary)
            }

            Spacer()

            if currentPage < pages.count - 1 {
                Button("Next") {
                    withAnimation {
                        currentPage += 1
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Get Started") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
