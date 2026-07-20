import SwiftUI

// Claude  Date 07/19/2026 last changed: 07/20/2026 by: Claude
// The per-exercise action pair shared by the workout editor and the preset editor:
// "Swap" beside "Remove" on a single row rather than stacked. Both use hand-made
// template assets — the "swap" glyph (blue) and the "eraser" glyph (red) — tinted
// with fixed system colors that are universally understood and deliberately
// theme-independent, like the destructive red already was.
//
// `.buttonStyle(.borderless)` on each button is required: inside a Form row, a
// plain button would let a tap anywhere in the row fire both actions.
struct ExerciseActionsRow: View {
    let onSwap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 0) {
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
        // Keep each half's tap target inside its own button.
        .contentShape(Rectangle())
    }
}
