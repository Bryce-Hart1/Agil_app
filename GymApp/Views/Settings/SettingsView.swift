import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// App settings. Pushed from the Profile tab, so it does not host its own
/// navigation stack.
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    // Claude  Date 06/18/2026
    // Shared-card sync, for the Friends section (friend code + look up a friend).
    @EnvironmentObject private var cardSync: CardSyncService
    // Claude  Date 06/18/2026
    // Offline food mode (same key the food search + barcode scanner read): keeps food
    // lookups local unless the user explicitly chooses to go online for a given search.
    @AppStorage("offlineFoodMode") private var offlineFoodMode = false
    // Fable  Date 07/13/2026
    // Rest-timer face style (same key RestTimerFullScreenView reads): false keeps
    // the original progress ring, true swaps in the analog stopwatch face.
    @AppStorage("restTimerAnalogStyle") private var restTimerAnalogStyle = false
    // Claude  Date 07/16/2026
    // Water display unit (same key the diary tracker + goals editor read). Display
    // conversion only — everything stays stored in ml.
    @AppStorage(WaterUnit.storageKey) private var waterUnitRaw = WaterUnit.milliliters.rawValue
    // Claude  Date 07/14/2026
    // For "Replay app tour": Settings is pushed on the Profile stack, so pop back
    // first — the tour spotlights root-level chrome (ModeNotch, tab bar) that a
    // pushed screen covers.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // Claude  Date 06/09/2026
            // Editable display name, saved locally. Shown on the Profile card.
            Section("Profile") {
                TextField("Display name", text: $store.profile.displayName)
                    .textInputAutocapitalization(.words)
            }
            // Claude  Date 07/14/2026
            // Identity (from onboarding, editable here). On-device only; its sole
            // purpose is calibrating strength-badge thresholds. Changing it silently
            // re-evaluates achievements — see identityBinding. The footer restates
            // the privacy contract and the sticky-badge guarantee.
            Section {
                Picker("Identify as", selection: identityBinding) {
                    Text("Male").tag(Gender.male)
                    Text("Female").tag(Gender.female)
                    Text("Prefer not to say").tag(Gender.unspecified)
                }
                // Claude  Date 07/16/2026
                // retintOnThemeChange (here + the Units picker below): Settings sits
                // directly beneath the Theme screen on the Profile stack, so its menu
                // pickers are always alive during a theme swap and kept the old accent
                // baked into their value labels. Rebuilding re-reads the new tint.
                .retintOnThemeChange(theme.current, salt: "identity")
            } header: {
                Text("Identity")
            } footer: {
                Text("Stays on this device — never shared or uploaded. Used only to calibrate strength-badge thresholds. Badges you've already earned always stay earned.")
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
            // Fable  Date 07/13/2026
            // Opt-in analog stopwatch face for the full-screen rest timer; lives right
            // under Appearance since it's a purely visual preference.
            Section {
                Toggle("Analog stopwatch", isOn: $restTimerAnalogStyle)
            } header: {
                Text("Rest timer")
            } footer: {
                Text("Shows the full-screen rest timer as an analog stopwatch face instead of the progress ring.")
            }

            // Claude  Date 06/18/2026
            // Friends: opt into sharing just your profile card, see your friend code,
            // and look up a friend's card. The footer states the privacy contract.
            Section {
                Toggle("Friends mode", isOn: friendsModeBinding)

                if store.profile.dataMode == .friends, let code = cardSync.myFriendCode {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your friend code").font(.subheadline)
                            Text(code)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                        Spacer(minLength: 8)
                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = code
                            #endif
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                NavigationLink {
                    FriendsView()
                } label: {
                    Label("Manage friends", systemImage: "person.2")
                }
            } header: {
                Text("Friends")
            } footer: {
                Text("Friends mode shares only your profile card — display name, card style, equipped rank, and featured badges. Your workouts, nutrition, water, and everything else never leave this device. Turning it off deletes your shared card.")
            }

            // Claude  Date 06/18/2026
            // Offline food mode: gate Open Food Facts lookups (search + barcode) behind
            // an explicit opt-in, so the app stays local-first.
            Section {
                Toggle("Offline mode", isOn: $offlineFoodMode)
            } header: {
                Text("Food lookups")
            } footer: {
                Text("When on, food search and barcode scans only use foods saved on this device. If something isn't found, you'll be asked to enter it yourself or search Open Food Facts online just for that lookup.")
            }

            // Claude  Date 07/16/2026
            // Water display unit: ml or US fl oz, applied wherever water amounts show
            // (diary tracker, water goal). Logged history is canonical ml, so this is
            // safe to flip back and forth.
            Section {
                Picker("Units", selection: $waterUnitRaw) {
                    ForEach(WaterUnit.allCases) { unit in
                        Text(unit.label).tag(unit.rawValue)
                    }
                }
                .retintOnThemeChange(theme.current, salt: "waterUnits")
            } header: {
                Text("Water")
            } footer: {
                Text("Used wherever water amounts appear — the diary tracker and your daily goal. Logged water is stored in milliliters, so switching units never changes your history.")
            }

            // Claude  Date 07/14/2026
            // Replay the first-boot spotlight tour. Pops Settings first (see the
            // dismiss note above); the short delay lets the pop animation land before
            // the overlay appears and starts driving tabs/modes itself.
            Section {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        store.startTour()
                    }
                } label: {
                    Label("Replay app tour", systemImage: "sparkles.rectangle.stack")
                }
            } header: {
                Text("Help")
            } footer: {
                Text("Replays the guided tour of the app's main screens.")
            }

            Section("About") {
                LabeledContent("App", value: "Agil")
                LabeledContent("Tagline", value: "Your Bench & Marking App")
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
                // Claude  Date 07/12/2026
                // Previews the future IAP "Founders Edition" purchase moment: grants the
                // founders cards (idempotent — they're auto-granted on launch too) and
                // plays the unlock celebration. Replayable any time.
                Button("Unlock Founders cards") {
                    theme.grantFoundersCards()
                    store.celebrateFoundersUnlock()
                }
            } header: {
                Text("Developer (alpha)")
            } footer: {
                Text("Gallery previews every badge + rank (tap to play its celebration). Unlock all fills in every badge so the card and lists populate. Replay re-plays earned unlocks; Reset wipes progress and re-earns it from your history. Unlock Founders cards plays the founders unlock celebration (a preview of the future in-app purchase).")
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
            // Claude  Date 07/09/2026
            // Live playground for the rank ring + promotion animations (see RankRingLabView).
            Section {
                NavigationLink { RankRingLabView() } label: {
                    Label("Rank ring lab", systemImage: "circle.hexagongrid.fill")
                }
            } header: {
                Text("Rank ring (debug)")
            } footer: {
                Text("Scrub every rank, size, and the segment-reveal sweep live, and fire the real promotion overlay for any rank.")
            }

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

    // Claude  Date 06/18/2026
    // Drives the Friends-mode toggle: flips UserProfile.dataMode (persisted via the
    // profile's didSet) and tells the sync service to push (Friends) or tear down the
    // shared card (Offline). The first flip to Friends also mints the device identity.
    private var friendsModeBinding: Binding<Bool> {
        Binding(
            get: { store.profile.dataMode == .friends },
            set: { isOn in
                let mode: DataMode = isOn ? .friends : .offline
                store.profile.dataMode = mode
                cardSync.handleModeChange(to: mode, store: store)
            }
        )
    }

    // Claude  Date 07/14/2026
    // Drives the Identity picker: persists via the profile's didSet, then silently
    // re-evaluates achievements against the newly selected catalog (announce: false —
    // flipping a picker shouldn't fire a celebration wall). Unlocks are sticky, so
    // switching identities never removes an earned badge.
    private var identityBinding: Binding<Gender> {
        Binding(
            get: { store.profile.gender },
            set: { newValue in
                store.profile.gender = newValue
                store.evaluateAchievements(announce: false)
            }
        )
    }

    #if DEBUG
    // Claude  Date 06/17/2026
    // Drives the "Barcode cache (debug)" section: a cold lookup should hit the
    // network and grow the cache by one; the second should resolve from cache.
    private func runBarcodeCacheTest() {
        let service = CachedFoodService(base: BackendFoodClient(), store: store)
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
            .environmentObject(CardSyncService())
    }
}
