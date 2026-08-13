import Foundation

/// Wraps stored data with a schema version so JSON files can be migrated later
/// without corrupting existing saves.
struct DataFile<T: Codable>: Codable {
    var schemaVersion: Int
    var data: T
}

/// The single type that touches disk. Reads/writes `Codable` values as JSON files
/// in the app's Documents directory.
///
/// Everything else in the app goes through `AppStore`, which goes through this.
/// To add online sync later, replace this implementation — the UI never changes.
struct PersistenceService {
    static let currentSchemaVersion = 1

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    private func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    /// Load a JSON file, returning `defaultValue` if the file doesn't exist yet
    /// (first launch) or can't be decoded.
    func load<T: Codable>(_ filename: String, default defaultValue: T) -> T {
        let fileURL = url(for: filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return defaultValue
        }
        do {
            let raw = try Data(contentsOf: fileURL)
            let file = try decoder.decode(DataFile<T>.self, from: raw)
            return file.data
        } catch {
            print("⚠️ Failed to load \(filename): \(error). Using default.")
            return defaultValue
        }
    }

    // Claude  Date 08/03/2026
    // The strict twin of `load`. `load` swallows every decode error and hands back
    // the default, which is right for a preferences file and *wrong* for anything
    // that represents money: a single corrupt byte in theme.json would silently
    // report a zero balance, and the next save() would atomically write that zero
    // over the only good copy. This throws instead, so the caller can refuse to
    // write rather than destroying the file it failed to read.
    //
    // Returns nil when the file simply doesn't exist yet (first launch) — that's a
    // normal state, not an error.
    func loadStrict<T: Codable>(_ filename: String, as type: T.Type = T.self) throws -> T? {
        let fileURL = url(for: filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let raw = try Data(contentsOf: fileURL)
        return try decoder.decode(DataFile<T>.self, from: raw).data
    }

    /// Save a value as JSON using an atomic write (so a crash mid-write can't
    /// leave a half-written file).
    func save<T: Codable>(_ value: T, to filename: String) {
        let file = DataFile(schemaVersion: Self.currentSchemaVersion, data: value)
        do {
            let raw = try encoder.encode(file)
            try raw.write(to: url(for: filename), options: [.atomic])
        } catch {
            print("⚠️ Failed to save \(filename): \(error)")
        }
    }
}
