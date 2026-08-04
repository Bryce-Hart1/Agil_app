import SwiftUI

// Claude  Date 06/12/2026 last changed: 08/02/2026 by: Claude
// (07/22) Rebuilt as a tap-to-edit screen: the live profile card fills the view and each
// part of it is tappable — tap the avatar/rank, name, badges, or the header palette chip
// and the matching editor slides up as a bottom sheet. The old Form of stacked sections is
// gone; every control now lives behind the element it changes. The pickers themselves
// (card styles, avatars, coin/buy flow) are unchanged — just relocated into the sheets.
//
// (08/02) Two tabs now: CARD (the tap-to-edit card above) and CHARACTER (the full-screen
// customizer). The character has far too many knobs — 7 slots, 5 colour roles, a live
// preview — to live only behind a face tap on a bottom sheet; it needs a room of its own,
// and it needs to be findable without knowing the card is tappable. Both tabs and the face
// tap all drive the SAME CharacterCustomizerView, so there's one editor, not two.
// Temporary home while the build settles — if the character grows past what a tab here can
// hold, this lifts out to its own destination off the Profile hub with no changes to the
// customizer itself.
struct EditProfileCardView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    // Which element's editor is currently presented (nil = none).
    @State private var target: EditTarget?
    @State private var section: EditSection = .card

    private var stats: ProfileStats {
        ProfileStats(workouts: store.workouts, exercises: store.exercises)
    }

    // Claude  Date 08/02/2026
    // The two halves of this screen. Not an enum of sheets like EditTarget — these are
    // top-level modes, so they're a segmented control rather than a presentation.
    private enum EditSection: String, CaseIterable, Identifiable {
        case card, character
        var id: String { rawValue }
        var title: String { self == .card ? "Card" : "Character" }
    }

    // Claude  Date 07/22/2026
    // The tappable regions of the card, each mapped to a bottom sheet. `.rank` shares the
    // avatar sheet (the rank ring frames the avatar, so they're edited together). Name is
    // deliberately absent — renaming lives in Settings › Change Name, not on the card.
    private enum EditTarget: String, Identifiable {
        case style, avatar, badges
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $section) {
                ForEach(EditSection.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .retintOnThemeChange(theme.current, salt: "edit-profile-section")

            switch section {
            case .card:      cardTab
            case .character: CharacterCustomizerView()
            }
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationTitle(section == .card ? "Edit Profile Card" : "Your Character")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .sheet(item: $target) { target in
            switch target {
            case .style:
                CardStylePickerSheet()
                    .environmentObject(store)
                    .environmentObject(theme)
                    .presentationDetents([.medium, .large])
            case .avatar:
                // Claude  Date 08/02/2026
                // (Was AvatarPickerSheet. Now the same customizer the Character tab shows,
                // wrapped in sheet chrome — which is why it wants the full height.)
                FaceEditorSheet()
                    .environmentObject(store)
                    .environmentObject(theme)
                    .presentationDetents([.large])
            case .badges:
                NavigationStack { FeaturedBadgesView() }
                    .environmentObject(store)
                    .environmentObject(theme)
            }
        }
    }

    // The original tap-to-edit card, unchanged. The GeometryReader now measures the space
    // left under the tab picker, so the card still sizes itself to (almost) fill it.
    private var cardTab: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 12) {
                    ProfileShowcaseCard(
                        name: store.profile.resolvedName,
                        style: CardStyle.style(for: store.profile.cardStyleID),
                        unlockedIDs: store.unlockedAchievementIDs,
                        pinnedIDs: store.profile.showcasedAchievementIDs,
                        memberSince: stats.memberSince,
                        rank: store.strategistRank,
                        rankProgress: store.strategistProgress,
                        avatarID: store.profile.avatarID,
                        character: store.profile.character,
                        ringFillMode: .rankProgress,
                        catalog: store.achievementCatalog,
                        edit: ProfileCardEditActions(
                            background: { target = .style },
                            avatar: { target = .avatar },
                            badges: { target = .badges }
                        )
                    )
                    .frame(height: max(380, geo.size.height - 64))

                    Text("Tap any part of your card to edit it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Card style picker

// Claude  Date 07/22/2026
// The card-style chooser, raised by the header palette chip. Shows ONLY styles the user
// already owns — buying happens in the Shop, so this stays a clean "equip what you have"
// list with no coin/buy clutter. Applying a style updates the live card underneath
// immediately (store.profile is the shared source of truth).
private struct CardStylePickerSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    // Owned styles only, in catalog order.
    private var ownedStyles: [CardStyle] {
        CardStyle.all.filter { theme.isCardStyleUnlocked($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ownedStyles) { style in
                        CardStyleRow(
                            style: style,
                            isSelected: store.profile.cardStyleID == style.id,
                            isUnlocked: true,
                            canAfford: false,
                            onSelect: { store.profile.cardStyleID = style.id },
                            onBuy: {}
                        )
                    }
                } footer: {
                    Text("Unlock more styles in the Shop.")
                }
            }
            .navigationTitle("Card Style")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Rows (shared by the sheets above)
// (The avatar sheet + its cell moved to FaceEditorSheet.swift on 08/02/2026.)

// Claude  Date 06/13/2026 last changed: 06/13/2026 by: Claude
// One card-style row: a swatch (color fill or image thumbnail) + name, with a
// trailing control — selected (checkmark), owned (tap to apply), or locked (Buy
// button, disabled when unaffordable).
private struct CardStyleRow: View {
    let style: CardStyle
    let isSelected: Bool
    let isUnlocked: Bool
    let canAfford: Bool
    let onSelect: () -> Void
    let onBuy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            swatch
            // Claude  Date 06/16/2026 last changed: 06/16/2026 by: Claude
            // Name truncates if space is tight so it can never squeeze the badge or
            // buy button into wrapping (which made the price spill into a circle).
            Text(style.name)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            // Claude  Date 06/16/2026 — rarity badge (hidden for the free base).
            if let label = style.tier.label {
                tierBadge(label, color: style.tier.color)
            }
            Spacer(minLength: 8)
            trailing
        }
        .contentShape(Rectangle())
        .onTapGesture { if isUnlocked { onSelect() } }
    }

    // Claude  Date 06/16/2026
    // Small coloured capsule marking the card's rarity tier (Rare/Epic/Legendary).
    private func tierBadge(_ label: String, color: Color) -> some View {
        Text(label.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 0.5))
    }

    @ViewBuilder private var swatch: some View {
        Group {
            switch style.background {
            case .color(let hex):
                Circle().fill(Color(hex: hex))
            case .gradient(let from, let to):
                Circle().fill(LinearGradient(colors: [Color(hex: from), Color(hex: to)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
            case .image(let asset):
                Image(asset).resizable().scaledToFill()
            // Claude  Date 06/16/2026
            // Live animated preview right in the swatch so the motion sells itself.
            case .animated(let kind):
                AnimatedCardBackground(kind: kind)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .overlay(Circle().stroke(.quaternary))
    }

    @ViewBuilder private var trailing: some View {
        if isSelected {
            Image(systemName: "checkmark").fontWeight(.semibold)
        } else if isUnlocked {
            Text("Owned").font(.subheadline).foregroundStyle(.secondary)
        } else {
            Button(action: onBuy) {
                Label("\(style.price.formatted())", systemImage: "circle.hexagongrid.fill")
                    .font(.subheadline)
                    .lineLimit(1)
                    .fixedSize()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAfford)
            .opacity(canAfford ? 1 : 0.5)
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileCardView()
            .environmentObject(AppStore())
            .environmentObject(ThemeManager())
    }
}
