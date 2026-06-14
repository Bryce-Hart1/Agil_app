import SwiftUI

// Claude  Date 06/12/2026 last changed: 06/13/2026 by: Claude
// The Profile tab: the show-off card fills (almost) the whole screen with its
// original edge margins — like a "fullscreen card" view — and you scroll down
// past it to reach Edit Profile Card / Shop / Settings. The card keeps its new
// design (top achievements row, open lower portion).
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
                            traits: ProfileTrait.showcase(from: stats),
                            memberSince: stats.memberSince
                        )
                        .frame(height: max(380, geo.size.height - 32))

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

    // Claude  Date 06/12/2026 last changed: 06/13/2026 by: Claude
    // The settings/shop hub revealed by scrolling below the card.
    private var navRows: some View {
        VStack(spacing: 0) {
            profileNavRow("Edit Profile Card", systemImage: "slider.horizontal.3") {
                EditProfileCardView()
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
// One achievement shown in the card's stats row (icon + value + label).
struct ProfileTrait: Identifiable {
    let id = UUID()
    let icon: String
    let value: String
    let label: String

    // Claude  Date 06/13/2026
    // The four headline achievements. Placeholder picks from current stats —
    // refine into real achievement milestones (e.g. "400 lb squat") later.
    static func showcase(from stats: ProfileStats) -> [ProfileTrait] {
        [
            ProfileTrait(icon: "trophy.fill", value: compactWeight(stats.heaviestLift), label: "Heaviest"),
            ProfileTrait(icon: "calendar", value: "\(stats.daysLogged)", label: "Days Logged"),
            ProfileTrait(icon: "scalemass.fill", value: compactWeight(stats.totalVolume), label: "Total Lifted"),
            ProfileTrait(icon: "flame.fill", value: "\(stats.weekStreak) wk", label: "Streak"),
        ]
    }

    private static func compactWeight(_ value: Double) -> String {
        if value >= 10_000 { return String(format: "%.0fk lb", value / 1000) }
        if value >= 1_000 { return String(format: "%.1fk lb", value / 1000) }
        return "\(Int(value.rounded())) lb"
    }
}

// Claude  Date 06/12/2026 last changed: 06/13/2026 by: Claude
// The shareable card: a CardStyle background (color or image) drawn by
// CardBackgroundView, with a top achievements row and an open lower portion.
// Rounded + shadowed so it reads as a card with the screen showing at its edges.
struct ProfileShowcaseCard: View {
    let name: String
    let style: CardStyle
    let traits: [ProfileTrait]
    let memberSince: Date?

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

            achievementsRow

            // The open lower portion — reserved for future content.
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
    // One transparent row of achievements across the top of the card (no tile
    // backgrounds), icon over value over label.
    private var achievementsRow: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(traits) { trait in
                VStack(spacing: 5) {
                    Image(systemName: trait.icon)
                        .font(.title3)
                        .foregroundStyle(.white)
                    Text(trait.value)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(trait.label)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
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
