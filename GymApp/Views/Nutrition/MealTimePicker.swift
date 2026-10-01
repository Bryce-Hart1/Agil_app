import SwiftUI

// CLAUDE  Date 09/30/2026
// The "When" row on every food-logging surface: a meal menu and a compact clock. The time
// follows the meal (switch to Breakfast and it jumps to your usual breakfast time) until
// the user sets it themselves, and from then on stays where they put it. Used by the
// food page, recipe page and quick add. The caller seeds nothing; `suggest` does it.
struct MealTimePicker: View {
    @Binding var meal: MealType
    @Binding var time: Date
    let accent: Color
    // The time to show for a meal the user hasn't timed by hand (AppStore.suggestedLogTime).
    let suggest: (MealType) -> Date

    @State private var timeTouched = false

    var body: some View {
        // CLAUDE  Date 09/30/2026 — both controls fixedSize: a menu Picker is flexible, so
        // it split the leftover width with the Spacer and wrapped "Breakfast" letter by letter.
        HStack(spacing: 8) {
            Text("When").font(.subheadline).foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Picker("Meal", selection: $meal) {
                ForEach(MealType.allCases) { meal in
                    Label(meal.title, systemImage: meal.systemImage).tag(meal)
                }
            }
            .pickerStyle(.menu)
            .tint(accent)
            .fixedSize()
            DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(accent)
                .fixedSize()
        }
        .onAppear { if !timeTouched { time = suggest(meal) } }
        .onChange(of: meal) { newMeal in
            if !timeTouched { time = suggest(newMeal) }
        }
    }

    // Writes through, and marks the time as the user's own so a meal switch won't move it.
    private var timeBinding: Binding<Date> {
        Binding(get: { time }, set: { newValue in
            time = newValue
            timeTouched = true
        })
    }
}
