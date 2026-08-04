import SwiftUI

#if DEBUG
// Claude  Date 07/09/2026
// DEBUG-only playground for the RankRing / promotion visuals. Lets you scrub every knob
// (rank, size, the newest-segment reveal sweep, next-rank progress, core style) and watch
// it live, see all seven ranks side by side, and fire the real RankPromotionOverlay for
// any rank on demand (via store.previewPromotion, which plays over the whole app). Wrapped
// in #if DEBUG so it never ships. Reached from Settings → Rank ring lab (debug).
struct RankRingLabView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @State private var rank: StrategistRank = .warrior
    @State private var size: CGFloat = 120
    @State private var reveal: Double = 1
    @State private var progress: Double = 0.5
    @State private var showsProgress = true
    @State private var progressFill = false   // false = rank map, true = progress meter
    // Claude  Date 08/02/2026
    // (Was a `useAvatar` Bool. Characters made the core a three-way choice, and seeing a
    // character sit inside the 0.54x core slot is exactly what needs eyeballing.)
    @State private var coreStyle: CoreStyle = .character

    private enum CoreStyle: String, CaseIterable, Identifiable {
        case character, avatar, initials
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    var body: some View {
        List {
            liveSection
            controlsSection
            characterSection
            gallerySection
            promotionSection
        }
        .navigationTitle("Rank ring lab")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
    }

    // Claude  Date 08/02/2026
    // Every character knob in one place, writing straight to the real profile — so whatever
    // you set here is what the card, the friend row and the badge's reverse face all show.
    // Shuffle is the fast way to sweep combinations; the size row is the legibility check
    // the compositor's stroke floors and detail gate exist for.
    private var characterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach([CGFloat(28), 38, 46, 60, 65, 92, 120], id: \.self) { s in
                        VStack(spacing: 4) {
                            CharacterView(character: labCharacterForced, size: s)
                            Text("\(Int(s))").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.black.opacity(0.85))

            ForEach(CharacterSlot.allCases) { slot in
                Picker(slot.title, selection: optionBinding(slot)) {
                    ForEach(CharacterCatalog.options(for: slot)) { Text($0.name).tag($0.id) }
                }
                .retintOnThemeChange(theme.current, salt: "charslot-\(slot.rawValue)")
            }

            ForEach(CharacterColorRole.allCases.filter(\.isUserPickable)) { role in
                Picker(role.title, selection: tokenBinding(role)) {
                    ForEach(CharacterCatalog.swatches(for: role)) { Text($0.name).tag($0.id) }
                }
                .retintOnThemeChange(theme.current, salt: "charrole-\(role.rawValue)")
            }

            Toggle("Characters enabled", isOn: $store.profile.character.isEnabled)

            Button("Shuffle") {
                var c = UserCharacter.random()
                c.isEnabled = store.profile.character.isEnabled
                store.profile.character = c
            }
            .foregroundStyle(theme.current.accent)
        } header: {
            Text("Character")
        } footer: {
            Text("Writes to your real profile. The size row is the legibility check: below 36pt the brows, mouth and glasses bridge are dropped on purpose.")
        }
    }

    private func optionBinding(_ slot: CharacterSlot) -> Binding<String> {
        Binding(get: { store.profile.character.option(for: slot).id },
                set: { store.profile.character.set($0, for: slot) })
    }

    private func tokenBinding(_ role: CharacterColorRole) -> Binding<String> {
        Binding(get: { store.profile.character.token(for: role) },
                set: { store.profile.character.set(token: $0, for: role) })
    }

    /// The character with `isEnabled` forced on, so the lab can inspect it either way.
    private var labCharacterForced: UserCharacter {
        var c = store.profile.character
        c.isEnabled = true
        return c
    }

    // The single ring under test, centered on a neutral card so the aura/glow read.
    private var liveSection: some View {
        Section {
            RankRing(rank: rank, progress: progress, size: size,
                     showsProgress: showsProgress, revealProgress: reveal,
                     fillMode: progressFill ? .rankProgress : .rankSegments) {
                core(diameter: RingGeometry.coreDiameter(for: size))
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .padding(.vertical, 12)
            .listRowBackground(Color.black.opacity(0.85))
        } header: {
            Text(progressFill
                 ? "\(rank.title) · \(Int(progress * 100))% to next · \(Int(size))pt"
                 : "\(rank.title) · \(rank.rawValue + 1)/7 segments · \(Int(size))pt")
        }
    }

    private var controlsSection: some View {
        Section("Controls") {
            Picker("Rank", selection: $rank) {
                ForEach(StrategistRank.allCases, id: \.self) { Text($0.title).tag($0) }
            }

            Picker("Fill mode", selection: $progressFill) {
                Text("Rank map").tag(false)
                Text("Progress to next").tag(true)
            }
            .pickerStyle(.segmented)

            slider("Size", value: $size, range: 40...160, format: "\(Int(size))pt")
            slider("Reveal (newest seg)", value: $reveal, range: 0...1, format: pct(reveal))
            slider("Progress (next rank)", value: $progress, range: 0...1, format: pct(progress))

            Toggle("Show next-rank progress", isOn: $showsProgress)

            Picker("Core", selection: $coreStyle) {
                ForEach(CoreStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Button("Replay segment reveal") {
                reveal = 0
                withAnimation(.easeInOut(duration: 0.8)) { reveal = 1 }
            }
            .foregroundStyle(theme.current.accent)
        }
    }

    // All seven ranks at a glance — the visual-QA row the design doc asks for.
    private var gallerySection: some View {
        Section("All ranks") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(StrategistRank.allCases, id: \.self) { r in
                        VStack(spacing: 6) {
                            RankRing(rank: r, progress: 0.5, size: 72, showsProgress: false) {
                                RankRingInitials(name: store.profile.resolvedName, size: 72)
                            }
                            Text(r.title).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.black.opacity(0.85))
        }
    }

    // Fires the actual promotion overlay (mounted at RootTabView) so the crest spring-in +
    // segment sweep + confetti play exactly as they do on a real rank-up.
    private var promotionSection: some View {
        Section {
            ForEach(StrategistRank.allCases, id: \.self) { r in
                Button {
                    store.previewPromotion(r)
                } label: {
                    Label("Play promotion → \(r.title)", systemImage: "sparkles")
                }
            }
        } header: {
            Text("Promotion overlay")
        } footer: {
            Text("Plays the real RankPromotionOverlay over the whole app (non-persistent — your actual rank is untouched). Tap the overlay to dismiss and return here.")
        }
    }

    @ViewBuilder private func core(diameter: CGFloat) -> some View {
        // Claude  Date 08/02/2026
        // Routed through ProfileFaceView so the lab exercises the SAME precedence the real
        // card does — forcing a branch here is just a matter of what we hand it.
        ProfileFaceView(
            character: labCharacter,
            avatarID: coreStyle == .initials ? nil : store.profile.avatarID,
            name: store.profile.resolvedName,
            size: diameter
        )
    }

    // Force-enabled: the lab inspects the character on demand, whether or not the user
    // currently has characters switched on.
    private var labCharacter: UserCharacter? {
        coreStyle == .character ? labCharacterForced : nil
    }

    private func slider(_ title: String, value: Binding<CGFloat>,
                        range: ClosedRange<CGFloat>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            LabeledContent(title, value: format)
            Slider(value: value, in: range)
        }
    }

    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            LabeledContent(title, value: format)
            Slider(value: value, in: range)
        }
    }

    private func pct(_ v: Double) -> String { "\(Int(v * 100))%" }
}

#Preview {
    NavigationStack { RankRingLabView() }
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
#endif
