import SwiftUI

// Claude  Date 08/04/2026 last changed: 08/11/2026 by: Claude
// The note tiers a lift can carry, as Form rows. Lives in one place because both
// editors show it — the live workout editor and the preset editor — so a user
// learns the colour code once.
//
//   Perma   (full accent, pin)     Exercise.note — belongs to the LIFT. Shows
//                                  everywhere that lift appears, and edits write
//                                  straight to the library, so it sticks even if
//                                  this workout is never saved.
//   Session (accent at 45%,        LoggedExercise.note — a note to your NEXT
//            bubble)               session of this preset. Two states, below.
//
// The tiers are distinguished by weight of the SAME hue rather than by two
// different colours: a second hue would either clash with the user's chosen theme
// or fight the app's other semantic colours (red for destructive, green/amber on
// the nutrition ring). Same-hue-lighter reads as "the quieter one of these two"
// without introducing a colour that has to mean something.
//
// Claude  Date 08/11/2026
// The session note has a ONE-SESSION LIFESPAN, and the icon is what says where it
// is in that life:
//
//   bubble.left.fill  fresh    — written this session, addressed to future-you.
//                               It will appear in your next session of this preset.
//   bubble.left       expiring — carried in from last session. This is its last
//                               showing; it won't be carried again. Editing it
//                               re-arms it, and the icon fills back in as you type.
//
// ⚠️ Freshness is encoded ONLY as filled-vs-outline, never as opacity. Opacity is
// already spoken for by the tier above (session = 45%), and stacking a second
// dimming on top would both make the row nearly invisible and blur the one
// distinction this file exists to protect. The fill axis was the free one.
//
// Both rows stay in whatever face their screen uses — the workout editor is SF
// Pro, the preset editor is the theme's mono — so the colour is the only
// differentiator and the fields sit naturally in their surroundings.
struct ExerciseNoteFields: View {
    /// The library lift whose perma note this edits.
    let exerciseId: UUID
    /// The note to your next session of this preset.
    @Binding var sessionNote: String?
    let accent: Color
    // Claude  Date 08/07/2026 last changed: 08/11/2026 by: Claude
    // Whether the session row is offered at all. Two callers pass false: the PRESET editor
    // (a template is built in advance, not lived through — there's no session to write from)
    // and any AD-HOC workout, which has no preset and therefore no "next session of this"
    // for a note to reach. Offering the row there would promise a future-you who never
    // arrives.
    var showsSessionNote: Bool = true
    // Claude  Date 08/11/2026
    // True when `sessionNote` was carried in from the previous session — its last showing.
    // Drives the outline icon; see the header note on why this is not an opacity change.
    var sessionNoteIsExpiring: Bool = false
    // Claude  Date 08/11/2026
    // Called when the user edits the session note. The owner uses it to clear the
    // carried-forward flag, which re-arms the note for another session — so the icon fills
    // in live, mid-keystroke, as it stops being someone else's message and becomes yours.
    var onEditSessionNote: () -> Void = {}

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

        if showsSessionNote {
            // Filled means "there is a live message waiting for future-you", so it takes
            // BOTH a note and freshness. An empty row is outline (nothing to deliver) and
            // so is an expiring one (already delivered) — they're never confusable, because
            // one of them visibly has text in it and the other shows its placeholder.
            let hasNote = !(sessionNote ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let filled = hasNote && !sessionNoteIsExpiring
            noteRow(
                icon: filled ? "bubble.left.fill" : "bubble.left",
                tint: accent.opacity(0.45),
                placeholder: "Note for next time (shows once, next session)",
                text: Binding(
                    get: { sessionNote ?? "" },
                    set: { newValue in
                        // Mirrors Binding(_:replacingNilWith:) — blank persists as nil, so
                        // "has a note" stays a simple nil check everywhere else.
                        let trimmed = newValue.isEmpty ? nil : newValue
                        guard trimmed != sessionNote else { return }
                        sessionNote = trimmed
                        onEditSessionNote()
                    }
                )
            )
        }
    }

    // Claude  Date 08/04/2026 last changed: 08/07/2026 by: Claude
    // Shared row body. The leading bar is what carries the tier at a glance once a
    // note is filled in — the placeholder text explaining which is which is gone
    // by then, and an icon alone is too small to read as a category.
    //
    // (08/07) Set in .subheadline rather than the inherited body size, and allowed up
    // to six lines. These placeholders are long enough to be sentences, and at body
    // size in the app's wide mono face the tail of both of them was cut off — which is
    // exactly the text that says which tier the row is.
    private func noteRow(icon: String, tint: Color, placeholder: String,
                         text: Binding<String>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(tint)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(tint)
                .frame(width: 14)
                .padding(.top, 3)

            TextField(placeholder, text: text, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...6)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
