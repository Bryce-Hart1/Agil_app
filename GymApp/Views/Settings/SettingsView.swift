import SwiftUI

/// App settings. Pushed from the Profile tab, so it does not host its own
/// navigation stack.
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        List {
            // Claude  Date 06/09/2026
            // Editable display name, saved locally. Shown on the Profile card.
            Section("Profile") {
                TextField("Display name", text: $store.profile.displayName)
                    .textInputAutocapitalization(.words)
            }
            Section("Appearance") {
                NavigationLink {
                    ThemeSettingsView()
                } label: {
                    HStack {
                        Label("Theme", systemImage: "paintpalette")
                        Spacer()
                        Text(theme.current.name).foregroundStyle(.secondary)
                    }
                }
            }
            Section("About") {
                LabeledContent("App", value: "Agil")
                LabeledContent("Tagline", value: "Your Tracking & Marking App")
                LabeledContent("Version", value: "0.1.0")
            }
            Section("Stored data") {
                LabeledContent("Exercises", value: "\(store.exercises.count)")
                LabeledContent("Workouts", value: "\(store.workouts.count)")
                LabeledContent("Presets", value: "\(store.presets.count)")
            }
            // Claude  Date 06/13/2026
            // Alpha-only helpers for trying the achievement-unlock celebration.
            Section {
                NavigationLink {
                    BadgeGalleryView()
                } label: {
                    Label("Badge gallery", systemImage: "square.grid.3x3.fill")
                }
                Button("Unlock all achievements") {
                    store.unlockAllAchievements()
                }
                Button("Replay achievement unlocks") {
                    store.replayCelebrations()
                }
                Button("Reset achievements", role: .destructive) {
                    store.resetAchievements()
                }
            } header: {
                Text("Developer (alpha)")
            } footer: {
                Text("Gallery previews every badge + rank (tap to play its celebration). Unlock all fills in every badge so the card and lists populate. Replay re-plays earned unlocks; Reset wipes progress and re-earns it from your history.")
            }

            // Claude  Date 06/16/2026
            // Alpha dev-only coin grants, so the wallet can be topped up to test the
            // shop + animated card purchases without grinding workouts. Spendable
            // balance is the shared pool (earned − spent), shown live here.
            Section {
                LabeledContent("Coins") {
                    Text("\(theme.balance(earned: store.totalCoinsEarned))")
                        .monospacedDigit()
                        .foregroundStyle(theme.current.accent)
                }
                Button("Add 500 coins") { store.grantDevCoins(500) }
                Button("Add 2,000 coins") { store.grantDevCoins(2_000) }
                Button("Reset dev coins", role: .destructive) { store.resetDevCoins() }
            } header: {
                Text("Developer coins (alpha)")
            } footer: {
                Text("Adds free coins to the spendable balance for testing the Shop and animated profile cards. Reset clears only the dev grant — coins earned from workouts and achievements are untouched.")
            }

            #if DEBUG
            // Claude  Date 06/17/2026
            // Temporary verification for the barcode cache (no scanner UI yet).
            // Resolves a known barcode twice through CachedFoodService and prints the
            // paths to the Xcode console. Remove once the real scanner exercises it.
            Section {
                LabeledContent("Cached barcodes", value: "\(store.barcodeCache.entries.count)")
                Button("Test barcode cache") { runBarcodeCacheTest() }
            } header: {
                Text("Barcode cache (debug)")
            } footer: {
                Text("Resolves Nutella (3017620422003) twice: 1st hits Open Food Facts and caches it, 2nd returns from cache. Watch the Xcode console; also runs the LRU cap check.")
            }
            #endif
        }
        .navigationTitle("Settings")
        .themed(theme.current)
    }

    #if DEBUG
    // Claude  Date 06/17/2026
    // Drives the "Barcode cache (debug)" section: a cold lookup should hit the
    // network and grow the cache by one; the second should resolve from cache.
    private func runBarcodeCacheTest() {
        let service = CachedFoodService(base: OpenFoodFactsClient(), store: store)
        let barcode = "3017620422003" // Nutella — well-populated on Open Food Facts.
        print("🔖 [barcode cache] \(BarcodeCache.debugRunLRUCheck())")
        Task { @MainActor in
            let before = store.barcodeCache.entries.count
            let wasCached = store.barcodeCache.contains(barcode)
            let first = try? await service.lookup(barcode: barcode)
            print("🔖 [barcode cache] 1st lookup (\(wasCached ? "already cached" : "cold → network")): \(first?.name ?? "nil") · entries \(before)→\(store.barcodeCache.entries.count)")
            let second = try? await service.lookup(barcode: barcode)
            print("🔖 [barcode cache] 2nd lookup (from cache): \(second?.name ?? "nil") · entries \(store.barcodeCache.entries.count)")
        }
    }
    #endif
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppStore())
            .environmentObject(ThemeManager())
    }
}
