import SwiftUI

/// Minimal settings for Phase 0: app info and a live count of stored data,
/// which doubles as a quick check that persistence is working.
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        NavigationStack {
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
                }
            }
            .navigationTitle("Settings")
            .themed(theme.current)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
