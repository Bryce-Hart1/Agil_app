import SwiftUI

/// Create or edit a custom theme: pick a name, light/dark, and accent /
/// background / card colors, with a live preview. Saving selects the theme.
struct ThemeEditorView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private let base: AppTheme

    @State private var name: String
    @State private var isDark: Bool
    @State private var accent: Color
    @State private var background: Color
    @State private var surface: Color

    init(base: AppTheme) {
        self.base = base
        _name = State(initialValue: base.name)
        _isDark = State(initialValue: base.isDark)
        _accent = State(initialValue: base.accent)
        _background = State(initialValue: base.background)
        _surface = State(initialValue: base.surface)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Theme name", text: $name)
                }
                Section("Appearance") {
                    Toggle("Dark mode", isOn: $isDark)
                    ColorPicker("Accent", selection: $accent, supportsOpacity: false)
                    ColorPicker("Background", selection: $background, supportsOpacity: false)
                    ColorPicker("Cards", selection: $surface, supportsOpacity: false)
                }
                Section("Preview") {
                    PreviewCard(accent: accent, background: background, surface: surface, isDark: isDark)
                        .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle(base.name == "My Theme" ? "New Theme" : "Edit Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let theme = AppTheme(
            id: base.id,
            name: trimmedName,
            isBuiltIn: false,
            isDark: isDark,
            accentHex: accent.toHex(),
            backgroundHex: background.toHex(),
            surfaceHex: surface.toHex()
        )
        themeManager.addOrUpdate(theme)
        themeManager.select(theme)
        dismiss()
    }
}

/// A small mock of the app's UI so color choices can be judged at a glance.
private struct PreviewCard: View {
    let accent: Color
    let background: Color
    let surface: Color
    let isDark: Bool

    private var textColor: Color { isDark ? .white : .black }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bench Press").font(.headline).foregroundStyle(textColor)
            HStack {
                Text("Set 1").foregroundStyle(textColor.opacity(0.6))
                Spacer()
                Text("8 reps × 135 lb").foregroundStyle(textColor)
            }
            .font(.subheadline)
            .padding(10)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button("Add Set") {}
                .buttonStyle(.borderedProminent)
                .tint(accent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
    }
}

#Preview {
    ThemeEditorView(base: AppTheme.classic.asNewTemplate())
        .environmentObject(ThemeManager())
}
