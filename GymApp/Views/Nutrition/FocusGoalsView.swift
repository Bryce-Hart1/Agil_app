import SwiftUI

// Claude  Date 07/12/2026 last changed: 10/01/2026 by: CLAUDE
// The Focus sheet, opened from the diary's top-left Focus button: the home for focus goals
// (editable target + direction, one per nutrient, removed with a confirmed trash button) and
// a row that pushes the existing SupplementsView. Edits write straight through to the store.
struct FocusGoalsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    // CLAUDE  Date 10/01/2026
    // The goal whose trash button was tapped, held until the user confirms or cancels.
    @State private var goalToRemove: NutrientFocusGoal?

    private var untracked: [NutrientFocusGoal.Nutrient] {
        NutrientFocusGoal.Nutrient.allCases.filter { nutrient in
            !store.focusGoals.contains { $0.nutrient == nutrient }
        }
    }

    // CLAUDE  Date 10/01/2026
    // One line of status for the supplements row, so the Focus tab shows where the stack
    // stands today without being a second checklist (ticking stays on the journal card).
    private var supplementSummary: String {
        let total = store.supplements.count
        if total == 0 { return "Build your stack and set reminders" }
        let due = store.dueSupplements(on: Date())
        let taken = store.takenSupplementIDs(on: Date())
        let done = due.filter { taken.contains($0.id) }.count
        if due.isEmpty { return "\(total) in your stack · none due today" }
        return done == due.count ? "All taken today" : "\(done) of \(due.count) taken today"
    }

    var body: some View {
        NavigationStack {
            Form {
                supplementsSection

                if store.focusGoals.isEmpty {
                    Section("Focus goals") {
                        Text("Pick a nutrient to focus on. Its progress will show under the diary's Summary each day.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                if !store.focusGoals.isEmpty {
                    Section("Tracking") {
                        ForEach($store.focusGoals) { $goal in
                            goalRow($goal)
                        }
                    }
                }

                if !untracked.isEmpty {
                    Section("Add a focus") {
                        ForEach(untracked) { nutrient in
                            Button {
                                withAnimation { store.addFocusGoal(for: nutrient) }
                            } label: {
                                HStack(spacing: 10) {
                                    iconChip(nutrient.systemImage, tint: nutrient.tint)
                                    Text(nutrient.label).foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(theme.current.accent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Remove \(goalToRemove?.nutrient.label ?? "this") goal?",
                isPresented: Binding(get: { goalToRemove != nil },
                                     set: { if !$0 { goalToRemove = nil } }),
                titleVisibility: .visible,
                presenting: goalToRemove
            ) { goal in
                Button("Remove \(goal.nutrient.label) goal", role: .destructive) {
                    remove(goal)
                }
            } message: { _ in
                Text("It stops showing on your Journal. If you add it back, the target starts over at the default.")
            }
        }
    }

    // CLAUDE  Date 10/01/2026
    // The only way a goal is deleted, reached after the confirmation. Looks the goal up by id
    // rather than trusting a row index, which can shift while the dialog is up.
    private func remove(_ goal: NutrientFocusGoal) {
        guard let index = store.focusGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        withAnimation { store.deleteFocusGoals(at: IndexSet(integer: index)) }
    }

    // CLAUDE  Date 10/01/2026
    // Pushes the same SupplementsView the journal card opens (it has no stack of its own, so
    // it rides this sheet's NavigationStack). Always shown — the Focus tab is where to look.
    private var supplementsSection: some View {
        Section("Supplements") {
            NavigationLink {
                SupplementsView()
            } label: {
                HStack(spacing: 10) {
                    iconChip("pills.fill", tint: theme.current.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage supplements")
                        Text(supplementSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .supportingTextFont()
                    }
                }
            }
        }
    }

    // Claude  Date 07/12/2026 last changed: 10/01/2026 by: CLAUDE
    // One tracked goal: chip + name, trailing editable target with unit, a quiet trash button
    // at the far right (asks first, see goalToRemove), and a segmented at-least / stay-under
    // picker beneath. The button is borderless so it doesn't make the whole Form row tappable.
    private func goalRow(_ goal: Binding<NutrientFocusGoal>) -> some View {
        let nutrient = goal.wrappedValue.nutrient
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                iconChip(nutrient.systemImage, tint: nutrient.tint)
                Text(nutrient.label).font(.headline)
                Spacer()
                TextField("Target", value: goal.target, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                Text(nutrient.unit).foregroundStyle(.secondary)
                Button {
                    goalToRemove = goal.wrappedValue
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(nutrient.label) goal")
            }
            Picker("Direction", selection: goal.direction) {
                ForEach(NutrientFocusGoal.Direction.allCases, id: \.self) { direction in
                    Text(direction.label).tag(direction)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FocusGoalsView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
