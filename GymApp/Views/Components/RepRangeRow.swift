import SwiftUI

// Bryce Hart 6/4/26 last changed: 06/13/2026 by: Claude
/// Sets or edits a target rep range. Shows an "add" affordance when no range is
/// set, and inline min/max fields (with a clear button) once it is.
///
/// Shared by the workout editor (per logged exercise) and the preset editor
/// (per preset item).
///
// Claude  Date 06/13/2026
// Reworked the inputs to be string-backed instead of `.number`-formatted Int
// fields. The old Int fields refused an empty string, so clearing a value to
// retype it snapped back — frustrating to change. Now each field:
//   • accepts digits only (no negatives, no junk),
//   • can be left blank while you're editing (no snap-back),
//   • is normalized when focus leaves: both blank → range removed; one blank →
//     mirrors the other (a single target); otherwise kept as entered. Display
//     order is handled by RepRange.display, so min/max order doesn't matter.
struct RepRangeRow: View {
    @Binding var targetRepRange: RepRange?
    // CLAUDE  Date 09/17/2026
    // Reports which bound has the keyboard (nil when it leaves), so a screen can put its
    // ±1 rep steppers in the keyboard bar. Optional: the workout editor doesn't track it.
    var onFocusChange: ((Field?) -> Void)? = nil

    @State private var minText = ""
    @State private var maxText = ""
    @FocusState private var focused: Field?

    enum Field: Hashable { case min, max }

    var body: some View {
        Group {
            if targetRepRange != nil {
                activeRow
            } else {
                Button {
                    targetRepRange = RepRange(min: 8, max: 12)
                } label: {
                    Label("Set rep range", systemImage: "target")
                }
            }
        }
        .onAppear(perform: syncText)
        // Re-seed the text when the range is (re)added via the button.
        .onChange(of: targetRepRange == nil) { isNil in if !isNil { syncText() } }
        // Settle edge cases once the user taps away from the fields.
        .onChange(of: focused) { newValue in
            if newValue == nil { normalize() }
            onFocusChange?(newValue)
        }
        // CLAUDE  Date 09/17/2026
        // Keyboard-bar steppers edit the range directly, so re-show it in the fields.
        .onChange(of: targetRepRange) { _ in syncIfEditedElsewhere() }
    }

    private var activeRow: some View {
        HStack {
            Label("Target", systemImage: "target")
                .foregroundStyle(.secondary)
            Spacer()
            numberField($minText, placeholder: "min", field: .min)
            Text("–").foregroundStyle(.secondary)
            numberField($maxText, placeholder: "max", field: .max)
            Text("reps").foregroundStyle(.secondary)
            Button {
                targetRepRange = nil
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func numberField(_ text: Binding<String>, placeholder: String, field: Field) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .frame(width: 44)
            .focused($focused, equals: field)
            .onChange(of: text.wrappedValue) { newValue in
                // Keep digits only (blocks "-" and other characters); cap length.
                let digits = String(newValue.filter(\.isNumber).prefix(3))
                if digits != newValue { text.wrappedValue = digits }
                liveCommit()
            }
    }

    // Keep the model in sync as the user types so the value isn't lost if the
    // sheet closes without a blur. Leaves the range untouched while *both* fields
    // are blank (normalize() handles that on focus loss) to avoid churning to 0–0.
    private func liveCommit() {
        guard targetRepRange != nil else { return }
        let lo = Int(minText)
        let hi = Int(maxText)
        guard lo != nil || hi != nil else { return }
        targetRepRange = RepRange(min: lo ?? 0, max: hi ?? 0)
    }

    // Resolve the edge cases when the fields lose focus.
    private func normalize() {
        guard targetRepRange != nil else { return }
        switch (Int(minText), Int(maxText)) {
        case (nil, nil):
            targetRepRange = nil                          // left entirely blank → no range
        case (let only?, nil), (nil, let only?):
            targetRepRange = RepRange(min: only, max: only) // one side blank → single target
            syncText()
        case (let lo?, let hi?):
            targetRepRange = RepRange(min: lo, max: hi)
        }
    }

    // CLAUDE  Date 09/17/2026
    // Re-shows only a side that no longer matches what's typed (blank reads as 0, as
    // liveCommit writes it). Typing always matches, so a just-cleared field isn't turned
    // into "0" mid-edit, and a stepper on one side leaves a blank other side blank.
    private func syncIfEditedElsewhere() {
        guard let range = targetRepRange else { return }
        if (Int(minText) ?? 0) != range.min { minText = "\(range.min)" }
        if (Int(maxText) ?? 0) != range.max { maxText = "\(range.max)" }
    }

    private func syncText() {
        if let range = targetRepRange {
            minText = "\(range.min)"
            maxText = "\(range.max)"
        }
    }
}
