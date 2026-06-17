import Foundation

// Claude  Date 06/17/2026
// A caching decorator over any FoodSearchService (e.g. OpenFoodFactsClient): it
// transparently consults the local BarcodeCache before falling through to the
// network, and records found products on the way back. Same protocol as the bare
// client, so it's a drop-in — a future barcode scanner just does:
//
//   CachedFoodService(base: OpenFoodFactsClient(), store: store).lookup(barcode:)
//
// Networking stays in `base`; cache storage stays in AppStore. This type only
// wires the two together, which is why it holds the @MainActor AppStore and hops
// onto it (`await`) for the synchronous cache reads/writes.
struct CachedFoodService: FoodSearchService {
    let base: FoodSearchService
    let store: AppStore

    // Text search isn't barcode-keyed, so it passes straight through (uncached).
    func search(_ query: String) async throws -> [FoodItem] {
        try await base.search(query)
    }

    // Cache-first barcode lookup: a hit skips the network entirely; a miss fetches
    // from `base` and caches the result. Only *found* products are stored — a nil
    // result writes nothing (no negative caching).
    func lookup(barcode: String) async throws -> FoodItem? {
        if let hit = await store.cachedFood(forBarcode: barcode) { return hit }
        let fetched = try await base.lookup(barcode: barcode)
        if let fetched { await store.rememberScannedFood(fetched, forBarcode: barcode) }
        return fetched
    }
}
