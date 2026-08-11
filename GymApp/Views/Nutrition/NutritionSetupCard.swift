import SwiftUI

// Claude  Date 07/25/2026
// The nutrition world's first-run checklist, sitting at the top of the Journal
// between the date stepper and Summary.
//
// Why it exists: a new user's diary silently fills toward 2000 kcal / 3000 ml —
// numbers they never chose — and the only way to change either is an unlabelled
// `target` glyph in the toolbar. Focus goals hide behind an equally unlabelled
// `scope` glyph, and the Focus card doesn't render at all until a goal exists.
// Nothing on the screen says any of it is configurable. This card is the signpost.
//
// Two required items (calorie + water goals) gate the First Plan badge; the focus
// item is a bonus that never blocks it — it's here to advertise a feature, not to
// hold a reward hostage. Completion state lives in profile.nutritionSetup.
//
// NOTE: this must never mention the badge. First Plan is a secret achievement — the
// payoff is the red count appearing over the Profile tab and a sealed slot on the
// Achievement Book's Secrets page. Naming it here would defeat the whole feature.
struct NutritionSetupCard: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    /// Opens the focus-goals sheet — its presentation state lives in the parent.
    let onOpenFocus: () -> Void

    private var setup: NutritionSetup { store.profile.nutritionSetup }
    private var accent: Color { theme.current.accent }
    // Whether the water goal is part of this checklist at all (Settings → Water).
    @AppStorage(WaterTracking.storageKey) private var trackWater = WaterTracking.defaultValue

    var body: some View {
        Section {
            if setup.isComplete {
                completedRow
            } else {
                checklistRows
            }
        } header: {
            header
        }
    }

    private var header: some View {
        HStack {
            Text("Get started")
            Spacer()
            if !setup.isComplete {
                Text("\(setup.completedRequiredCount) of \(NutritionSetup.requiredCount)")
                    .monospacedDigit()
            }
            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    store.acknowledgeNutritionSetup()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss setup checklist")
        }
    }

    @ViewBuilder
    private var checklistRows: some View {
        // Both goals live on the same screen, so both rows push it. That's fine —
        // the row you tapped tells you which field to look for.
        NavigationLink {
            NutritionGoalsView()
        } label: {
            checklistRow(
                title: "Set your calorie goal",
                detail: "Your daily target, so the Summary above means something.",
                done: setup.calorieGoalSet
            )
        }

        // Only when the user actually tracks water — see NutritionSetup.isComplete.
        if trackWater {
            NavigationLink {
                NutritionGoalsView()
            } label: {
                checklistRow(
                    title: "Set your water goal",
                    detail: "How much you're aiming to drink each day.",
                    done: setup.waterGoalSet
                )
            }
        }

        bonusRow
    }

    // Claude  Date 07/25/2026
    // The bonus item. Visually distinct on purpose — a tinted chip instead of a
    // checkbox — so it never reads as something standing between the user and a
    // finished list. Stays tappable after it's been opened.
    private var bonusRow: some View {
        Button(action: onOpenFocus) {
            HStack(spacing: 12) {
                iconChip(setup.focusGoalsOpened ? "checkmark" : "scope", tint: accent)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Pick a nutrient focus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Optional")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(accent.opacity(0.15), in: Capsule())
                    }
                    Text("Track a focus goal alongside your macros.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .supportingTextFont()
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func checklistRow(title: String, detail: String, done: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(done ? AnyShapeStyle(accent) : AnyShapeStyle(Color.secondary.opacity(0.5)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(done ? .secondary : .primary)
                    .strikethrough(done, color: .secondary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .supportingTextFont()
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    // Claude  Date 07/25/2026
    // The payoff, shown in place for a few seconds before the card retires itself.
    // Says nothing about the badge on purpose (see the note at the top of the file).
    //
    // The auto-hide timer hangs off THIS row rather than off the Section or an
    // .onAppear. Section is a container the List interprets, so lifecycle modifiers
    // on it aren't reliably run; and onAppear re-fires when the user pops back from
    // the pushed Goals screen — which is exactly the moment they finish — so an
    // onAppear latch would retire the card before they ever saw this. This row only
    // exists once isComplete is true, so its .task fires precisely on completion.
    private var completedRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("You're all set.")
                    .font(.subheadline.weight(.bold))
                Text("Change these any time from the target button up top.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .supportingTextFont()
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .transition(.opacity)
        .task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                store.acknowledgeNutritionSetup()
            }
        }
    }
}

#Preview {
    NavigationStack {
        List {
            NutritionSetupCard(onOpenFocus: {})
        }
    }
    .environmentObject(AppStore())
    .environmentObject(ThemeManager())
}
