import SwiftUI

// Claude  Date 08/04/2026
// The two note tiers a lift can carry, as a matched pair of Form rows. Lives in
// one place because both editors show it — the live workout editor and the preset
// editor — and the whole point is that the two tiers look identical wherever you
// meet them, so a user learns the colour code once.
//
//   Perma   (full accent)          Exercise.note — belongs to the LIFT. Shows
//                                  everywhere that lift appears, and edits write
//                                  straight to the library, so it sticks even if
//                                  this workout is never saved.
//   Session (accent at 45%)        LoggedExercise.note / PresetItem.note — belongs
//                                  to this session or this template. Rides into a
//                                  preset when the workout is saved as one, and
//                                  comes back when that preset is started; if the
//                                  workout is never saved, it goes nowhere.
//
// The tiers are distinguished by weight of the SAME hue rather than by two
// different colours: a second hue would either clash with the user's chosen theme
// or fight the app's other semantic colours (red for destructive, green/amber on
// the nutrition ring). Same-hue-lighter reads as "the quieter one of these two"
// without introducing a colour that has to mean something.
//
// Both rows stay in whatever face their screen uses — the workout editor is SF
// Pro, the preset editor is the theme's mono — so the colour is the only
// differentiator and the fields sit naturally in their surroundings.
struct ExerciseNoteFields: View {
    /// The library lift whose perma note this edits.
    let exerciseId: UUID
    /// The per-session (or per-template) note.
    @Binding var sessionNote: String?
    let accent: Color

    @EnvironmentObject private var store: AppStore

    var body: some View {
        // A lift deleted out from under an open editor has no perma note to edit;
        // the session note still belongs to this workout, so it stays.
        if store.exercise(for: exerciseId) != nil {
            noteRow(
                icon: "pin.fill",
                tint: accent,
                placeholder: "Exercise note (always shows for this lift)",
                text: Binding(store.exerciseNoteBinding(for: exerciseId), replacingNilWith: "")
            )
        }

        noteRow(
            icon: "bubble.left",
            tint: accent.opacity(0.45),
            placeholder: "Session note (just for this workout)",
            text: Binding($sessionNote, replacingNilWith: "")
        )
    }

    // Claude  Date 08/04/2026
    // Shared row body. The leading bar is what carries the tier at a glance once a
    // note is filled in — the placeholder text explaining which is which is gone
    // by then, and an icon alone is too small to read as a category.
    private func noteRow(icon: String, tint: Color, placeholder: String,
                         text: Binding<String>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(tint)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 16)
                .padding(.top, 3)

            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(1...4)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
