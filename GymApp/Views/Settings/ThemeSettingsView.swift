import SwiftUI

// Claude  Date 06/13/2026 last changed: 06/13/2026 by: Claude
/// Lists the themes you currently own for quick selection. Buying new themes
/// now happens in the Shop (Profile → Shop), and custom themes are disabled for
/// now — so this shows only unlocked presets. (ThemeEditorView is kept in the
/// project for when custom themes return.)
struct ThemeSettingsView: View {
    @EnvironmentObject private var theme: ThemeManager

    // Claude  Date 06/13/2026
    // Only themes the user has unlocked are selectable here; locked ones live in the Shop.
    private var ownedPresets: [AppTheme] {
        AppTheme.builtIns.filter { theme.isUnlocked($0) }
    }

    var body: some View {
        List {
            Section {
                ForEach(ownedPresets) { preset in
                    ThemeRow(theme: preset, isSelected: preset.id == theme.selectedID) {
                        theme.select(preset)
                    }
                }
            } header: {
                Text("Your Themes")
            } footer: {
                // CLAUDE  Date 09/03/2026 — say that the icon comes with the theme.
                Text("Each theme comes with its own app icon. Find more in the Shop.")
            }
        }
        .navigationTitle("Theme")
        .themed(theme.current)
    }
}

/// A selectable theme row with a name, color swatches, and a checkmark.
private struct ThemeRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // CLAUDE  Date 09/03/2026
                // The theme's app icon, not an abstract colour swatch — a theme now carries
                // its icon too, and this is the row you equip it from. The accent dot stays
                // as a small overlay so the palette is still readable at a glance.
                AgilLogoMark(theme: theme, size: 34, cornerRadius: 8)
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.background, lineWidth: 1.5))
                            .offset(x: 3, y: 3)
                    }

                Text(theme.name).foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(theme.accent).fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { ThemeSettingsView() }
        .environmentObject(ThemeManager())
}
