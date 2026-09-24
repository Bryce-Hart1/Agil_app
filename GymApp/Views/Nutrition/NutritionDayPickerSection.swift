import SwiftUI

/// The day picker shared by Journal and Log, so both screens show the same day.
struct NutritionDayPickerSection: View {
    @Binding var selectedDate: Date

    var body: some View {
        Section {
            HStack {
                Button { step(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                Spacer()
                VStack(spacing: 1) {
                    Text(selectedDate, format: .dateTime.weekday(.wide))
                        .font(.headline)
                    Text(selectedDate, format: .dateTime.month().day().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { step(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.borderless)
                    .disabled(Calendar.current.isDateInToday(selectedDate))
            }
            if !Calendar.current.isDateInToday(selectedDate) {
                Button("Jump to Today") { selectedDate = Date() }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func step(_ days: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: days, to: selectedDate)
        else { return }
        if days > 0 && next > Date() { return }
        selectedDate = next
    }
}
