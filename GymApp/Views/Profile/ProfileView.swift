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
            // Claude  Date 07/14/2026
            // Friends manager (share code, add/accept, friends list, blocks). Sits
            // between Edit Profile Card and Achievements.
            profileNavRow("Friends", systemImage: "person.2") {
                FriendsView()
            }
            Divider().padding(.leading, 16)
            profileNavRow("Achievements", systemImage: "rosette") {
                AchievementsView()
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
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        profileNavRow(title, icon: { Image(systemName: systemImage) }, destination: destination)
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

    // Claude  Date 07/13/2026
    // Shared row body — accepts any icon view so both the SF-Symbol and custom-asset
    // variants above can reuse it.
    private func profileNavRow<Icon: View, Destination: View>(
        _ title: String,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack {
                Label { Text(title) } icon: { icon() }
                Spacer()
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

// MARK: - Showcase card

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

            cardAvatar

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
                Text(rank.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            if hasFeatured { featuredRow }

            Spacer(minLength: 12)

            if let memberSince {
                Text("Member since \(memberSince.formatted(.dateTime.month().year()))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
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
        }
    }

    // Claude  Date 06/13/2026 last changed: 07/12/2026 by: Claude
    // The featured badges row across the top (transparent), badge over title. Shows
    // only the user's pinned badges — empty slots no longer render as "Locked"
    // placeholders. Each badge takes an equal share of the width so 1–4 badges stay
    // evenly spread.
    private var featuredRow: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(featuredBadges) { achievement in
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
