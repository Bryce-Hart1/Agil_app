import SwiftUI

/// App settings. Pushed from the Profile tab, so it does not host its own
/// navigation stack.
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        List {
            Section("Appearance") {
                NavigationLink {
                    ThemeSettingsView()
                } label: {
                    HStack {
                        Label("Theme", systemImage: "paintpalette")
                        Spacer()
                        Text(theme.current.name).foregroundStyle(.secondary)
                    }
                }
            }
            Section("About") {
                LabeledContent("App", value: "gym_app")
                LabeledContent("Version", value: "0.1.0")
            }
            Section("Stored data") {
                LabeledContent("Exercises", value: "\(store.exercises.count)")
                LabeledContent("Workouts", value: "\(store.workouts.count)")
                LabeledContent("Presets", value: "\(store.presets.count)")
            }
        }
        .navigationTitle("Settings")
        .themed(theme.current)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppStore())
            .environmentObject(ThemeManager())
    }
}
