import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 07/21/2026
// Which set field the workout editor's keyboard is currently attached to, keyed by the
// set's own id (stable across reorders and inserts, unlike an index). Drives the
// @FocusState in WorkoutEditor and tells SetEntryAccessoryBar which steppers to offer.
enum SetEntryField: Hashable {
    case reps(UUID)
    case weight(UUID)
    // Claude  Date 09/07/2026
    // The three cardio-bout fields. A bout is entered as minutes + seconds rather than one
    // number, so each half focuses separately and gets its own steppers below.
    case durationMinutes(UUID)
    case durationSeconds(UUID)
    case distance(UUID)

    var setID: UUID {
        switch self {
        case .reps(let id), .weight(let id),
             .durationMinutes(let id), .durationSeconds(let id), .distance(let id):
            return id
        }
    }

    /// Whether this field belongs to a cardio bout (so the bar steps time/distance).
    var isCardio: Bool {
        switch self {
        case .durationMinutes, .durationSeconds, .distance: return true
        case .reps, .weight:                                return false
        }
    }
}

// Claude  Date 07/21/2026
// The bar that sits on top of the keyboard while logging sets. Beyond dismissing the
// keyboard it offers quick steppers for whichever field is focused, so a working weight
// can be nudged (+5, −2.5…) without selecting and retyping the number — the common case
// when the bar goes up a plate from last week.
//
// `field` is nil whenever focus is on something that isn't a set field (the workout note,
// an exercise's form cue, a rep-range field). The bar then collapses to just Done, which
// is exactly what those fields had before.
//
// Hosted by SwiftUI's ToolbarItemGroup(placement: .keyboard), which under iOS 26 draws it
// inside a rounded system container inset from the screen edges (older iOS gives a plain
// bar — the styling has to hold either way). A square, edge-to-edge slab was tried and
// rejected: the container can't be restyled from SwiftUI, and reaching past it needs a
// UIKit inputAccessoryView, which looked worse in practice.
//
// The cells are styled as KEYCAPS — the keyboard's own corner radius and neutral fill,
// split evenly across the width — so the row reads as one more keyboard row instead of an
// app widget parked on the keyboard. The capsule chips they replace stacked a third corner
// radius on top of the system container's and the keys', which is what made the bar look
// unconsidered; accent is now spent on the single Done key rather than washed across four.
struct SetEntryAccessoryBar: View {
    let field: SetEntryField?
    let accent: Color
    // Claude  Date 09/07/2026
    // Read here rather than passed in, matching how the water views resolve their unit:
    // only the distance steppers' VoiceOver labels need it.
    @AppStorage(DistanceUnit.storageKey) private var distanceUnitRaw = DistanceUnit.miles.rawValue
    private var distanceUnit: DistanceUnit {
        DistanceUnit(rawValue: distanceUnitRaw) ?? .miles
    }
    let onAdjust: (Double) -> Void
    let onDone: () -> Void

    // Claude  Date 07/21/2026
    // Plate-friendly jumps for weight (a pair of 1.25s is the smallest change most racks
    // allow) and single reps for the rep field. Ordered negative → positive so the row
    // reads like a number line.
    // Claude  Date 09/07/2026
    // Cardio jumps: 5- and 1-minute blocks, quarter- and twelfth-of-a-minute seconds, and
    // tenths/halves of the user's distance unit. All four keys wide, like the weight row —
    // the bar's fixed width already assumes four is the maximum.
    private var steps: [Double] {
        switch field {
        case .reps:            return [-1, 1]
        case .weight:          return [-5, -2.5, 2.5, 5]
        case .durationMinutes: return [-5, -1, 1, 5]
        case .durationSeconds: return [-15, -5, 5, 15]
        case .distance:        return [-0.5, -0.1, 0.1, 0.5]
        case nil:              return []
        }
    }

    // Claude  Date 07/21/2026
    // Metrics borrowed from the iPhone keyboard so the row sits under it as a matched
    // set: ~5pt continuous corners, ~6pt between keys, a key roughly 38pt tall. These are
    // the numbers to nudge if a future iOS restyles its keys.
    private static let keyCornerRadius: CGFloat = 5
    private static let keySpacing: CGFloat = 6
    private static let keyHeight: CGFloat = 38
    // Claude  Date 08/18/2026
    // FIXED widths, not floors, and deliberately so.
    //
    // The previous version paired `minWidth:` with `maxWidth: .infinity` on every key plus
    // `.frame(maxWidth: .infinity)` on the row, on the theory that the keyboard toolbar
    // proposes only its content's width so the maximums would collapse back to the
    // minimums. That theory is wrong on iOS 26: the toolbar proposes the FULL SCREEN
    // width, while the rounded glass container it draws the row inside is inset ~28pt a
    // side and padded internally — so the row laid itself out at ~393pt inside a ~340pt
    // window, splitting five keys at ~74pt each. The result is the reported bug: the row
    // sits off-centre and the trailing +5 key is clipped away by the container's edge.
    // The rep row has three keys and enough slack to survive the same overflow, which is
    // why only weight looked broken.
    //
    // Fixed widths take the proposal out of the equation: the row is always
    // 4×keyWidth + doneWidth + 4×keySpacing = 288pt regardless of what is proposed, which
    // fits inside the container's usable width on every shipping iPhone (~303pt on the
    // 375pt SE, ~321pt at 393pt). Raise these only against `screen − 72`, never
    // `screen − 32`, and never reintroduce `maxWidth: .infinity` here.
    private static let keyWidth: CGFloat = 50
    private static let doneWidth: CGFloat = 64

