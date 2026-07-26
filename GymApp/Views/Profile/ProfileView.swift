import SwiftUI

// Claude  Date 06/12/2026 last changed: 07/12/2026 by: Claude
// The Profile tab: the show-off card fills (almost) the whole screen with its
// original edge margins — like a "fullscreen card" view — and you scroll down
// past it to reach Achievements / Edit Profile Card / Shop / Settings. The card
// shows only the user's featured (pinned) badges — the shelf of every other earned
// badge that used to sit below was removed 07/12/2026.
struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    private var stats: ProfileStats {
        ProfileStats(workouts: store.workouts, exercises: store.exercises)
    }

    var body: some View {
        NavigationStack {
            // Claude  Date 06/13/2026
            // GeometryReader gives us the viewport height so the card can be sized
            // to ~one full screen; the nav rows then sit just below the fold.
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 16) {
                        ProfileShowcaseCard(
                            name: store.profile.resolvedName,
                            style: CardStyle.style(for: store.profile.cardStyleID),
                            unlockedIDs: store.unlockedAchievementIDs,
                            pinnedIDs: store.profile.showcasedAchievementIDs,
                            memberSince: stats.memberSince,
                            rank: store.profile.showsRankOnCard ? store.strategistRank : nil,
                            rankProgress: store.strategistProgress,
                            avatarID: store.profile.avatarID,
                            ringFillMode: .rankProgress,
                            catalog: store.achievementCatalog
                        )
                        .frame(height: max(380, geo.size.height - 32))
                        // Claude  Date 07/14/2026
                        // Spotlight-tour anchor: the one in-content target, reported
                        // via the real preference plumbing (chrome targets use
                        // synthesized fallbacks instead — see TourSupport).
                        .tourTarget(.profileCard)

                        rankBanner

                        navRows
                    }
                    .padding(16)
                }
                .background(theme.current.background.ignoresSafeArea())
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            // Claude  Date 07/13/2026
            // Centered mode-switcher pill in the nav bar (shared by all root tabs).
            // As the principal item it takes the inline title's spot — the tab
            // label already says Profile, so no title text is lost that matters.
            .modeNotchToolbar()
        }
    }

    // Claude  Date 06/15/2026
    // The Strategist rank banner, tappable into the full ladder. Sits between the
    // card and the nav hub.
    private var rankBanner: some View {
        NavigationLink {
            StrategistRankView()
        } label: {
            StrategistRankBanner(
                rank: store.strategistRank,
                progress: store.strategistProgress,
                pointsToNext: StrategistScoring.pointsToNext(forScore: store.strategistScore)
            )
            .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // Claude  Date 06/12/2026 last changed: 06/13/2026 by: Claude
    // The hub revealed by scrolling below the card.
    private var navRows: some View {
        VStack(spacing: 0) {
            // Claude  Date 07/13/2026
            // Icon: custom template asset "wrench" (was slider.horizontal.3).
            profileNavRow("Edit Profile Card", image: "wrench") {
                EditProfileCardView()
            }
            Divider().padding(.leading, 16)
            // Claude  Date 07/14/2026 last changed: 07/23/2026 by: Claude
            // Friends manager (share code, add/accept, friends list, blocks). Sits
            // between Edit Profile Card and Achievements. Disabled (greyed, no push)
            // while in Ghost Mode, since none of the social features work there.
            profileNavRow(
                "Friends",
                systemImage: "person.2",
                disabledMessage: store.profile.dataMode == .ghost ? "Disabled in ghost mode" : nil
            ) {
                FriendsView()
            }
            Divider().padding(.leading, 16)
            // Claude  Date 07/25/2026
            // Browse the shipped workout templates and install one as a preset. Lives
            // here (rather than only on the Presets tab) so it's findable as a "things
            // I can add to my account" destination, alongside the Shop.
            profileNavRow("Premade Workouts", image: "folder-plus") {
                PremadeWorkoutsView()
            }
            Divider().padding(.leading, 16)
            // Claude  Date 07/24/2026
            // The Achievement Book (was the flat AchievementsView list). Carries the
            // same unopened count as the tab badge, so the reason you came to this
            // screen is still visible once the tab bar is behind you.
            profileNavRow("Achievements", systemImage: "rosette",
                          badgeCount: store.unopenedAchievementCount) {
                AchievementBookView()
            }
            Divider().padding(.leading, 16)
            profileNavRow("Shop", systemImage: "bag") {
                ShopView()
            }
            Divider().padding(.leading, 16)
            profileNavRow("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    // Claude  Date 06/12/2026 last changed: 07/13/2026 by: Claude
    // A tappable row that pushes a destination, styled as a settings row. The
    // SF-Symbol and custom-asset variants both funnel into the shared core below.
    private func profileNavRow<Destination: View>(
        _ title: String,
        systemImage: String,
        disabledMessage: String? = nil,
        badgeCount: Int = 0,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        profileNavRow(title, disabledMessage: disabledMessage, badgeCount: badgeCount,
                      icon: { Image(systemName: systemImage) }, destination: destination)
    }

    // Claude  Date 07/13/2026
    // Variant taking a custom asset-catalog icon (template image) instead of an SF
    // Symbol — used by the Edit Profile Card row (wrench). Sized to match the
    // symbol rows' icon footprint.
    private func profileNavRow<Destination: View>(
        _ title: String,
        image: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        profileNavRow(
            title,
            icon: { Image(image).resizable().scaledToFit().frame(width: 20, height: 20) },
            destination: destination
        )
    }

    // Claude  Date 07/13/2026 last changed: 07/24/2026 by: Claude
    // Shared row body — accepts any icon view so both the SF-Symbol and custom-asset
    // variants above can reuse it. When `disabledMessage` is set the row is inert:
    // no NavigationLink push, the title/icon are greyed (.plain buttons don't auto-
    // grey, so opacity is applied manually), and the message replaces the chevron.
    // `badgeCount` (07/24/2026) draws a red count before the chevron — zero draws
    // nothing, so every other row is untouched.
    @ViewBuilder
    private func profileNavRow<Icon: View, Destination: View>(
        _ title: String,
        disabledMessage: String? = nil,
        badgeCount: Int = 0,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        if let disabledMessage {
            HStack {
                Label { Text(title) } icon: { icon() }
                    .opacity(0.5)
                Spacer()
                Text(disabledMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .foregroundStyle(.primary)
        } else {
            NavigationLink(destination: destination()) {
                HStack {
                    Label { Text(title) } icon: { icon() }
                    Spacer()
                    if badgeCount > 0 {
                        Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Color.red, in: Capsule())
                            .accessibilityLabel("\(badgeCount) new")
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Showcase card

// Claude  Date 07/22/2026
// The set of "edit this element" callbacks handed to ProfileShowcaseCard to turn it into
// an interactive editor (see EditProfileCardView). Each closure just signals which element
// was tapped; the owner raises the matching sheet. Defaulted so a caller can wire up only
// what it needs.
struct ProfileCardEditActions {
    var background: () -> Void = {}
    var avatar: () -> Void = {}   // the avatar art + rank ring cluster
    var rank: () -> Void = {}     // routed to the same editor as the avatar
    var badges: () -> Void = {}
}

// Claude  Date 06/12/2026 last changed: 07/12/2026 by: Claude
// The shareable card: a CardStyle background (color or image) drawn by
// CardBackgroundView and a row of featured (pinned) achievement badges. Rounded +
// shadowed so it reads as a card with the screen showing at its edges. (The shelf
// of every other earned badge that used to sit below the featured row was removed.)
struct ProfileShowcaseCard: View {
    let name: String
    let style: CardStyle
    let unlockedIDs: Set<String>
    let pinnedIDs: [String]
    let memberSince: Date?
    // Claude  Date 06/15/2026
    // The Strategist rank equipped onto the card (nil = not equipped); progress
    // fills its ring toward the next rank.
    var rank: StrategistRank? = nil
    var rankProgress: Double = 1
    // Claude  Date 06/30/2026 last changed: 07/09/2026 by: Claude
    // The chosen avatar shown at the top of the card. nil means "no avatar to show" —
    // which is the friend-card case, since SharedCard syncs `rank` but not `avatarID`.
    // A nil avatar renders an initials core inside the rank ring instead of art.
    var avatarID: String? = nil
    // Claude  Date 07/09/2026
    // How the rank ring reads. Your OWN card uses .rankProgress (the ring fills toward your
    // next rank — a personal "how close am I" meter). Friends viewing your card keep the
    // default .rankSegments (your rank crest), so your progress-to-next stays private.
    var ringFillMode: RankRingFill = .rankSegments
    // Claude  Date 07/14/2026
    // Which achievement catalog resolves the pinned badge ids. Your OWN card passes the
    // gender-calibrated store.achievementCatalog; friend cards keep the baseline default —
    // a friend's identity is never shared (SharedCard privacy contract), and ids/tiers are
    // identical across variants so the badges themselves render the same.
    var catalog: [Achievement] = Achievement.all

    // Claude  Date 07/22/2026
    // Opt-in edit affordances. nil (the default, used by the Profile tab, Friends and
    // FriendCard) renders a plain, read-only card exactly as before. When set — only by
    // EditProfileCardView — each editable element becomes tappable and grows a small pencil
    // chip, turning the live card into its own editor. The closures just report which
    // element was tapped; the owning view decides what sheet to raise.
    var edit: ProfileCardEditActions? = nil

    // Claude  Date 06/13/2026 last changed: 07/12/2026 by: Claude
    // Just the user's pinned badges (in their chosen order, still-unlocked, capped at
    // maxFeatured). The empty slots that AchievementShowcase.featured pads with are
    // dropped here, so the row shows only real badges — no "Locked" placeholders.
    private var featuredBadges: [Achievement] {
        AchievementShowcase.featured(unlockedIDs: unlockedIDs, pinnedIDs: pinnedIDs,
                                     catalog: catalog)
            .compactMap { $0 }
    }

    // Claude  Date 07/01/2026 last changed: 07/12/2026 by: Claude
    // Whether any badge is pinned. When none are, the card omits the row entirely
    // (a fully blank card).
    private var hasFeatured: Bool { !featuredBadges.isEmpty }

    // Claude  Date 06/12/2026 last changed: 06/16/2026 by: Claude
    // A representative color for the drop shadow: the card color, the animated
    // card's accent, or black for image cards.
    private var shadowColor: Color {
        switch style.background {
        case .color(let hex):       return Color(hex: hex)
        case .gradient(let from, _): return Color(hex: from)
        case .animated(let kind):   return kind.accent
        case .image:                return .black
        }
    }

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CardBackgroundView(background: style.background))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.18), lineWidth: 1))
            .shadow(color: shadowColor.opacity(0.4), radius: 12, y: 6)
    }

    // Claude  Date 07/09/2026
    // The avatar at the top of the card. When a rank is equipped it's framed by the
    // RankRing (rank earns the frame, coins buy what's inside); with no rank it's the
    // plain avatar as before. The ring's core is the chosen avatar art on your own card,
    // or initials on a friend's card (their avatarID doesn't sync — see avatarID above).
    private let ringSize: CGFloat = 120

    @ViewBuilder private var cardAvatar: some View {
        if let rank {
            RankRing(rank: rank, progress: rankProgress, size: ringSize,
                     fillMode: ringFillMode) {
                avatarCore(diameter: RingGeometry.coreDiameter(for: ringSize))
            }
        } else {
            avatarCore(diameter: 92)
        }
    }

    @ViewBuilder private func avatarCore(diameter: CGFloat) -> some View {
        if let avatarID {
            AvatarView(avatar: Avatar.avatar(for: avatarID), size: diameter)
        } else {
            ZStack {
                Circle().fill(Color.white.opacity(0.15))
                RankRingInitials(name: name, size: diameter)
            }
            .frame(width: diameter, height: diameter)
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            header

            editable(edit?.avatar, chip: .bottomTrailing) { cardAvatar }

            // Claude  Date 07/22/2026
            // The name is intentionally NOT editable from the card — renaming carries
            // backend/identity weight, so it lives behind Settings › Change Name instead.
            Text(name)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            // Claude  Date 06/15/2026 last changed: 07/09/2026 by: Claude
            // The equipped rank's title (when turned on in Edit Profile Card). The
            // emblem that used to sit here is gone — the rank ring around the avatar now
            // carries the rank visually, so this is just the label. (StrategistEmblem
            // still lives on the rank banner and the ladder.)
            if let rank {
                editable(edit?.rank, chip: .trailing) {
                    Text(rank.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }

            // Claude  Date 07/22/2026
            // Edit mode gets the interactive badge editor (tappable badges + an add slot
            // or a "change or delete" prompt). Read-only cards keep the original behaviour:
            // the row is shown only when something is pinned, and omitted otherwise.
            if let edit {
                badgeEditor(edit)
            } else if hasFeatured {
                featuredRow
            }

            Spacer(minLength: 12)

            if let memberSince {
                Text("Member since \(memberSince.formatted(.dateTime.month().year()))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    // Claude  Date 07/22/2026
    // Wraps an editable element: with an action it becomes a plain button carrying a small
    // pencil chip (so it reads as tappable); without one it's just the content, unchanged.
    @ViewBuilder
    private func editable<Content: View>(_ action: (() -> Void)?,
                                         chip alignment: Alignment,
                                         @ViewBuilder content: () -> Content) -> some View {
        if let action {
            Button(action: action) { content() }
                .buttonStyle(.plain)
                .overlay(alignment: alignment) { editChip.padding(-4) }
        } else {
            content()
        }
    }

    private var editChip: some View {
        Image(systemName: "pencil")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(5)
            .background(.black.opacity(0.35), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1))
    }

    // Claude  Date 07/22/2026
    // The badges section in edit mode. Each featured badge stays tappable (opens the
    // picker to reorder/remove). While there's still room, a badge-sized "selection-plus"
    // slot sits to the RIGHT of the badges, as if it were the next badge, to add more.
    // Once the row is full (maxFeatured), that slot is dropped — there's nowhere to put a
    // new badge — and a "minus-square + Change or delete badges" prompt sits underneath
    // instead, routing to the same picker.
    @ViewBuilder
    private func badgeEditor(_ edit: ProfileCardEditActions) -> some View {
        let isFull = featuredBadges.count >= AchievementShowcase.maxFeatured
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(featuredBadges) { achievement in
                    Button(action: edit.badges) { badgeCell(achievement) }
                        .buttonStyle(.plain)
                }
                if !isFull {
                    Button(action: edit.badges) { addBadgeSlot }
                        .buttonStyle(.plain)
                }
            }

            if isFull {
                Button(action: edit.badges) {
                    VStack(spacing: 4) {
                        Image("minus-square")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                        Text("Change or delete badges")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // A badge-sized add slot: the selection-plus glyph where a badge would be, so it reads
    // as the next empty badge position.
    private var addBadgeSlot: some View {
        VStack(spacing: 6) {
            Image("selection-plus")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 58, height: 58)
                .foregroundStyle(.white.opacity(0.9))
            Text("Add")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("AppLogo")
                .resizable().scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            Text("AGIL")
                .font(.caption.bold()).tracking(3)
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            // Claude  Date 07/22/2026
            // In edit mode the background has no single element to tap, so the header
            // carries a palette chip for it (a whole-card tap would fight the inner
            // elements' gestures). Hidden entirely on read-only cards.
            if let edit {
                Button(action: edit.background) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.white.opacity(0.22), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change card style")
            }
        }
    }

    // Claude  Date 06/13/2026 last changed: 07/12/2026 by: Claude
    // The featured badges row across the top (transparent), badge over title. Shows
    // only the user's pinned badges — empty slots no longer render as "Locked"
    // placeholders. Each badge takes an equal share of the width so 1–4 badges stay
    // evenly spread.
    private var featuredRow: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(featuredBadges) { badgeCell($0) }
        }
    }

    // Claude  Date 07/22/2026 — one badge + its title, shared by featuredRow and the editor.
    private func badgeCell(_ achievement: Achievement) -> some View {
        VStack(spacing: 6) {
            BadgeView(icon: achievement.icon, tier: achievement.tier, unlocked: true, size: 58, glimmer: true, ringed: false)
            Text(achievement.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

}

#Preview {
    let store = AppStore()
    store.addWorkout(Workout(exercises: [
        LoggedExercise(exerciseId: store.exercises[0].id,
                       sets: [ExerciseSet(reps: 8, weight: 185), ExerciseSet(reps: 5, weight: 225)])
    ]))
    return ProfileView()
        .environmentObject(store)
        .environmentObject(ThemeManager())
}
