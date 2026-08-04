import SwiftUI

// Claude  Date 08/02/2026
// The character customizer — the single implementation behind BOTH entry points: the
// Character tab in Edit Profile Card, and the sheet you get by tapping the face on the live
// card (FaceEditorSheet, which is just a NavigationStack + Done around this).
//
// It's a bare `List` with no navigation chrome of its own precisely so it can be hosted
// either way. Anything host-specific (title, Done button, dismissal) belongs to the host.
//
// The on/off switch is framed as a MODE, not a disable — "off" isn't nothing, it's the stock
// Avatar catalogue — and the avatar half is the old AvatarPickerSheet moved across verbatim,
// coin economy and all. The rank toggle stays visible in both modes: being reachable when
// the ring is currently off is the entire reason that control lives with the face.
struct CharacterCustomizerView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    /// The avatar awaiting a buy-confirmation, if any.
    @State private var pendingAvatarPurchase: Avatar?
    /// Same, for a locked character option. Dormant while every option is free.
    @State private var pendingOptionPurchase: CharacterOption?
    @State private var tab: CharacterEditorTab = .skin
    /// Live value of the custom ColorPicker, per role. See scheduleCustomColour.
    @State private var draftColors: [String: Color] = [:]
    @State private var pendingColourCommit: DispatchWorkItem?

    private var balance: Int { theme.balance(earned: store.totalCoinsEarned) }
    private var character: UserCharacter { store.profile.character }
    private var accent: Color { theme.current.accent }

    var body: some View {
        List {
            previewSection
            modeSection
            if character.isEnabled {
                characterTabSection
                ForEach(tab.slots) { slot in optionSection(slot) }
                ForEach(tab.roles) { role in colourSection(role) }
                shuffleSection
            } else {
                avatarSection
            }
        }
        .themed(theme.current)
        .alert("Buy Avatar", isPresented: avatarPurchaseAlertBinding, presenting: pendingAvatarPurchase) { avatar in
            Button("Buy for \(avatar.price)") { confirmAvatarPurchase(avatar) }
            Button("Cancel", role: .cancel) {}
        } message: { avatar in
            Text("Unlock the \(avatar.name) avatar for \(avatar.price) coins?")
        }
        .alert("Buy Style", isPresented: optionPurchaseAlertBinding, presenting: pendingOptionPurchase) { option in
            Button("Buy for \(option.price)") { confirmOptionPurchase(option) }
            Button("Cancel", role: .cancel) {}
        } message: { option in
            Text("Unlock \(option.name) for \(option.price) coins?")
        }
    }

    // MARK: - Sections

    // The live face, updating as you tap. Watching the whole character change under your
    // finger is most of what makes this feel like control rather than a settings form.
    private var previewSection: some View {
        Section {
            ProfileFaceView(character: character,
                            avatarID: store.profile.avatarID,
                            name: store.profile.resolvedName,
                            size: 120)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .listRowBackground(Color.black.opacity(0.85))
        }
    }

    private var modeSection: some View {
        Section {
            Picker("Face", selection: characterEnabledBinding) {
                Text("Character").tag(true)
                Text("Avatar").tag(false)
            }
            .pickerStyle(.segmented)
        } footer: {
            Text(character.isEnabled
                 ? "Your character shows on your card, on the back of your Strategist badge, and to friends."
                 : "Using a classic avatar. Your character is saved — switch back any time.")
        }
    }

    private var characterTabSection: some View {
        Section {
            Picker("Part", selection: $tab) {
                ForEach(CharacterEditorTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private func optionSection(_ slot: CharacterSlot) -> some View {
        Section {
            CharacterOptionGrid(
                slot: slot,
                character: character,
                accent: accent,
                isUnlocked: { theme.isCharacterOptionUnlocked($0) },
                onSelect: { option in
                    tapHaptic()
                    store.profile.character.set(option.id, for: slot)
                },
                onBuy: { pendingOptionPurchase = $0 }
            )
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        } header: {
            Text(slot.title)
        }
    }

    private func colourSection(_ role: CharacterColorRole) -> some View {
        Section {
            CharacterSwatchStrip(
                role: role,
                selectedToken: character.token(for: role),
                accent: accent,
                custom: bindingForDraft(role),
                onSelect: { token in
                    tapHaptic()
                    store.profile.character.set(token: token, for: role)
                }
            )
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        } header: {
            Text(role.title)
        }
    }

    // Claude  Date 08/02/2026
    // Rows rather than a toolbar menu: this view is hosted both inline (the Character tab)
    // and in a sheet, and a row works identically in both without the host having to
    // contribute toolbar items.
    private var shuffleSection: some View {
        Section {
            Button {
                tapHaptic()
                store.profile.character = keepingEnabled(.random())
            } label: {
                Label("Shuffle", systemImage: "dice")
            }
            .foregroundStyle(accent)

            Button(role: .destructive) {
                store.profile.character = keepingEnabled(.default)
            } label: {
                Label("Reset to default", systemImage: "arrow.uturn.backward")
            }
        } footer: {
            Text("Shuffle rolls every part and colour at once — the fastest way to find a look you like.")
        }
    }

    // The stock-avatar half, moved across unchanged — same strip, same coin footer, same
    // buy alert. Nothing about the avatar economy changed when characters landed.
    private var avatarSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Avatar.all) { avatar in
                        AvatarPickCell(
                            avatar: avatar,
                            accent: accent,
                            isSelected: store.profile.avatarID == avatar.id,
                            isUnlocked: theme.isAvatarUnlocked(avatar),
                            canAfford: balance >= avatar.price,
                            onSelect: { store.profile.avatarID = avatar.id },
                            onBuy: { pendingAvatarPurchase = avatar }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            Text("Avatar")
        } footer: {
            Text("Coins: \(balance)")
        }
    }

    // MARK: - Plumbing

    /// Shuffling or resetting must never silently switch modes on the user.
    private func keepingEnabled(_ new: UserCharacter) -> UserCharacter {
        var copy = new
        copy.isEnabled = store.profile.character.isEnabled
        return copy
    }

    private var characterEnabledBinding: Binding<Bool> {
        Binding(get: { store.profile.character.isEnabled },
                set: { store.profile.character.isEnabled = $0 })
    }

    private var avatarPurchaseAlertBinding: Binding<Bool> {
        Binding(get: { pendingAvatarPurchase != nil },
                set: { if !$0 { pendingAvatarPurchase = nil } })
    }

    private var optionPurchaseAlertBinding: Binding<Bool> {
        Binding(get: { pendingOptionPurchase != nil },
                set: { if !$0 { pendingOptionPurchase = nil } })
    }

    /// Buy, then equip the newly unlocked avatar.
    private func confirmAvatarPurchase(_ avatar: Avatar) {
        if theme.purchaseAvatar(avatar, balance: balance) {
            store.profile.avatarID = avatar.id
        }
        pendingAvatarPurchase = nil
    }

    /// Buy, then equip the newly unlocked style — same shape as the avatar flow.
    private func confirmOptionPurchase(_ option: CharacterOption) {
        if theme.purchaseCharacterOption(option, balance: balance) {
            store.profile.character.set(option.id, for: option.slot)
        }
        pendingOptionPurchase = nil
    }

    // Claude  Date 08/02/2026
    // ⚠️ The custom ColorPicker must NOT write straight into store.profile. Dragging round
    // the colour wheel emits dozens of changes a second, and every one of them would hit
    // AppStore.profile's didSet — a pretty-printed atomic JSON write to Documents — AND
    // RootTabView's .onChange(of: store.profile), which queues a card sync. The sync has its
    // own 0.8s debounce; the DISK WRITE has none. So the picker drives local state and only
    // the settled colour is committed. Discrete swatch taps bypass this — they're one write.
    private func bindingForDraft(_ role: CharacterColorRole) -> Binding<Color> {
        Binding(
            get: { draftColors[role.rawValue] ?? character.color(for: role) },
            set: { newValue in
                draftColors[role.rawValue] = newValue
                scheduleCustomColour(newValue, for: role)
            }
        )
    }

    private func scheduleCustomColour(_ color: Color, for role: CharacterColorRole) {
        pendingColourCommit?.cancel()
        let item = DispatchWorkItem {
            store.profile.character.set(token: color.toHex(), for: role)
        }
        pendingColourCommit = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }

    // iOS 16 target, so no .sensoryFeedback (17+). Matches OnboardingView's helper, which
    // is file-private there.
    private func tapHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - Editor grouping

// Claude  Date 08/02/2026
// A UI-only grouping over slots and colour roles. Users think "Hair", not "hairBack +
// hair + facialHair + hair colour" — and the indirection means the internal slot list can
// grow without the editor growing a tab per slot.
enum CharacterEditorTab: String, CaseIterable, Identifiable {
    case skin, hair, face, top, extras

    var id: String { rawValue }

    var title: String {
        switch self {
        case .skin:   return "Skin"
        case .hair:   return "Hair"
        case .face:   return "Face"
        case .top:    return "Top"
        case .extras: return "Extras"
        }
    }

    var slots: [CharacterSlot] {
        switch self {
        case .skin:   return [.head]
        case .hair:   return [.hair, .facialHair]
        case .face:   return [.face]
        case .top:    return [.top]
        case .extras: return [.accessory, .backdrop]
        }
    }

    var roles: [CharacterColorRole] {
        switch self {
        case .skin:   return [.skin]
        case .hair:   return [.hair]
        case .face:   return []
        case .top:    return [.top]
        case .extras: return [.accessory, .backdrop]
        }
    }
}

// MARK: - Pickers

// Claude  Date 08/02/2026
// The style grid for one slot. Copies IconGrid's exact visual language — adaptive grid,
// radius 10, accent-tinted fill and 2pt stroke when selected — so selection reads the same
// here as it does when picking a preset icon. (IconGrid itself is hardwired to
// PresetIcons.all + PresetIconView and can't be parameterized without rewriting it.)
//
// Each tile draws the WHOLE character with just this one slot swapped, which is far more
// legible than a floating disembodied hairstyle — and is why CharacterAssets memoizes its
// lookups, since a grid is a few hundred layer resolutions.
struct CharacterOptionGrid: View {
    let slot: CharacterSlot
    let character: UserCharacter
    let accent: Color
    /// Ownership gate. Every option is free today, so this is always true — but the grid
    /// routes through it anyway so a priced option can never become silently equippable.
    var isUnlocked: (CharacterOption) -> Bool = { _ in true }
    let onSelect: (CharacterOption) -> Void
    var onBuy: (CharacterOption) -> Void = { _ in }

    private let corner: CGFloat = 10

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 66), spacing: 12)], spacing: 12) {
            ForEach(CharacterCatalog.options(for: slot)) { option in
                let isSelected = character.option(for: slot).id == option.id
                let unlocked = isUnlocked(option)
                VStack(spacing: 4) {
                    CharacterView(character: character.setting(option.id, for: slot),
                                  size: 46,
                                  discColor: Color.gray.opacity(0.18),
                                  ringColor: .clear)
                        .opacity(unlocked ? 1 : 0.45)
                        .overlay(alignment: .bottomTrailing) {
                            if !unlocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .background(Circle().fill(.background).frame(width: 16, height: 16))
                            }
                        }
                    Text(unlocked ? option.name : "\(option.price)")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: corner)
                    .fill(isSelected ? accent.opacity(0.2) : .clear))
                .overlay(RoundedRectangle(cornerRadius: corner)
                    .stroke(isSelected ? accent : .gray.opacity(0.25),
                            lineWidth: isSelected ? 2 : 1))
                .contentShape(RoundedRectangle(cornerRadius: corner))
                .onTapGesture { unlocked ? onSelect(option) : onBuy(option) }
                .accessibilityLabel(unlocked ? option.name : "\(option.name), locked, \(option.price) coins")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

