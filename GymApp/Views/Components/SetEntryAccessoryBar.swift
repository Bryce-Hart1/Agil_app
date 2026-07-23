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

    var setID: UUID {
        switch self {
        case .reps(let id), .weight(let id): return id
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
    let onAdjust: (Double) -> Void
    let onDone: () -> Void

    // Claude  Date 07/21/2026
    // Plate-friendly jumps for weight (a pair of 1.25s is the smallest change most racks
    // allow) and single reps for the rep field. Ordered negative → positive so the row
    // reads like a number line.
    private var steps: [Double] {
        switch field {
        case .reps:   return [-1, 1]
        case .weight: return [-5, -2.5, 2.5, 5]
        case nil:     return []
        }
    }

    // Claude  Date 07/21/2026
    // Metrics borrowed from the iPhone keyboard so the row sits under it as a matched
    // set: ~5pt continuous corners, ~6pt between keys, a key roughly 38pt tall. These are
    // the numbers to nudge if a future iOS restyles its keys.
    private static let keyCornerRadius: CGFloat = 5
    private static let keySpacing: CGFloat = 6
    private static let keyHeight: CGFloat = 38
    // Claude  Date 07/21/2026 last changed: 07/21/2026 by: Claude
    // These floors ARE the key widths in practice: the keyboard toolbar sizes itself to
    // its content rather than proposing the full screen width, so `maxWidth: .infinity`
    // resolves to the minimum and the row renders exactly this wide. Widening a key means
    // raising its floor.
    //
    // They're also load-bearing. Without a minimum, `maxWidth: .infinity` lets a view
    // compress to nothing — which silently broke the weight row: SwiftUI squeezed all four
    // steppers to zero and left only Done (whose padding it couldn't shrink), collapsing
    // the bar to a lone accent square. The three-key rep row always fit, which is why only
    // weight looked broken.
    //
    // Budget check before raising these. The widest the row may be is the narrowest
    // supported screen minus the toolbar's own inset: iOS 16.1 runs on 375pt devices at
    // the low end, leaving ~343pt. The weight row costs
    // 4×keyMinWidth + doneMinWidth + 4×keySpacing = 328pt, so there's ~15pt of headroom.
    // Push past that and the row overflows and clips — the same failure as before, from
    // the other direction.
    private static let keyMinWidth: CGFloat = 58
    private static let doneMinWidth: CGFloat = 72

    // Claude  Date 07/21/2026
    // Done sits in the MIDDLE with the decreases to its left and the increases to its
    // right — the row reads as a number line with the exit in the middle, and the thumb
    // has the same reach either way. Keys split the width evenly, as a keyboard row does.
    //
    // With no steppers to show (the note and rep-range fields) Done keeps its natural
    // width between spacers rather than stretching: a full-width accent slab for a plain
    // dismiss button would shout far louder than the keyboard beneath it.
    var body: some View {
        HStack(spacing: Self.keySpacing) {
            if steps.isEmpty {
                Spacer(minLength: 0)
                doneKey.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
            } else {
                ForEach(steps.filter { $0 < 0 }, id: \.self) { stepKey($0) }
                doneKey
                ForEach(steps.filter { $0 > 0 }, id: \.self) { stepKey($0) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var doneKey: some View {
        Button(action: onDone) {
            Text("Done")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent.contrastingForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: Self.doneMinWidth, maxWidth: .infinity,
                       minHeight: Self.keyHeight)
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
                .frame(minWidth: Self.keyMinWidth, maxWidth: .infinity,
                       minHeight: Self.keyHeight)
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
        case .reps:   unit = abs(step) == 1 ? "rep" : "reps"
        case .weight: unit = "pounds"
        case nil:     unit = ""
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
