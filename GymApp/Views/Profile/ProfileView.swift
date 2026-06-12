import SwiftUI

// Claude  Date 06/12/2026
// The Profile tab: a full-page, show-off profile card on top, with "Edit Profile
// Card" and "Settings" beneath it. The card is the thing the user will eventually
// flaunt; its color/name/traits become customizable from Edit Profile Card.
struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    private var stats: ProfileStats {
        ProfileStats(workouts: store.workouts, exercises: store.exercises)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                ProfileShowcaseCard(
                    name: store.profile.resolvedName,
                    cardColor: Color(hex: store.profile.cardColorHex),
                    traits: ProfileTrait.showcase(from: stats),
                    memberSince: stats.memberSince
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 0) {
                    profileNavRow("Edit Profile Card", systemImage: "slider.horizontal.3") {
                        EditProfileCardView()
                    }
                    Divider().padding(.leading, 16)
                    profileNavRow("Settings", systemImage: "gearshape") {
                        SettingsView()
                    }
                }
                .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.current.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // Claude  Date 06/12/2026
    // A tappable row that pushes a destination, styled as a settings row
    // (primary text + chevron) rather than a tinted link.
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

// Claude  Date 06/12/2026
// One displayed stat on the profile card. Eventually the user picks which four.
struct ProfileTrait: Identifiable {
    let id = UUID()
    let label: String
    let value: String

    // The default four traits shown on the card for now.
    static func showcase(from stats: ProfileStats) -> [ProfileTrait] {
        [
            ProfileTrait(label: "Workouts", value: "\(stats.totalWorkouts)"),
            ProfileTrait(label: "Volume", value: compactWeight(stats.totalVolume)),
            ProfileTrait(label: "Streak", value: "\(stats.weekStreak) wk"),
            ProfileTrait(label: "Heaviest", value: compactWeight(stats.heaviestLift)),
        ]
    }

    private static func compactWeight(_ value: Double) -> String {
        if value >= 10_000 { return String(format: "%.0fk lb", value / 1000) }
        if value >= 1_000 { return String(format: "%.1fk lb", value / 1000) }
        return "\(Int(value.rounded())) lb"
    }
}

// Claude  Date 06/12/2026
// The shareable card: colored background, name, avatar, and a 2×2 grid of traits.
struct ProfileShowcaseCard: View {
    let name: String
    let cardColor: Color
    let traits: [ProfileTrait]
    let memberSince: Date?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("AGIL")
                    .font(.caption.bold())
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Image("AppLogo")
                    .resizable().scaledToFit()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }

            Spacer(minLength: 0)

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

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(traits) { trait in
                    VStack(spacing: 4) {
                        Text(trait.value)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(trait.label)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                }
            }

            Spacer(minLength: 0)

            if let memberSince {
                Text("Member since \(memberSince.formatted(.dateTime.month().year()))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [cardColor, cardColor.opacity(0.78)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: cardColor.opacity(0.4), radius: 12, y: 6)
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
