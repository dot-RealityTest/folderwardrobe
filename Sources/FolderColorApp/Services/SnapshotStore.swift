import Foundation

private struct SnapshotDatabase: Codable {
    var snapshots: [String: FolderSnapshot] = [:]
}

final class SnapshotStore {
    private let fileURL: URL
    private var database: SnapshotDatabase

    init(directoryName: String = "folderwardrobe") {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeDirectory = Self.resolveStoreDirectory(baseDirectory: baseDirectory, preferredName: directoryName)
        try? FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)

        fileURL = storeDirectory.appendingPathComponent("snapshots.json")
        database = Self.loadDatabase(from: fileURL)
    }

    func snapshot(for key: String) -> FolderSnapshot? {
        database.snapshots[key]
    }

    func save(_ snapshot: FolderSnapshot, for key: String) throws {
        database.snapshots[key] = snapshot
        try persist()
    }

    func remove(for key: String) throws {
        database.snapshots.removeValue(forKey: key)
        try persist()
    }

    private func persist() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(database)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func loadDatabase(from fileURL: URL) -> SnapshotDatabase {
        guard
            let data = try? Data(contentsOf: fileURL),
            let database = try? JSONDecoder().decode(SnapshotDatabase.self, from: data)
        else {
            return SnapshotDatabase()
        }

        return database
    }

    private static func resolveStoreDirectory(baseDirectory: URL, preferredName: String) -> URL {
        let fileManager = FileManager.default
        let preferredDirectory = baseDirectory.appendingPathComponent(preferredName, isDirectory: true)
        if fileManager.fileExists(atPath: preferredDirectory.path) {
            return preferredDirectory
        }

        let legacyDirectory = baseDirectory.appendingPathComponent("FolderColorUtility", isDirectory: true)
        if fileManager.fileExists(atPath: legacyDirectory.path) {
            return legacyDirectory
        }

        return preferredDirectory
    }
}
