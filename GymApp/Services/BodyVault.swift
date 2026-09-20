import Foundation
import CryptoKit

// CLAUDE  Date 09/19/2026
// The body feature's storage: ONE file, encrypted with a key that lives in the Keychain.
// That combination is the privacy promise — Keychain items restore only from ENCRYPTED
// backups, so an unencrypted Finder backup carries nothing but ciphertext. Nothing here is
// ever synced, shared or exported.
struct BodyVault {

    enum VaultError: Error {
        /// The key is gone but the file isn't: the data can't be recovered.
        case keyMissing
        /// The Keychain couldn't answer right now (locked device). Try again later.
        case keyUnavailable(OSStatus)
        case decryptionFailed
    }

    static let fileName = "body.vault"
    /// Where an unreadable vault is parked. Never deleted behind the user's back.
    static let asideFileName = "body.vault.unreadable"

    private let directory: URL
    private let keys: BodyKeyProviding

    init(directory: URL? = nil, keys: BodyKeyProviding = KeychainBodyKey()) {
        self.directory = directory ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.keys = keys
    }

    private var url: URL { directory.appendingPathComponent(Self.fileName) }
    private var asideURL: URL { directory.appendingPathComponent(Self.asideFileName) }

    var fileExists: Bool { FileManager.default.fileExists(atPath: url.path) }

    // MARK: - Read

    // CLAUDE  Date 09/19/2026
    // nil means "nothing stored yet", which is a normal first run. Everything else throws —
    // never a silent default, because the next save would then write that default over the
    // only copy (the same trap PersistenceService.loadStrict exists to avoid).
    func load() throws -> BodyData? {
        guard fileExists else { return nil }
        let key: SymmetricKey
        switch keys.load() {
        case .found(let existing): key = existing
        case .notFound:            throw VaultError.keyMissing
        case .failed(let status):  throw VaultError.keyUnavailable(status)
        }
        let raw = try Data(contentsOf: url)
        guard let box = try? AES.GCM.SealedBox(combined: raw),
              let plain = try? AES.GCM.open(box, using: key) else {
            throw VaultError.decryptionFailed
        }
        return try Self.decoder.decode(BodyData.self, from: plain)
    }

    // MARK: - Write

    // CLAUDE  Date 09/19/2026
    // A key is minted ONLY when there is no vault file, so a Keychain that answers badly can
    // never orphan good data. The new key is read back before the first write — a key that
    // failed to store would otherwise encrypt a file nothing can ever open again.
    func save(_ data: BodyData) throws {
        let key: SymmetricKey
        switch keys.load() {
        case .found(let existing):
            key = existing
        case .notFound:
            guard !fileExists else { throw VaultError.keyMissing }
            key = try keys.create()
        case .failed(let status):
            throw VaultError.keyUnavailable(status)
        }
        let plain = try Self.encoder.encode(data)
        guard let sealed = try? AES.GCM.seal(plain, using: key).combined else {
            throw VaultError.decryptionFailed
        }
        try sealed.write(to: url, options: [.atomic])
        applyFileProtection()
    }

    // MARK: - Recovery and erase

    /// Park an unreadable vault rather than deleting it — a key can come back with a restore.
    func moveAside() {
        guard fileExists else { return }
        let fm = FileManager.default
        try? fm.removeItem(at: asideURL)
        try? fm.moveItem(at: url, to: asideURL)
    }

    // CLAUDE  Date 09/19/2026
    // Total erase: both files and the key. Side effect — anything still encrypted with that
    // key becomes permanently unreadable, which is the point. Called by "Erase body data" and
    // by AccountDeletion, since PersistenceService.removeAll only sweeps *.json.
    func erase() {
        let fm = FileManager.default
        try? fm.removeItem(at: url)
        try? fm.removeItem(at: asideURL)
        keys.delete()
    }

    private func applyFileProtection() {
        #if canImport(UIKit)
        // Belt and braces on top of our own encryption. Deliberately NOT `.complete`: the app
        // can be launched into the background before first unlock, and a save that throws
        // there would be worse than a file the OS already protects at rest.
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path)
        #endif
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

// CLAUDE  Date 09/19/2026
// Where the vault's key comes from. A protocol purely so the standalone model harness can run
// the vault with an in-memory key instead of touching the real Keychain.
protocol BodyKeyProviding {
    func load() -> BodyKeyLookup
    func create() throws -> SymmetricKey
    func delete()
}

enum BodyKeyLookup {
    case found(SymmetricKey)
    case notFound
    case failed(OSStatus)
}

// CLAUDE  Date 09/19/2026
// The real one: a 256-bit key kept as base64 in the Keychain beside the card secret, with
// AfterFirstUnlock accessibility. That class is what limits restores to encrypted backups —
// and it stays readable if the app is ever woken before the user unlocks.
struct KeychainBodyKey: BodyKeyProviding {
    static let account = "agil.bodyKey"
    private let store = KeychainStore.standard

    func load() -> BodyKeyLookup {
        switch store.lookup(Self.account) {
        case .found(let encoded):
            guard let raw = Data(base64Encoded: encoded) else { return .failed(errSecDecode) }
            return .found(SymmetricKey(data: raw))
        case .notFound:
            return .notFound
        case .failed(let status):
            return .failed(status)
        }
    }

    func create() throws -> SymmetricKey {
        let key = SymmetricKey(size: .bits256)
        let encoded = key.withUnsafeBytes { Data($0) }.base64EncodedString()
        store.set(encoded, for: Self.account)
        // Read it back: a key that didn't store would encrypt a file nothing could open.
        guard case .found(let stored) = load() else { throw BodyVault.VaultError.keyMissing }
        return stored
    }

    func delete() { store.delete(Self.account) }
}
