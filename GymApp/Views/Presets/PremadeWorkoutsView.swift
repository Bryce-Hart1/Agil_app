import SwiftUI

// Claude  Date 07/25/2026 - edited 7-25-26 Bryce Hart
// Browse the shipped workout templates (see PremadeWorkout). This is the answer to
// the blank slate a brand-new user hits: rather than building a preset lift by lift,
// they pick a ready-made split, optionally rename it and swap its icon, and it lands
// in their library as an ordinary preset.
//
// Reachable three ways — the Profile nav row and the Presets tab push it, and the
// Workouts empty state presents it in a sheet. It never wraps itself in a
// NavigationStack; every call site already provides one. Pass `isModal: true` from
// the sheet so it gets a Close button (a pushed copy has the back chevron instead).
struct PremadeWorkoutsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var isModal: Bool = false

    var body: some View {
        List {
            Section {
                ForEach(PremadeWorkouts.all) { premade in
                    NavigationLink {
                        PremadeWorkoutDetailView(premade: premade)
                    } label: {
                        PremadeRow(premade: premade,
                                   accent: theme.current.accent,
                                   isAdded: isAdded(premade))
                    }
                }
            } header: {
                Text("Need inspiration? Start with one of our teams researched workouts")
                    .textCase(nil)
                    .supportingTextFont()
            }
        }
        .navigationTitle("Premade Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .toolbar {
            if isModal {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // Claude  Date 07/25/2026
    // Whether this template is already in the library. Matched on the premadeID slug
    // rather than the name, so a preset the user renamed still reads as "Added".
    private func isAdded(_ premade: PremadeWorkout) -> Bool {
        store.presets.contains { $0.premadeID == premade.id }
    }
}

// MARK: - Row

private struct PremadeRow: View {
    let premade: PremadeWorkout
    let accent: Color
    let isAdded: Bool

    var body: some View {
        HStack(spacing: 12) {
            PresetIconView(name: premade.symbolName, size: 24)
                .foregroundStyle(accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(premade.name)
                    .font(.headline)
                Text(premade.rowSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .supportingTextFont()
            }
            if isAdded {
                Spacer()
                Text("Added")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.15), in: Capsule())
            }
        }
    }
}

// MARK: - Detail

// Claude  Date 07/25/2026
// One template, previewed before it's installed. Name and icon are local @State
// seeded from the catalog so edits here don't touch anything until "Add to My
// Presets" — that button is the only write, and it hands both values to
// AppStore.installPremade.
struct PremadeWorkoutDetailView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let premade: PremadeWorkout

    @State private var name: String
    @State private var symbolName: String

    init(premade: PremadeWorkout) {
        self.premade = premade
        _name = State(initialValue: premade.name)
        _symbolName = State(initialValue: premade.symbolName)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Preset name", text: $name)
            }

            Section("Icon") {
                IconGrid(selected: $symbolName, accent: theme.current.accent)
            }

            Section("Exercises (\(premade.items.count))") {
                // Keyed by position, not name: a template is allowed to repeat a lift
                // (e.g. a second, lighter back-off block), which duplicate ids would break.
                ForEach(premade.items.indices, id: \.self) { index in
                    let item = premade.items[index]
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                        Text(planSummary(for: item))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .supportingTextFont()
                        if let note = item.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button {
                    hideKeyboard()
                    store.installPremade(premade, name: name, symbolName: symbolName)
                    dismiss()
                } label: {
                    Text("Add to My Presets")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            } footer: {
                Text("Adds it to your presets. Start it any time from the + on the Workouts tab.")
            }
        }
        .navigationTitle(name.isEmpty ? premade.name : name)
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
            }
        }
    }

    // Claude  Date 07/25/2026
    // The one-line plan for a lift, e.g. "3 × 8–12 · rest 2:00". Each piece is dropped
    // when the catalog entry leaves it out, so an entry with only a set count reads
    // "3 sets" rather than carrying empty separators.
    private func planSummary(for item: PremadeExercise) -> String {
        var parts: [String] = []
        if let sets = item.sets {
            if let reps = item.reps {
                parts.append("\(sets) × \(reps.display)")
            } else {
                parts.append("\(sets) set\(sets == 1 ? "" : "s")")
            }
        } else if let reps = item.reps {
            parts.append("\(reps.display) reps")
        }
        if let rest = item.restSeconds {
            parts.append("rest \(RestDuration.label(rest))")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack {
        PremadeWorkoutsView()
            .environmentObject(AppStore())
            .environmentObject(ThemeManager())
    }
}
