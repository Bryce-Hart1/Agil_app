import SwiftUI

// Claude  Date 09/07/2026
// One-time, skippable prompt for the bodyweight the cardio calorie estimate needs, raised
// from a bout that has no calorie figure to show. Skipping is a real answer — cardio keeps
// tracking time, distance and pace without it — so "Not now" sits as prominently as Save,
// and the footer states the privacy contract rather than burying it in Settings.
struct BodyweightPromptView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @FocusState private var focused: Bool

    // Claude  Date 09/07/2026
    // Clamped at 1500 lb, past the heaviest human on record: it rejects a fat-fingered extra
    // digit (which would inflate every calorie figure) without standing in a real user's way.
    private var value: Double? {
        let parsed = Double(text.filter { $0.isNumber || $0 == "." }) ?? 0
        return parsed > 0 ? Swift.min(parsed, 1_500) : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Weight", text: $text)
                            .keyboardType(.decimalPad)
                            .focused($focused)
                        Text("lb").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Calories burned are estimated from your weight, the machine and your pace — a ballpark, not a measurement. Your weight stays on this device: it is never synced, shared, or sent with your profile card, and you can change or clear it any time in Settings.")
                }
            }
            .themed(theme.current)
            .navigationTitle("Estimate Calories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.profile.bodyweightLb = value
                        dismiss()
                    }
                    .disabled(value == nil)
                }
            }
            .onAppear {
                // Pre-fill when one is already on file, so this doubles as a quick edit.
                if let lb = store.profile.bodyweightLb, lb > 0 {
                    text = lb.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(lb)) : String(lb)
                }
                focused = true
            }
        }
    }
}

#Preview {
    BodyweightPromptView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
