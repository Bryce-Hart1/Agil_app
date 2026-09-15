import SwiftUI

// Claude  Date 06/12/2026 last changed: 08/07/2026 by: Claude
// (07/22) Rebuilt as a tap-to-edit screen: the live profile card fills the view and each
// part of it is tappable — tap the background or the badges and the matching editor slides
// up as a bottom sheet. The old Form of stacked sections is gone; every control now lives
// behind the element it changes.
//
// (08/07) Back to a single screen. This briefly carried a second CHARACTER tab for the
// customizable profile face; that feature is gone, and with it the face tap on the card —
// the picture is the rank emblem now, which is earned rather than edited.
//
// (09/05) Two screens again, but as two FACES of one card rather than two tabs: the
// segmented control at the top turns the card over, and the back's background and stats
// are edited by tapping them exactly as the front's are.
struct EditProfileCardView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    // Which element's editor is currently presented (nil = none).
    @State private var target: EditTarget?
    // CLAUDE  Date 09/05/2026
    // The face being edited, and the back's resolved numbers. `face` drives the real
    // flip, so the segmented control and the card preview can never disagree. backStats
    // is held rather than recomputed per render (it walks the activity ledger) and is
    // refreshed when the picked stats change, so the live card updates under the sheet.
    @State private var face: CardFace = .front
    @State private var backStats: CardBackStats = .empty

    private var stats: ProfileStats {
        ProfileStats(workouts: store.workouts, exercises: store.exercises)
    }

    // Claude  Date 07/22/2026 last changed: 08/07/2026 by: Claude
    // The tappable regions of the card, each mapped to a bottom sheet. Name is deliberately
    // absent — renaming lives in Settings › Change Name, not on the card. (08/07: `.avatar`
    // is gone with the face feature; the card's picture is the rank emblem, which is earned
    // rather than edited, so that region is no longer tappable.)
    private enum EditTarget: String, Identifiable {
        case style, badges, backStyle, stats
        var id: String { rawValue }
    }

    // Claude  Date 08/07/2026
    // One section again. This was a Card/Character segmented pair while the character
    // customizer needed a room of its own; with that gone a one-option picker would be
    // pure chrome, so the card tab IS the screen.
    var body: some View {
        cardTab
            .background(theme.current.background.ignoresSafeArea())
            .navigationTitle("Edit Profile Card")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .sheet(item: $target) { target in
                switch target {
                case .style:
                    CardStylePickerSheet(title: "Card Style", selectedID: frontStyleID)
                        .environmentObject(store)
                        .environmentObject(theme)
                        .presentationDetents([.medium, .large])
                case .badges:
                    NavigationStack { FeaturedBadgesView() }
                        .environmentObject(store)
                        .environmentObject(theme)
                // CLAUDE  Date 09/05/2026 — the back reuses the front's picker, with
                // "Match front" as an extra choice (nil = track whatever the front is).
                case .backStyle:
                    CardStylePickerSheet(title: "Back Style",
                                         selectedID: $store.profile.cardBackStyleID,
                                         allowsMatchFront: true)
                        .environmentObject(store)
                        .environmentObject(theme)
                        .presentationDetents([.medium, .large])
                case .stats:
                    NavigationStack { CardStatsPickerView() }
                        .environmentObject(store)
                        .environmentObject(theme)
                }
            }
            .onAppear { refreshBackStats() }
            .onChange(of: store.profile.cardBackStatIDs) { _ in refreshBackStats() }
            .onChange(of: store.profile.cardBackHeroStat) { _ in refreshBackStats() }
    }

    // The original tap-to-edit card, unchanged. The GeometryReader now measures the space
    // left under the tab picker, so the card still sizes itself to (almost) fill it.
    private var cardTab: some View {
        VStack(spacing: 0) {
            facePicker

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 12) {
                        CardFlipView(isFlipped: isShowingBack) {
                            frontCard
                        } back: {
                            backCard
                        }
                        .frame(height: max(380, geo.size.height - 64))

                        // Claude  Date 09/14/2026
                        // Hides the titles under the featured badges, icons only. Front-only
                        // since the back has no badges; syncs to friends via CardSyncService.
                        if face == .front {
                            Toggle("Show badge names", isOn: $store.profile.showsBadgeNamesOnCard)
                                .tint(theme.current.accent)
                                .padding(.horizontal, 4)
                        }

                        Text(face == .front
                             ? "Tap any part of your card to edit it."
                             : "Tap the palette or the stats to edit the back.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 8)
                    }
                    .padding(16)
                }
            }
        }
    }

    // CLAUDE  Date 09/05/2026
    // Front/Back again — the same segmented shape the Card/Character pair had until
    // 08/07. Selecting a segment performs the real flip, hence the animated binding;
    // swiping the card writes back through `isShowingBack` and moves the control.
    private var facePicker: some View {
        Picker("Card face", selection: animatedFace) {
            ForEach(CardFace.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var animatedFace: Binding<CardFace> {
        Binding(get: { face },
                set: { newValue in withAnimation(CardFace.flipAnimation) { face = newValue } })
    }

    // CardFlipView animates its own swipe, so this one stays plain.
    private var isShowingBack: Binding<Bool> {
        Binding(get: { face == .back }, set: { face = $0 ? .back : .front })
    }

    // The front's style lives in a non-optional field, so it is bridged to the optional
    // binding the (now shared) picker takes. A nil can never arrive here — the front has
    // no "Match front" row to produce one.
    private var frontStyleID: Binding<String?> {
        Binding(get: { store.profile.cardStyleID },
                set: { newValue in if let newValue { store.profile.cardStyleID = newValue } })
    }

    private var frontCard: some View {
        ProfileShowcaseCard(
            name: store.profile.resolvedName,
            style: CardStyle.style(for: store.profile.cardStyleID),
            logoAsset: ThemeIcon.logoAsset(for: theme.current),
            unlockedIDs: store.unlockedAchievementIDs,
            pinnedIDs: store.profile.showcasedAchievementIDs,
            memberSince: stats.memberSince,
            rank: store.strategistRank,
            rankProgress: store.strategistProgress,
            ringFillMode: .rankProgress,
            catalog: store.achievementCatalog,
            showsBadgeNames: store.profile.showsBadgeNamesOnCard,
            edit: ProfileCardEditActions(
                background: { target = .style },
                badges: { target = .badges }
            )
        )
    }

    private var backCard: some View {
        ProfileShowcaseCardBack(
            name: store.profile.resolvedName,
            style: store.resolvedBackCardStyle,
            logoAsset: ThemeIcon.logoAsset(for: theme.current),
            stats: backStats,
            memberSince: stats.memberSince,
            edit: ProfileCardBackEditActions(
                background: { target = .backStyle },
                stats: { target = .stats }
            )
        )
    }

    private func refreshBackStats() { backStats = store.cardBackStats }
}

// MARK: - Card style picker

// Claude  Date 07/22/2026 last changed: 09/05/2026 by: CLAUDE
// The card-style chooser, raised by a face's header palette chip. Shows ONLY styles the
// user already owns — buying happens in the Shop, so this stays a clean "equip what you
// have" list with no coin/buy clutter. Applying a style updates the live card underneath
// immediately (store.profile is the shared source of truth).
//
// (09/05) Parameterized so both faces share it: the selection is passed in as a binding
// rather than written straight to profile.cardStyleID. `allowsMatchFront` adds the back's
// extra choice, where nil means "track the front" instead of copying its id.
private struct CardStylePickerSheet: View {
    let title: String
    @Binding var selectedID: String?
    var allowsMatchFront: Bool = false

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
                if allowsMatchFront {
                    Section {
                        matchFrontRow
                    } footer: {
                        Text("The back follows your front card unless you pick its own style.")
                    }
                }

                Section {
                    ForEach(ownedStyles) { style in
                        CardStyleRow(
                            style: style,
                            isSelected: selectedID == style.id,
                            isUnlocked: true,
                            canAfford: false,
                            onSelect: { selectedID = style.id },
                            onBuy: {}
                        )
                    }
                } footer: {
                    Text("Unlock more styles in the Shop.")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // Not a CardStyleRow: there is no style to swatch here, just the "use the front's"
    // choice, which shows the front's current swatch as a hint of what that means.
    private var matchFrontRow: some View {
        HStack(spacing: 12) {
            CardStyleSwatch(style: CardStyle.style(for: store.profile.cardStyleID))
            Text("Match front")
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if selectedID == nil {
                Image(systemName: "checkmark").fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedID = nil }
    }
}

// MARK: - Rows (shared by the sheets above)
// (The avatar sheet + its cell were deleted with the profile-face feature on 08/07/2026.)

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

    private var swatch: some View { CardStyleSwatch(style: style) }

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

// Claude  Date 06/13/2026 last changed: 09/05/2026 by: CLAUDE
// A card style as a 28pt disc: colour fill, gradient, image thumbnail, live animated
// preview, or an outline card in miniature. (09/05: pulled out of CardStyleRow so the
// back picker's "Match front" row can show the front's swatch too.)
struct CardStyleSwatch: View {
    let style: CardStyle

    var body: some View {
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
            // Claude  Date 09/02/2026
            // Outline cards: the swatch is the card in miniature — filled disc
            // with its border colour ringing the edge.
            case .outlined(let fill, let stroke):
                Circle().fill(Color(hex: fill))
                    .overlay(Circle().strokeBorder(Color(hex: stroke), lineWidth: 2))
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .overlay(Circle().stroke(.quaternary))
    }
}

#Preview {
    NavigationStack {
        EditProfileCardView()
            .environmentObject(AppStore())
            .environmentObject(ThemeManager())
    }
}
