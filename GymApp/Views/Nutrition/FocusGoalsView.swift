import SwiftUI

// Claude  Date 07/12/2026
// Sheet for managing nutrient focus goals, opened from the diary's top-left
// Focus button. Lists the goals being tracked (editable target + direction,
// swipe to delete) and offers the not-yet-tracked nutrients to add — one goal
// per nutrient. Edits write straight through to the store (which auto-persists),
// matching the goals screen; Done just dismisses.
struct FocusGoalsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private var untracked: [NutrientFocusGoal.Nutrient] {
        NutrientFocusGoal.Nutrient.allCases.filter { nutrient in
            !store.focusGoals.contains { $0.nutrient == nutrient }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if store.focusGoals.isEmpty {
                    Section {
                        Text("Pick a nutrient to focus on — its progress will show under the diary's Summary each day.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                if !store.focusGoals.isEmpty {
                    Section {
                        ForEach($store.focusGoals) { $goal in
                            goalRow($goal)
                        }
                        .onDelete { store.deleteFocusGoals(at: $0) }
                    } header: {
                        Text("Tracking")
                    } footer: {
                        Text("Swipe a goal to remove it.")
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
            .navigationTitle("Focus Goals")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // Claude  Date 07/12/2026
    // One tracked goal: chip + name, trailing editable target with unit, and a
    // segmented at-least / stay-under picker beneath.
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
