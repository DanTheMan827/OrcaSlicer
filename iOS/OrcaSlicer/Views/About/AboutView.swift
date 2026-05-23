import SwiftUI

/// About screen showing app information, version, and links.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                appInfoSection
                linksSection
                acknowledgmentsSection
                legalSection
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var appInfoSection: some View {
        Section {
            HStack(spacing: 16) {
                // App icon placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "cube.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("OrcaSlicer")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Version 2.4.0")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Build 1")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var linksSection: some View {
        Section("Links") {
            Link(destination: URL(string: "https://github.com/SoftFever/OrcaSlicer")!) {
                Label("GitHub Repository", systemImage: "link")
            }
            Link(destination: URL(string: "https://github.com/SoftFever/OrcaSlicer/wiki")!) {
                Label("Documentation", systemImage: "book")
            }
            Link(destination: URL(string: "https://github.com/SoftFever/OrcaSlicer/issues")!) {
                Label("Report an Issue", systemImage: "exclamationmark.bubble")
            }
            Link(destination: URL(string: "https://discord.gg/P4VE9UY9gJ")!) {
                Label("Discord Community", systemImage: "bubble.left.and.bubble.right")
            }
        }
    }

    private var acknowledgmentsSection: some View {
        Section("Powered By") {
            AcknowledgmentRow(name: "libslic3r", description: "Core slicing engine")
            AcknowledgmentRow(name: "PrusaSlicer", description: "Based on PrusaSlicer by Prusa Research")
            AcknowledgmentRow(name: "BambuStudio", description: "Based on BambuStudio by Bambu Lab")
            AcknowledgmentRow(name: "SceneKit", description: "3D model rendering")
        }
    }

    private var legalSection: some View {
        Section("Legal") {
            NavigationLink {
                LicenseView()
            } label: {
                Label("Open Source Licenses", systemImage: "doc.text")
            }
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
        }
    }
}

struct AcknowledgmentRow: View {
    let name: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.body)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct LicenseView: View {
    var body: some View {
        ScrollView {
            Text("""
            OrcaSlicer is licensed under the GNU Affero General Public License, version 3.

            This program is free software: you can redistribute it and/or modify it under \
            the terms of the GNU Affero General Public License as published by the Free \
            Software Foundation, either version 3 of the License, or (at your option) any \
            later version.

            This program is distributed in the hope that it will be useful, but WITHOUT \
            ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS \
            FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

            Based on PrusaSlicer by Prusa Research (https://github.com/prusa3d/PrusaSlicer) \
            and BambuStudio by Bambu Lab (https://github.com/bambulab/BambuStudio), both \
            licensed under the GNU Affero General Public License, version 3.
            """)
            .font(.footnote)
            .padding()
        }
        .navigationTitle("Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("""
            OrcaSlicer for iOS respects your privacy.

            • All slicing is performed locally on your device.
            • No 3D model data is transmitted to external servers unless you explicitly \
            choose to send files to a network printer.
            • Printer connection data is stored locally on your device.
            • No analytics or tracking data is collected.
            • Network access is only used for printer communication when you initiate it.
            """)
            .font(.footnote)
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    AboutView()
}
