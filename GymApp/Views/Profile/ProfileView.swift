import SwiftUI

// Claude  Date 06/12/2026 last changed: 06/13/2026 by: Claude
// The Profile tab: the show-off card fills (almost) the whole screen with its
// original edge margins — like a "fullscreen card" view — and you scroll down
// past it to reach Achievements / Edit Profile Card / Shop / Settings. The card's
// top row shows the user's featured achievement badges; the lower area is a shelf
// of the rest of their earned badges.
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
                            rankProgress: store.strategistProgress
                        )
                        .frame(height: max(380, geo.size.height - 32))

                        rankBanner

                        navRows
                    }
                    .padding(16)
                }
                .background(theme.current.background.ignoresSafeArea())
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
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
            profileNavRow("Edit Profile Card", systemImage: "slider.horizontal.3") {
                EditProfileCardView()
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

    // Claude  Date 06/12/2026
    // A tappable row that pushes a destination, styled as a settings row.
    private func profileNavRow<Destination: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack {
                Label(title, systemImage: systemImage)
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

// Claude  Date 06/12/2026 last changed: 06/13/2026 by: Claude
// The shareable card: a CardStyle background (color or image) drawn by
// CardBackgroundView, a top row of featured achievement badges, and a shelf of
// the rest of the earned badges below. Rounded + shadowed so it reads as a card
// with the screen showing at its edges.
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

    // The 4 featured slots (nil = locked placeholder).
    private var featured: [Achievement?] {
        AchievementShowcase.featured(unlockedIDs: unlockedIDs, pinnedIDs: pinnedIDs)
    }

    // The remaining unlocked badges (everything not already in the featured row).
    private var shelf: [Achievement] {
        let featuredIDs = Set(featured.compactMap { $0?.id })
        return AchievementShowcase.unlockedSorted(unlockedIDs).filter { !featuredIDs.contains($0.id) }
    }

    // A representative color for the drop shadow (card color, or black for image cards).
    private var shadowColor: Color {
        if case .color(let hex) = style.background { return Color(hex: hex) }
        return .black
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

    private var content: some View {
        VStack(spacing: 16) {
            header

            Image(systemName: "person.crop.circle.fill")
                .resizable().scaledToFit()
                .frame(width: 92, height: 92)
                .foregroundStyle(.white)
                .shadow(radius: 6, y: 3)

            Text(name)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            // Claude  Date 06/15/2026
            // The equipped rank emblem (when the user has turned it on in Edit
            // Profile Card), sitting just under the name.
            if let rank {
                HStack(spacing: 8) {
                    StrategistEmblem(rank: rank, progress: rankProgress, size: 44)
                    Text(rank.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }

            featuredRow

            Spacer(minLength: 12)

            badgeShelf

            Spacer(minLength: 0)

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

    // Claude  Date 06/13/2026
    // The featured badges row across the top (transparent), badge over title;
    // empty slots render as locked placeholders to bait progress.
    private var featuredRow: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(Array(featured.enumerated()), id: \.offset) { _, slot in
                VStack(spacing: 6) {
                    if let achievement = slot {
                        BadgeView(icon: achievement.icon, tier: achievement.tier, unlocked: true, size: 58, glimmer: true, ringed: false)
                        Text(achievement.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    } else {
                        LockedBadge(size: 50)
                        Text("Locked")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // Claude  Date 06/13/2026
    // The lower "shelf" of the remaining earned badges (hidden when there are none).
    @ViewBuilder private var badgeShelf: some View {
        if !shelf.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Badges")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 10)], spacing: 10) {
                    ForEach(shelf) { achievement in
                        BadgeView(icon: achievement.icon, tier: achievement.tier, unlocked: true, size: 40, glimmer: true, ringed: false)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
