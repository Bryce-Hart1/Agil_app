import SwiftUI

extension View {
    /// Applies the theme's background and card colors to a `List` or `Form`.
    /// Hides the default system grouped background so the theme shows through,
    /// and tints all rows with the theme's surface color.
    func themed(_ theme: AppTheme) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
            .listRowBackground(theme.surface)
    }

    // Claude  Date 07/16/2026
    // Menu-style Pickers are UIKit-backed and resolve the .tint in effect when
    // they're first created — after a theme swap, any picker that was already
    // alive keeps the old accent baked into its value label (e.g. a pink "3:00"
    // rest picker on a teal theme). Re-keying the picker's identity to the
    // active palette forces SwiftUI to recreate the control so it re-reads the
    // new tint. `salt` keeps sibling pickers (and per-row copies) distinct.
    func retintOnThemeChange(_ theme: AppTheme, salt: String = "") -> some View {
        id("retint|\(salt)|\(theme.id)|\(theme.accentHex)|\(theme.darkAccentHex ?? "")")
    }
}