    // Claude  Date 07/21/2026
    // Done sits in the MIDDLE with the decreases to its left and the increases to its
    // right — the row reads as a number line with the exit in the middle, and the thumb
    // has the same reach either way. Every key is the same width, as a keyboard row is.
    //
    // With no steppers to show (the note and rep-range fields) the row is Done alone at its
    // fixed width, which the toolbar centres — a full-width accent slab for a plain dismiss
    // button would shout far louder than the keyboard beneath it.
    var body: some View {
        HStack(spacing: Self.keySpacing) {
            ForEach(steps.filter { $0 < 0 }, id: \.self) { stepKey($0) }
            doneKey
            ForEach(steps.filter { $0 > 0 }, id: \.self) { stepKey($0) }
        }
        // Claude  Date 08/13/2026 last changed: 08/18/2026 by: Claude
        // The widths above are fixed, so oversized type can no longer widen a key — but it
        // could still overflow one, since "−2.5" at an accessibility size is wider than
        // 50pt. Capping the bar's type size keeps the labels inside their keycaps at any
        // device setting; they're short digits, so holding them at .large costs nothing in
        // legibility. The rest of the app scales freely.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private var doneKey: some View {
        Button(action: onDone) {
            Text("Done")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent.contrastingForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: Self.doneWidth, height: Self.keyHeight)
                .background(accent, in: keyShape)
                .contentShape(keyShape)
        }
        .buttonStyle(.plain)
    }

    private func stepKey(_ step: Double) -> some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            onAdjust(step)
        } label: {
            Text(label(for: step))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: Self.keyWidth, height: Self.keyHeight)
                .background(Self.keyFill, in: keyShape)
                .contentShape(keyShape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: step))
    }

    private var keyShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.keyCornerRadius, style: .continuous)
    }

    // Claude  Date 07/21/2026
    // Where a real keycap sits in each mode — white on light, dark gray on dark. Flat, with
    // no shadow or border, matching AgilTabBar's stance for the app's own chrome.
    private static let keyFill = Color(uiColor: .secondarySystemGroupedBackground)

    // "+5" / "−2.5" / "+1" — a true minus sign, and no trailing ".0" on whole numbers.
    private func label(for step: Double) -> String {
        let magnitude = step.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(abs(step)))
            : String(abs(step))
        return (step < 0 ? "−" : "+") + magnitude
    }

    private func accessibilityLabel(for step: Double) -> String {
        let unit: String
        switch field {
        case .reps:            unit = abs(step) == 1 ? "rep" : "reps"
        case .weight:          unit = "pounds"
        case .durationMinutes: unit = abs(step) == 1 ? "minute" : "minutes"
        case .durationSeconds: unit = "seconds"
        // Claude  Date 09/07/2026 — the distance stepper works in whatever unit the user
        // picked, so VoiceOver has to name that unit rather than assume miles.
        case .distance:        unit = distanceUnit.abbreviation
        case nil:              unit = ""
        }
        let verb = step < 0 ? "Decrease" : "Increase"
        return "\(verb) by \(label(for: step).dropFirst()) \(unit)"
    }
}

// Claude  Date 07/21/2026
// The three states, stacked, over the system grouped background so the keycaps read
// against something close to a real keyboard. The horizontal padding stands in for the
// toolbar's own inset, so the width is roughly what the bar really gets. The last row uses
// a pale accent on purpose — that's the contrastingForeground flip, where Done's label has
// to go dark or vanish.
#Preview {
    VStack(spacing: 24) {
        SetEntryAccessoryBar(field: .weight(UUID()), accent: .accentColor,
                             onAdjust: { _ in }, onDone: {})
        SetEntryAccessoryBar(field: .reps(UUID()), accent: .accentColor,
                             onAdjust: { _ in }, onDone: {})
        SetEntryAccessoryBar(field: nil, accent: .accentColor,
                             onAdjust: { _ in }, onDone: {})
        SetEntryAccessoryBar(field: .weight(UUID()), accent: Color(hex: "#F2E14C"),
                             onAdjust: { _ in }, onDone: {})
    }
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(uiColor: .systemGroupedBackground))
}
