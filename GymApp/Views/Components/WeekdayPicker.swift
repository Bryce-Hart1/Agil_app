import SwiftUI

// Claude  Date 08/29/2026
// A seven-pill weekday selector. The app's first one — the ModeNotch's check-in dots and
// the Shop's "This week" strip look similar but are read-only progress dots with no symbols,
// so they lent the visual treatment and nothing else.
//
// The rotation is the part that's easy to get wrong. Calendar's weekday NUMBERS are fixed
// at 1 = Sunday … 7 = Saturday and have nothing to do with firstWeekday; firstWeekday only
// decides where the week is drawn from. veryShortWeekdaySymbols is likewise indexed
// 0 = Sunday regardless. Both concerns live in SupplementSlot.displayOrder/initials so
// this view and the "Mon, Wed, Fri" summary label can't drift apart.
struct WeekdayPicker: View {
    @EnvironmentObject private var theme: ThemeManager

    @Binding var selection: Set<Int>

    private let order = SupplementSlot.displayOrder()
    private let initials = SupplementSlot.initials()

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(order.enumerated()), id: \.element) { index, weekday in
                let on = selection.contains(weekday)
                Button {
                    // Never let the set empty out: a slot with no days is a slot that can
                    // never be due and never reminds, which reads as the feature being
                    // broken rather than as a choice. Un-picking the last day is a no-op.
                    if on {
                        if selection.count > 1 { selection.remove(weekday) }
                    } else {
                        selection.insert(weekday)
                    }
                } label: {
                    Text(initials[index])
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .foregroundStyle(on ? Color.white : Color.secondary)
                        .background(
                            Circle().fill(on
                                          ? AnyShapeStyle(theme.current.accent)
                                          : AnyShapeStyle(Color.secondary.opacity(0.15)))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .animation(.easeInOut(duration: 0.15), value: selection)
    }
}

#Preview {
    struct Harness: View {
        @State private var days: Set<Int> = [2, 4, 6]
        var body: some View {
            List {
                Section("Days") {
                    WeekdayPicker(selection: $days)
                    Text(SupplementSlot(name: "Preview", weekdays: days).daysLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    return Harness().environmentObject(ThemeManager())
}
