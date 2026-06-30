import SwiftUI

// Claude  Date 06/30/2026
// Renders a preset's icon from its stored name, dispatching between an SF Symbol
// (Image(systemName:)) and a custom PNG asset (Image(_:)) via PresetIcons.isCustomAsset.
// One place so every preset-icon site — the picker grid, the list row, the "From Preset"
// menu — handles both kinds identically. Both are sized to `size` and tint to the caller's
// foregroundStyle (the custom PNGs are template-rendered, so they colour like the symbols).
struct PresetIconView: View {
    let name: String
    var size: CGFloat = 24

    var body: some View {
        Group {
            if PresetIcons.isCustomAsset(name) {
                Image(name).resizable().scaledToFit()
            } else {
                Image(systemName: name).resizable().scaledToFit()
            }
        }
        .frame(width: size, height: size)
    }
}
