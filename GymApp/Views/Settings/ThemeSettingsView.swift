import SwiftUI

/// Lists preset and custom themes for selection, and lets the user create,
/// edit, or delete custom themes.
struct ThemeSettingsView: View {
    @EnvironmentObject private var theme: ThemeManager

    @State private var editingTheme: AppTheme?
    @State private var creatingTheme: AppTheme?

    var body: some View {
        List {
            Section("Presets") {
                ForEach(AppTheme.builtIns) { preset in
                    ThemeRow(theme: preset, isSelected: preset.id == theme.selectedID) {
                        theme.select(preset)
                    }
                }
            }

            Section("Custom") {
                ForEach(theme.customThemes) { custom in
                    ThemeRow(theme: custom, isSelected: custom.id == theme.selectedID) {
                        theme.select(custom)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            theme.delete(custom)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            editingTheme = custom
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.gray)
                    }
                }

                Button {
                    creatingTheme = theme.current.asNewTemplate()
                } label: {
                    Label("Create Custom Theme", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Theme")
        .themed(theme.current)
        .sheet(item: $editingTheme) { ThemeEditorView(base: $0) }
        .sheet(item: $creatingTheme) { ThemeEditorView(base: $0) }
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
