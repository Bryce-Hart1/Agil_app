import SwiftUI

// Claude  Date 09/01/2026
// Two-line header for one exercise in the workout editor. Line 1 is the bare lift
// NAME at .headline, not uppercased; line 2 carries the facts that used to be crammed
// into the name string — equipment type (tinted, with its text), brand, unilateral.
// Callers MUST apply .textCase(nil) or SwiftUI uppercases the whole thing.
struct ExerciseSectionHeader: View {
    let exercise: Exercise?
    let targetRepRange: RepRange?
    let accent: Color
    let onEdit: (Exercise) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                // Claude  Date 09/01/2026
                // `name`, not displayLabel: brand and the unilateral flag are chips on
                // line 2 now, so using displayLabel here would label them twice.
                Text(exercise?.name ?? "Exercise")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                // Claude  Date 06/18/2026 last changed: 09/01/2026 by: Claude
                // Pencil → edit the underlying library exercise's details in place.
                if let exercise {
                    Button {
                        onEdit(exercise)
                    } label: {
                        Image(systemName: "pencil")
                            .fontWeight(.bold)
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(accent)
                    .accessibilityLabel("Edit \(exercise.displayLabel)")
                }

                Spacer(minLength: 8)

                if let targetRepRange {
                    Text("\(targetRepRange.display) reps")
                        .font(.subheadline)
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }
            }

            // Claude  Date 09/01/2026
            // The metadata strip. Each chip self-hides when its fact is unknown, so an
            // unclassified custom lift draws nothing here and the row collapses to one
            // line instead of leaving an empty band.
            if hasMetadata {
                // Claude  Date 09/03/2026
                // Brand leads, then equipment type: the strip reads as one phrase —
                // "Egym Machine" — the way the plate on the machine itself does. All
                // three chips share EquipmentBadge's `.detail` size so the neutral ones
                // don't read as a footnote to the tinted one.
                HStack(spacing: 6) {
                    BrandBadge(brand: exercise.flatMap(\.brandLabel), style: .detail)
                    EquipmentBadge(type: exercise?.equipmentType, style: .detail)
                    if exercise?.isUnilateral == true {
                        NeutralChip(text: "Unilateral", style: .detail)
                    }
                    // Claude  Date 09/07/2026 — names the cardio machine ("Treadmill"),
                    // which is what decides how this exercise logs. Reuses NeutralChip
                    // rather than adding a component; the rep-range label to the right
                    // self-hides, since a bout has no target range.
                    if let machine = exercise?.cardioMachine {
                        NeutralChip(text: machine.title, style: .detail)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var hasMetadata: Bool {
        guard let exercise else { return false }
        return exercise.equipmentType != nil || exercise.brandLabel != nil
            || exercise.isUnilateral || exercise.cardioMachine != nil
    }
}
