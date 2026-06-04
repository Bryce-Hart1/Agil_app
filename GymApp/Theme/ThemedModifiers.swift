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
}
