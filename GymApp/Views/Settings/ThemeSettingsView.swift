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
                Text("Unlock more themes in the Shop (Profile → Shop).")
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
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.background)
                    Circle().fill(theme.accent).frame(width: 16, height: 16)
                }
                .frame(width: 34, height: 34)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

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