// Claude  Date 08/02/2026
// The colour row for one role: the curated swatches, then a ColorPicker chip for anything
// else. The chip is what turns "a few options" into actual control, and it costs nothing in
// the model — a colour token is already either a swatch id or a literal hex.
struct CharacterSwatchStrip: View {
    let role: CharacterColorRole
    let selectedToken: String
    let accent: Color
    @Binding var custom: Color
    let onSelect: (String) -> Void

    /// True when the current token is a hand-mixed hex rather than a catalogue swatch.
    private var isCustom: Bool { selectedToken.hasPrefix("#") }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CharacterCatalog.swatches(for: role)) { swatch in
                    swatchDot(swatch)
                }
                Divider().frame(height: 30)
                customChip
            }
            .padding(.vertical, 4)
        }
    }

    private func swatchDot(_ swatch: CharacterSwatch) -> some View {
        let isSelected = selectedToken == swatch.id
        return Circle()
            .fill(Color(hex: swatch.hex))
            .frame(width: 32, height: 32)
            .overlay(Circle().stroke(isSelected ? accent : .gray.opacity(0.3),
                                     lineWidth: isSelected ? 2.5 : 1))
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(accent)
                        .background(Circle().fill(.background))
                        .offset(x: 2, y: 2)
                }
            }
            .contentShape(Circle())
            .onTapGesture { onSelect(swatch.id) }
            .accessibilityLabel(swatch.name)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var customChip: some View {
        ColorPicker("", selection: $custom, supportsOpacity: false)
            .labelsHidden()
            .frame(width: 32, height: 32)
            .overlay(Circle().stroke(isCustom ? accent : .gray.opacity(0.3),
                                     lineWidth: isCustom ? 2.5 : 1))
            .accessibilityLabel("Custom \(role.title.lowercased())")
    }
}

#Preview {
    NavigationStack {
        CharacterCustomizerView()
            .navigationTitle("Your Character")
            .navigationBarTitleDisplayMode(.inline)
    }
    .environmentObject(AppStore())
    .environmentObject(ThemeManager())
}
