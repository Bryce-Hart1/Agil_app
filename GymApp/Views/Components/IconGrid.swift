import SwiftUI

/// A grid of selectable preset icons (SF Symbols plus our custom art — see PresetIcons).
// Claude  Date 07/01/2026 last changed: 07/25/2026 by: Claude
// (07/25) Moved out of PresetEditorView, where it was private, so the premade-workout
// detail screen can offer the same picker instead of duplicating it. Body unchanged.
struct IconGrid: View {
    @Binding var selected: String
    let accent: Color

    private let columns = [GridItem(.adaptive(minimum: 48), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(PresetIcons.all, id: \.self) { name in
                PresetIconView(name: name, size: 26)
                    .frame(width: 48, height: 48)
                    .foregroundStyle(selected == name ? accent : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selected == name ? accent.opacity(0.2) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selected == name ? accent : Color.gray.opacity(0.25),
                                    lineWidth: selected == name ? 2 : 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture { selected = name }
                    .accessibilityLabel(name)
            }
        }
        .padding(.vertical, 4)
    }
}
