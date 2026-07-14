import SwiftUI

// Claude  Date 06/13/2026 last changed: 06/13/2026 by: Claude
// Lists all achievements grouped by category, with colored tier badges. Unlocked
// ones are lit and tappable to feature on the profile card (max 4); locked ones
// show the requirement, tier, and the coins they'd grant. The Big-3 section has
// an info button explaining what the "big three" lifts are.
struct AchievementsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @State private var showBig3Info = false

    // Claude  Date 07/14/2026
    // Read the gender-calibrated catalog so thresholds/titles reflect the user's
    // identity choice (same ids/tiers in every variant, so counts are unaffected).
    private var catalog: [Achievement] { store.achievementCatalog }

    private var unlockedCount: Int {
        catalog.filter { store.unlockedAchievementIDs.contains($0.id) }.count
    }

    // Powerlifting's three competition lifts; worded to match how we track them.
    private let big3Explanation = """
    In powerlifting the "big three" are the back squat, bench press, and conventional deadlift (traditional stance, not sumo) — the three competition lifts whose one-rep maxes add up to your total.

    Each lift now has its own badges, unlocked from the heaviest weight you've logged on that lift.
    """

    var body: some View {
        List {
            Section {
                HStack {
                    Label("Unlocked", systemImage: "rosette")
                    Spacer()
                    Text("\(unlockedCount) / \(catalog.count)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } footer: {
                Text("Feature up to 4 of these on your profile card from Profile → Edit Profile Card → Featured Badges. A pin marks the ones you've featured.")
            }

            ForEach(Achievement.Category.allCases, id: \.self) { category in
                Section {
                    ForEach(catalog.filter { $0.category == category }) { achievement in
                        AchievementRow(
                            achievement: achievement,
                            unlocked: store.unlockedAchievementIDs.contains(achievement.id),
                            showcased: store.profile.showcasedAchievementIDs.contains(achievement.id)
                        )
                    }
                } header: {
                    sectionHeader(category)
                }
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .alert("The Big Three", isPresented: $showBig3Info) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text(big3Explanation)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ category: Achievement.Category) -> some View {
        HStack(spacing: 6) {
            Text(category.title)
            if category.isBig3Lift {
                Button { showBig3Info = true } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("What is a big-3 lift?")
            }
        }
    }
}

// Claude  Date 06/13/2026 last changed: 06/13/2026 by: Claude
// One achievement row: badge + title/requirement + reward/status, with a pin
// marker when it's featured on the card.
private struct AchievementRow: View {
    let achievement: Achievement
    let unlocked: Bool
    let showcased: Bool

    var body: some View {
        HStack(spacing: 14) {
            BadgeView(icon: achievement.icon, tier: achievement.tier, unlocked: unlocked, size: 46)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(achievement.title)
                        .font(.headline)
                        .foregroundStyle(unlocked ? .primary : .secondary)
                    if showcased {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(achievement.tier.color)
                    }
                }
                Text(achievement.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Label("\(achievement.reward)", systemImage: "circle.hexagongrid.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(unlocked ? achievement.tier.color : .secondary)
                Text(unlocked ? "Earned" : achievement.tier.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack { AchievementsView() }
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
