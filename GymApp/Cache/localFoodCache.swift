import Foundation

// Claude  Date 06/17/2026
// A compact, on-disk cache of barcode → product lookups, so a previously-seen
// barcode resolves instantly (and offline) instead of re-hitting the rate-limited
// Open Food Facts API. Kept deliberately separate from the user's `foods` library
// (AppStore.foods): the library is the curated "My foods" list, whereas this is a
// disposable lookup-acceleration layer that can be evicted freely.
//
// Compactness comes from being a single barcode-keyed map of {product, lastUsed},
// bounded by an LRU cap (maxEntries). Persisted as its own JSON file by AppStore
// through the usual PersistenceService/DataFile pipeline.

// Claude  Date 06/17/2026
// One cached product, stamped with the time it was last read or written. lastUsed
// is what the LRU eviction sorts on, so frequently-scanned items survive.
struct CachedFood: Codable, Hashable {
    var item: FoodItem
    var lastUsed: Date
}

// Claude  Date 06/17/2026
// The cache itself: a barcode-keyed dictionary with an LRU size cap. All access
// normalizes the barcode the same way OpenFoodFactsClient does (trim) so keys are
// stable. Pure value type — AppStore owns persistence; this owns the logic.
struct BarcodeCache: Codable {
    // Upper bound on stored barcodes; the least-recently-used are evicted past this.
    static let maxEntries = 500

    private(set) var entries: [String: CachedFood] = [:]

    // Non-mutating presence check, so a cache *miss* never triggers a (pointless)
    // persist. Callers guard on this before calling the mutating `lookup`.
    func contains(_ barcode: String) -> Bool {
        entries[Self.normalize(barcode)] != nil
    }

    // Touch-on-read: returns the cached product and bumps its recency so it's less
    // likely to be evicted. Returns nil on a miss (without mutating).
    mutating func lookup(_ barcode: String) -> FoodItem? {
        let key = Self.normalize(barcode)
        guard var hit = entries[key] else { return nil }
        hit.lastUsed = Date()
        entries[key] = hit
        return hit.item
    }

    // Insert or replace a found product, stamping it as just-used, then evict the
    // oldest entries if we've gone over the cap. No-op for an empty barcode.
    mutating func insert(_ item: FoodItem, forBarcode barcode: String) {
        let key = Self.normalize(barcode)
        guard !key.isEmpty else { return }
        entries[key] = CachedFood(item: item, lastUsed: Date())
        evictIfNeeded()
    }

    // Drop the least-recently-used entries until we're back at the cap.
    private mutating func evictIfNeeded() {
        guard entries.count > Self.maxEntries else { return }
        let overflow = entries.count - Self.maxEntries
        let oldestKeys = entries
            .sorted { $0.value.lastUsed < $1.value.lastUsed }
            .prefix(overflow)
            .map(\.key)
        for key in oldestKeys { entries.removeValue(forKey: key) }
    }

    private static func normalize(_ barcode: String) -> String {
        barcode.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#if DEBUG
extension BarcodeCache {
    // Claude  Date 06/17/2026
    // Dev sanity check (driven from the Settings "Barcode cache (debug)" button):
    // overfill a fresh cache and confirm the LRU cap holds. Cap-only so it's
    // deterministic (per-insert timestamps can tie, so which keys evict isn't).
    static func debugRunLRUCheck() -> String {
        var cache = BarcodeCache()
        for i in 0..<(maxEntries + 5) {
            cache.insert(FoodItem(name: "Test \(i)", barcode: "\(i)"), forBarcode: "\(i)")
        }
        let ok = cache.entries.count == maxEntries
        return "LRU cap \(ok ? "✓" : "✗") (\(cache.entries.count)/\(maxEntries))"
    }
}
#endif
