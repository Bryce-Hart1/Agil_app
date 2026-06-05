import SwiftUI

/// The user's profile: an identity card, key lifting stats, and a link to
/// Settings. Designed to be clean enough to mirror as an online profile later.
struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    private var stats: ProfileStats {
        ProfileStats(workouts: store.workouts, exercises: store.exercises)
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ProfileCard(memberSince: stats.memberSince,
                                accent: theme.current.accent,
                                surface: theme.current.surface)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                Section("Stats") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        StatCard(title: "Workouts", value: "\(stats.totalWorkouts)",
                                 systemImage: "calendar", surface: theme.current.surface, accent: theme.current.accent)
                        StatCard(title: "Total volume", value: weight(stats.totalVolume),
                                 systemImage: "scalemass", surface: theme.current.surface, accent: theme.current.accent)
                        StatCard(title: "Total sets", value: "\(stats.totalSets)",
                                 systemImage: "square.stack.3d.up", surface: theme.current.surface, accent: theme.current.accent)
                        StatCard(title: "Heaviest lift", value: weight(stats.heaviestLift),
                                 systemImage: "trophy", surface: theme.current.surface, accent: theme.current.accent)
                        StatCard(title: "Week streak", value: "\(stats.weekStreak)",
                                 systemImage: "flame", surface: theme.current.surface, accent: theme.current.accent)
                        StatCard(title: "Top group", value: stats.topMuscleGroup ?? "—",
                                 systemImage: "figure.strengthtraining.traditional", surface: theme.current.surface, accent: theme.current.accent)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("Profile")
            .themed(theme.current)
        }
    }

    /// Compact weight formatting, e.g. 52,340 → "52k lb", 8,250 → "8.3k lb".
    private func weight(_ value: Double) -> String {
        if value >= 10_000 { return String(format: "%.0fk lb", value / 1000) }
        if value >= 1_000 { return String(format: "%.1fk lb", value / 1000) }
        return "\(Int(value.rounded())) lb"
    }
}

/// The identity header card: avatar, name (placeholder for now), and a subtitle.
private struct ProfileCard: View {
    let memberSince: Date?
    let accent: Color
    let surface: Color

    private var subtitle: String {
        guard let memberSince else { return "New lifter" }
        return "Lifting since \(memberSince.formatted(.dateTime.month().year()))"
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your Name")
                    .font(.title2).fontWeight(.bold)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    let store = AppStore()
    store.addWorkout(Workout(exercises: [
        LoggedExercise(exerciseId: store.exercises[0].id,
                       sets: [ExerciseSet(reps: 8, weight: 185), ExerciseSet(reps: 5, weight: 205)])
    ]))
    return ProfileView()
        .environmentObject(store)
        .environmentObject(ThemeManager())
}
