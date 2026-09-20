import SwiftUI

// CLAUDE  Date 09/19/2026
// Logging a weigh-in: weight, an optional body-fat estimate, and the day it belongs to.
// Deliberately small — daily weigh-ins only work if they take three seconds. Saving replaces
// any entry already on that day, since two readings from one morning are one measurement.
struct LogWeightSheet: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var bodyStore: BodyStore
    @AppStorage(BodyUnits.storageKey) private var unitsRaw = BodyUnits.defaultValue.rawValue
    @Environment(\.dismiss) private var dismiss

    /// Which day is being logged. Defaults to today; the hub can open it for a past day.
    @State var date = Date()
    @State private var weightField = ""
    @State private var bodyFatField = ""
    @FocusState private var weightFocused: Bool

    private var units: BodyUnits { BodyUnits(rawValue: unitsRaw) ?? .defaultValue }
    private var accent: Color { theme.current.accent }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Weight (\(units.weightAbbreviation))") {
                        TextField("", text: $weightField)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($weightFocused)
                    }
                    LabeledContent("Body fat % (optional)") {
                        TextField("", text: $bodyFatField)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("Most consistent first thing in the morning, after the bathroom, before eating. Day-to-day swings are mostly water — the plan reads your weekly average, not any one morning.")
                }

                Section {
                    DatePicker("Day", selection: $date, in: ...Date(), displayedComponents: .date)
                } footer: {
                    Text("Stays on this iPhone, encrypted.")
                }
            }
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(weightLb == nil)
                }
            }
            .onAppear {
                prefill()
                weightFocused = true
            }
        }
        .tint(accent)
    }

    private var weightLb: Double? {
        guard let value = Double(weightField.replacingOccurrences(of: ",", with: ".")),
              value > 0 else { return nil }
        return units.toPounds(value)
    }

    private var bodyFat: Double? {
        guard let value = Double(bodyFatField.replacingOccurrences(of: ",", with: ".")),
              value > 0, value < 70 else { return nil }
        return value
    }

    // CLAUDE  Date 09/19/2026
    // Prefill from the day being logged if it already has an entry, otherwise from the most
    // recent weigh-in — a scale rarely moves far in a day, so the keyboard starts near the
    // answer instead of empty.
    private func prefill() {
        let key = DayKey.key(for: date)
        if let existing = bodyStore.data.weighIns.first(where: { $0.dayKey == key }) {
            weightField = units.weightText(fromPounds: existing.weightLb)
            if let fat = existing.bodyFatPct { bodyFatField = String(format: "%.1f", fat) }
        } else if let latest = bodyStore.latestWeightLb {
            weightField = units.weightText(fromPounds: latest)
        }
    }

    private func save() {
        guard let weightLb else { return }
        bodyStore.logWeighIn(weightLb: weightLb, bodyFatPct: bodyFat, on: DayKey.key(for: date))
        Haptics.tap()
        dismiss()
    }
}

#Preview {
    LogWeightSheet()
        .environmentObject(ThemeManager())
        .environmentObject(BodyStore())
}
