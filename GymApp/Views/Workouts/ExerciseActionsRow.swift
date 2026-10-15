import SwiftUI

// Claude  Date 07/19/2026 last changed: 10/14/2026 by: CLAUDE
// The per-exercise action pair shared by the workout editor and the preset editor:
// "Swap" beside "Remove" on a single row rather than stacked. Both use hand-made
// template assets — the "swap" glyph (blue) and the "eraser" glyph (red) — tinted
// with fixed system colors that are universally understood and deliberately
// theme-independent, like the destructive red already was.
// (10/14) Optional "Plates" (calculator glyph, indigo) leads the row when `onCalculate` is
// passed; only the workout editor does, for barbell and plate-loaded lifts.
//
// `.buttonStyle(.borderless)` on each button is required: inside a Form row, a
// plain button would let a tap anywhere in the row fire both actions.
struct ExerciseActionsRow: View {
    let onSwap: () -> Void
    let onRemove: () -> Void
    // Declared last so the preset editor's trailing-closure call keeps matching onSwap.
    var onCalculate: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            if let onCalculate {
                Button {
                    onCalculate()
                } label: {
                    Label("Plates", image: "calculator")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.indigo)
                .accessibilityLabel("Plate calculator")

                Divider()
                    .frame(height: 22)
            }

            Button {
                onSwap()
            } label: {
                Label("Swap", image: "swap")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.blue)
            .accessibilityLabel("Swap exercise")

            Divider()
                .frame(height: 22)

            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", image: "eraser")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .accessibilityLabel("Remove exercise")
        }
        // CLAUDE  Date 10/14/2026
        // Three labels don't fit at body size on a phone ("Remove" wrapped to "Re-/move"), so the
        // row drops to subheadline when Plates is present. The two-button rows keep body size.
        .font(onCalculate == nil ? .body : .subheadline)
        .lineLimit(1)
        // Keep each half's tap target inside its own button.
        .contentShape(Rectangle())
    }
}
