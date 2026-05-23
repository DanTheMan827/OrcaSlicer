import Foundation

/// Manages persistence of custom print profiles.
/// Profiles are stored as JSON files in the app's documents directory.
final class ProfileManager: ObservableObject {
    @Published var savedProfiles: [SavedProfile] = []

    private let profilesDirectory: URL

    struct SavedProfile: Identifiable, Codable {
        let id: UUID
        var name: String
        var profile: PrintProfile
        var createdAt: Date
        var modifiedAt: Date

        init(name: String, profile: PrintProfile) {
            self.id = UUID()
            self.name = name
            self.profile = profile
            self.createdAt = Date()
            self.modifiedAt = Date()
        }
    }

    init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        profilesDirectory = documentsURL.appendingPathComponent("Profiles", isDirectory: true)

        // Create profiles directory if it doesn't exist
        try? FileManager.default.createDirectory(at: profilesDirectory, withIntermediateDirectories: true)

        loadProfiles()
    }

    func saveProfile(name: String, profile: PrintProfile) {
        let saved = SavedProfile(name: name, profile: profile)
        savedProfiles.append(saved)
        writeToDisk(saved)
    }

    func updateProfile(_ id: UUID, name: String, profile: PrintProfile) {
        guard let index = savedProfiles.firstIndex(where: { $0.id == id }) else { return }
        savedProfiles[index].name = name
        savedProfiles[index].profile = profile
        savedProfiles[index].modifiedAt = Date()
        writeToDisk(savedProfiles[index])
    }

    func deleteProfile(_ id: UUID) {
        guard let index = savedProfiles.firstIndex(where: { $0.id == id }) else { return }
        let profile = savedProfiles[index]
        savedProfiles.remove(at: index)

        let fileURL = profilesDirectory.appendingPathComponent("\(profile.id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }

    func duplicateProfile(_ id: UUID) {
        guard let source = savedProfiles.first(where: { $0.id == id }) else { return }
        saveProfile(name: "\(source.name) (Copy)", profile: source.profile)
    }

    /// Export a profile as a shareable JSON file.
    func exportProfile(_ id: UUID) -> URL? {
        guard let profile = savedProfiles.first(where: { $0.id == id }) else { return nil }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(profile.name).orcaprofile.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(profile) else { return nil }
        try? data.write(to: tempURL)

        return tempURL
    }

    /// Import a profile from a JSON file.
    func importProfile(from url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let profile = try? JSONDecoder().decode(SavedProfile.self, from: data) else {
            return false
        }

        // Create a new ID to avoid conflicts
        let imported = SavedProfile(name: profile.name, profile: profile.profile)
        savedProfiles.append(imported)
        writeToDisk(imported)
        return true
    }

    // MARK: - Private

    private func loadProfiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: profilesDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        savedProfiles = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> SavedProfile? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(SavedProfile.self, from: data)
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private func writeToDisk(_ profile: SavedProfile) {
        let fileURL = profilesDirectory.appendingPathComponent("\(profile.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(profile) else { return }
        try? data.write(to: fileURL)
    }
}
