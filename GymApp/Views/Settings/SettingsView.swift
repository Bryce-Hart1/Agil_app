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
    // CLAUDE  Date 09/19/2026 — weight, body metrics and the calorie plan (encrypted vault).
    @EnvironmentObject private var bodyStore: BodyStore
    @AppStorage(BodyUnits.storageKey) private var bodyUnitsRaw = BodyUnits.defaultValue.rawValue
    @AppStorage(BodyPlanCard.showWeightKey) private var showWeightOnJournal = true
    @State private var showEraseBodyConfirm = false
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
    @AppStorage(WaterTracking.storageKey) private var trackWater = WaterTracking.defaultValue
    // Claude  Date 09/07/2026
    // Cardio display settings. The distance unit is a plain @AppStorage like the water one;
    // the bodyweight lives on UserProfile instead, because it's personal data covered by the
    // privacy contract rather than a display preference.
    @AppStorage(DistanceUnit.storageKey) private var distanceUnitRaw = DistanceUnit.miles.rawValue
    // Claude  Date 07/14/2026
    // For "Replay app tour": Settings is pushed on the Profile stack, so pop back
    // first — the tour spotlights root-level chrome (ModeNotch, tab bar) that a
    // pushed screen covers.
    @Environment(\.dismiss) private var dismiss
    // Claude  Date 09/06/2026
    // Gates the "are you sure" alert before Friends → Ghost, which schedules a
    // permanent server-side wipe of the shared card + friends graph.
    @State private var showGhostModeConfirm = false
    // Claude  Date 09/06/2026
    // Delete Account is a two-step gate: a warning alert, then a second alert that
    // only proceeds if the user literally types DELETE (mismatch → the third alert).
    // `isDeleting` blocks a second tap while the teardown is in flight.
    @State private var showDeleteAccountWarning = false
    @State private var showDeleteAccountConfirm = false
    @State private var showDeleteMismatch = false
    @State private var deleteConfirmText = ""
    @State private var isDeleting = false

    // Claude  Date 09/06/2026
    // The Danger section's colour. Deliberately the system red rather than
    // theme.current.accent — a destructive zone must look destructive in every theme,
    // including the ones whose accent IS red-ish or whose accent is a soft pastel.
    private static let danger = Color.red

    var body: some View {
        List {
            // Claude  Date 06/09/2026 last changed: 09/19/2026 by: Claude
            // Profile: name (a deliberate rename screen, since it carries backend weight)
            // and identity. Identity is on-device only and just calibrates strength-badge
            // thresholds; changing it quietly re-checks achievements (see identityBinding).
            Section {
                NavigationLink {
                    ChangeNameView()
                } label: {
                    HStack {
                        Label("Change Name", systemImage: "person.text.rectangle")
                        Spacer()
                        Text(store.profile.resolvedName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                Picker("Identify as", selection: identityBinding) {
                    Text("Male").tag(Gender.male)
                    Text("Female").tag(Gender.female)
                    Text("Prefer not to say").tag(Gender.unspecified)
                }
                // Claude  Date 07/16/2026
                // retintOnThemeChange (on every menu picker here): Settings stays alive
                // under the Theme screen, so its pickers would keep the old accent after
                // a theme swap. Rebuilding them re-reads the new tint.
                .retintOnThemeChange(theme.current, salt: "identity")
            } header: {
                Text("Profile")
            } footer: {
                Text("Identity only helps set fair badge goals. It never leaves your phone.")
            }

            // Claude  Date 09/18/2026 last changed: 09/19/2026 by: Claude
            // Everything visual in one place: theme, the system-font override (see
            // ThemeManager.fontDesign) and the rest timer's face (same key
            // RestTimerFullScreenView reads).
            Section {
                NavigationLink {
                    ThemeSettingsView()
                } label: {
                    HStack {
                        Label("Theme", systemImage: "paintpalette")
                        Spacer()
                        Text(theme.current.name).foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $theme.usesSystemFont) {
                    Label("Use system font", systemImage: "textformat")
                }
                Toggle(isOn: $restTimerAnalogStyle) {
                    Label("Analog rest timer", systemImage: "stopwatch")
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("System font swaps your theme's font for Apple's standard one.")
            }

            // Claude  Date 06/18/2026 last changed: 09/19/2026 by: Claude
            // Friends: your shareable code and the friends manager. The Ghost Mode switch
            // lives in Danger, since flipping it schedules a server-side wipe.
            Section {
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
                Text(store.profile.dataMode == .friends
                     ? "Friends only see your profile card. Your workouts and meals stay on your phone."
                     : "Ghost Mode is on, so sharing is off. You can change that under Danger.")
            }

            // Claude  Date 07/16/2026 last changed: 09/19/2026 by: Claude
            // Food and water. Local lookups gate Open Food Facts (search + barcode) behind
            // an opt-in (key `offlineFoodMode`). Water is opt-out and stored in ml, so the
            // units picker is display only; it hides along with the tracker.
            Section {
                Toggle("Local food lookups only", isOn: $offlineFoodMode)
                Toggle("Track water", isOn: $trackWater)
                if trackWater {
                    Picker("Water units", selection: $waterUnitRaw) {
                        ForEach(WaterUnit.allCases) { unit in
                            Text(unit.label).tag(unit.rawValue)
                        }
                    }
                    .retintOnThemeChange(theme.current, salt: "waterUnits")
                }
            } header: {
                Text("Nutrition")
            } footer: {
                Text("Local lookups only search foods saved on your phone.")
            }

            // Claude  Date 09/07/2026 last changed: 09/19/2026 by: Claude
            // Cardio: bodyweight for the MET calorie estimate (optional, on-device) and
            // the distance display unit. Bouts are stored in seconds and meters, so
            // flipping the unit never rewrites history.
            Section {
                HStack {
                    Text("Bodyweight")
                    Spacer()
                    TextField("Optional", text: bodyweightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("lb").foregroundStyle(.secondary)
                }
                Picker("Distance", selection: $distanceUnitRaw) {
                    ForEach(DistanceUnit.allCases) { unit in
                        Text(unit.label).tag(unit.rawValue)
                    }
                }
                .retintOnThemeChange(theme.current, salt: "distanceUnits")
            } header: {
                Text("Cardio")
            } footer: {
                // CLAUDE  Date 09/19/2026 — weigh-ins, when there are any, now take over from
                // this field for calorie estimates; it stays as the answer for everyone else.
                Text(bodyStore.latestWeightLb == nil
                     ? "Your weight is only used to estimate calories burned. It stays on your phone."
                     : "Calorie estimates use your latest weigh-in. This is the fallback if you stop logging.")
            }

            bodySection

            // Claude  Date 07/14/2026 last changed: 09/19/2026 by: Claude
            // Help + About together. Replay pops Settings first (the tour spotlights root
            // chrome a pushed screen covers); the delay lets the pop land before it starts.
            Section {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        store.startTour()
                    }
                } label: {
                    Label("Replay app tour", systemImage: "sparkles.rectangle.stack")
                }
                NavigationLink {
                    HelpGuidesView()
                } label: {
                    Label("Help & Demos", systemImage: "questionmark.circle")
                }
                // CLAUDE  Date 09/19/2026 — what the calorie plan is and isn't, how it's
                // worked out, and where the body data lives. Readable without a plan.
                NavigationLink {
                    HealthSafetyView()
                } label: {
                    Label("Health & safety", systemImage: "heart.text.square")
                }
                LabeledContent("Version", value: "0.1.0")
            } header: {
                Text("Help & About")
            } footer: {
                Text("Agil: Your Bench & Marking App")
            }

            dangerSection

            // Claude  Date 09/19/2026
            // Every beta/debug tool lives one level down in DevToolsView, last on the
            // list, so the main screen stays about settings.
            Section {
                NavigationLink {
                    DevToolsView()
                } label: {
                    Label("Dev", systemImage: "hammer")
                }
            } footer: {
                Text("Beta testing tools.")
            }
        }
        .navigationTitle("Settings")
        .themed(theme.current)
        // Claude  Date 09/06/2026
        // Confirm before Friends → Ghost. The switch doesn't flip until "Turn on
        // Ghost Mode" is tapped (see ghostModeBinding); the actual server wipe is
        // still deferred 24h by CardSyncService so this is undoable even after.
        .alert("Turn on Ghost Mode?", isPresented: $showGhostModeConfirm) {
            Button("Turn on Ghost Mode", role: .destructive) {
                store.profile.dataMode = .ghost
                cardSync.handleModeChange(to: .ghost, store: store)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes your shared card, friend code, and friends list from the server. Nothing on this device is touched.\n\nYou have 24 hours to undo it: turn Ghost Mode back off within a day and everything is restored. After that it's gone for good and can't be recovered.")
        }
        // Claude  Date 09/06/2026
        // Delete Account, step 1: spell out the blast radius. "Continue" only opens
        // the typing gate below — nothing is destroyed until DELETE is typed.
        .alert("Delete Account?", isPresented: $showDeleteAccountWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                deleteConfirmText = ""
                showDeleteAccountConfirm = true
            }
        } message: {
            Text("This erases everything, immediately and permanently:\n\n• Your account, shared card, friend code, and friends list on the server\n• Every workout, exercise, meal, water and supplement log on this device\n• Every badge, rank and theme you've unlocked\n• Your weight history, body details and calorie plan\n• Your entire coin balance, including coins you purchased\n\nThere is no undo and no grace period. Agil will restart at the welcome screen.")
        }
        // Claude  Date 09/06/2026
        // Step 2: the typing gate. Alert buttons can't be reactively disabled from a
        // TextField's contents, so the button always fires and checks the text itself
        // — a mismatch falls through to the retry alert rather than deleting anything.
        .alert("Type DELETE to confirm", isPresented: $showDeleteAccountConfirm) {
            TextField("DELETE", text: $deleteConfirmText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { deleteConfirmText = "" }
            Button("Delete Everything", role: .destructive) {
                let matched = deleteConfirmText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased() == "DELETE"
                deleteConfirmText = ""
                if matched { runAccountDeletion() } else { showDeleteMismatch = true }
            }
        } message: {
            Text("Last step. Type DELETE in the field above to erase your account and all of your data.")
        }
        // Claude  Date 09/06/2026
        // Step 2 failed the text check. Nothing was deleted; offer another go.
        .alert("That didn't match", isPresented: $showDeleteMismatch) {
            Button("Cancel", role: .cancel) { }
            Button("Try again") { showDeleteAccountConfirm = true }
        } message: {
            Text("Nothing has been deleted. You have to type DELETE exactly to confirm.")
        }
    }

    // Claude  Date 09/06/2026 last changed: 09/19/2026 by: Claude
    // The Danger zone: the two controls that destroy data the user can't get back.
    // Last of the real settings (only the Dev link sits below). Fixed red tint and a
    // red leading edge so it reads as a hazard band in any theme.
    private var dangerSection: some View {
        Section {
            Toggle("Ghost Mode", isOn: ghostModeBinding)

            // The 24h undo window is open: the server copy hasn't been deleted yet.
            // Spell out the deadline and how to reverse it.
            if let due = cardSync.pendingCardDeletionDate {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Deletion scheduled", systemImage: "clock.badge.exclamationmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Self.danger)
                    Text("Your shared card and friends list will be deleted on \(due.formatted(date: .abbreviated, time: .shortened)). Turn Ghost Mode off before then to keep them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                showDeleteAccountWarning = true
            } label: {
                HStack {
                    Label("Delete Account", systemImage: "trash")
                        .foregroundStyle(Self.danger)
                    if isDeleting {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isDeleting)
        } header: {
            Text("Danger")
                .foregroundStyle(Self.danger)
        } footer: {
            Text("Ghost Mode turns off sharing and removes your card from our server. You have 24 hours to undo it.\n\nDelete Account erases everything, including coins you bought. This can't be undone.")
        }
        // Fixed red regardless of the equipped theme: tints the switch and the
        // ProgressView, and paints the hazard band over the theme's surface.
        .tint(Self.danger)
        .listRowBackground(
            theme.current.surface
                .overlay(Self.danger.opacity(0.10))
                .overlay(alignment: .leading) {
                    Rectangle().fill(Self.danger).frame(width: 3)
                }
        )
    }

    // CLAUDE  Date 09/19/2026
    // Body & Plan: display units, whether the Journal card shows the number, and the erase.
    // The plan's own settings (phase, pace, check-in day) live in the hub, not here — this is
    // for the handful of choices that outlive any one plan.
    private var bodySection: some View {
        Section {
            Picker("Body units", selection: $bodyUnitsRaw) {
                ForEach(BodyUnits.allCases) { unit in
                    Text(unit.label).tag(unit.rawValue)
                }
            }
            .retintOnThemeChange(theme.current, salt: "bodyUnits")

            Toggle("Show weight in the Journal", isOn: $showWeightOnJournal)

            Button(role: .destructive) {
                showEraseBodyConfirm = true
            } label: {
                Label("Erase body data", systemImage: "trash")
            }
        } header: {
            Text("Body & Plan")
        } footer: {
            Text("Your weight, body details and plan are stored only on this iPhone, encrypted, and only an encrypted backup can carry them to a new phone. Turning off the Journal number hides it without hiding the plan.")
        }
        .confirmationDialog("Erase body data?", isPresented: $showEraseBodyConfirm,
                            titleVisibility: .visible) {
            Button("Erase", role: .destructive) {
                bodyStore.eraseAll()
                store.profile.bodyweightLb = nil
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Deletes every weigh-in, your body details, your plan and its check-ins, plus the cardio bodyweight. Your calorie and macro goals stay as they are. This can't be undone.")
        }
    }

    // Claude  Date 09/06/2026
    // Step 3 of Delete Account (the typed DELETE matched). Runs the full teardown,
    // then pops Settings — RootTabView re-presents onboarding on its own once
    // profile.hasOnboarded goes false.
    private func runAccountDeletion() {
        isDeleting = true
        Task { @MainActor in
            await AccountDeletion.eraseEverything(store: store, theme: theme,
                                                  cardSync: cardSync, body: bodyStore)
            isDeleting = false
            dismiss()
        }
    }

    // Claude  Date 06/18/2026
    // Claude  Date 06/18/2026 last changed: 07/23/2026 by: Claude
    // Drives the Ghost Mode toggle: flips UserProfile.dataMode (persisted via the
    // profile's didSet) and tells the sync service to tear down the shared card (Ghost)
    // or push it (Friends). Polarity is ghost-first — ON = Ghost Mode — so the switch
    // matches the feature name everywhere else. Turning it OFF (→ Friends) mints the
    // device identity on first use.
    private var ghostModeBinding: Binding<Bool> {
        Binding(
            get: { store.profile.dataMode == .ghost },
            set: { isOn in
                if isOn {
                    // Friends → Ghost is destructive (schedules a server-side wipe).
                    // Route through the confirm alert and leave the mode untouched
                    // until they agree — the toggle snaps back on its own meanwhile.
                    if store.profile.dataMode == .friends {
                        showGhostModeConfirm = true
                    }
                } else {
                    // Ghost → Friends (incl. cancelling a pending deletion): safe,
                    // apply immediately.
                    store.profile.dataMode = .friends
                    cardSync.handleModeChange(to: .friends, store: store)
                }
            }
        )
    }

    // Claude  Date 07/14/2026
    // Drives the Identity picker: persists via the profile's didSet, then silently
    // re-evaluates achievements against the newly selected catalog (announce: false —
    // flipping a picker shouldn't fire a celebration wall). Unlocks are sticky, so
    // switching identities never removes an earned badge.
    // Claude  Date 09/07/2026
    // Drives the Cardio bodyweight field. A String binding rather than a numeric one so the
    // field can be genuinely EMPTY — this value is optional, and an empty box is the honest
    // rendering of "not given", where a numeric binding would sit at 0. Blank writes back
    // nil, which is what hides every calorie estimate instead of showing a 0 kcal one.
    // Clamped at 1500 lb: past the heaviest human on record, so it rejects a fat-fingered
    // extra digit without ever standing in a real user's way.
    private var bodyweightText: Binding<String> {
        Binding(
            get: {
                guard let lb = store.profile.bodyweightLb, lb > 0 else { return "" }
                return lb.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(lb)) : String(lb)
            },
            set: { text in
                let value = Double(text.filter { $0.isNumber || $0 == "." }) ?? 0
                store.profile.bodyweightLb = value > 0 ? Swift.min(value, 1_500) : nil
            }
        )
    }

    private var identityBinding: Binding<Gender> {
        Binding(
            get: { store.profile.gender },
            set: { newValue in
                store.profile.gender = newValue
                store.evaluateAchievements(announce: false)
            }
        )
    }
}

// Claude  Date 07/22/2026
// Deliberate rename screen (pushed from Settings › Profile). Edits a local draft and only
// writes back on Save — unlike the old always-live card field — so there's exactly one
// commit point. TODO(Bryce): fire the backend "change name" request from `save()` and gate
// the local write / navigation on its result.
private struct ChangeNameView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    // The pending edit, seeded from the current name (raw, not the "Your Name" fallback).
    @State private var draft: String = ""

    // Trimmed, non-empty, and actually different from what's stored.
    private var trimmed: String { draft.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool {
        !trimmed.isEmpty && trimmed != store.profile.displayName.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        Form {
            Section {
                TextField("Display name", text: $draft)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($focused)
                    .onSubmit { if canSave { save() } }
            } footer: {
                Text("This is the name shown on your profile card.")
            }
        }
        .navigationTitle("Change Name")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }.disabled(!canSave)
            }
        }
        .onAppear {
            draft = store.profile.displayName
            focused = true
        }
    }

    private func save() {
        guard canSave else { return }
        // TODO(Bryce): send the rename to the backend here; on success apply locally.
        store.profile.displayName = trimmed
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppStore())
            .environmentObject(ThemeManager())
            .environmentObject(CardSyncService())
    }
}
