import SwiftUI

// Claude  Date 06/12/2026
// Customize the profile card. First pass: name + card color, with a live preview.
// Trait selection and card style/templates come in a later refinement.
struct EditProfileCardView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    private var stats: ProfileStats {
        ProfileStats(workouts: store.workouts, exercises: store.exercises)
    }

    private var cardColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: store.profile.cardColorHex) },
            set: { store.profile.cardColorHex = $0.toHex() }
        )
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("First name", text: $store.profile.displayName)
                    .textInputAutocapitalization(.words)
            }

            Section("Card color") {
                ColorPicker("Color", selection: cardColorBinding, supportsOpacity: false)
            }

            Section("Preview") {
                ProfileShowcaseCard(
                    name: store.profile.resolvedName,
                    cardColor: Color(hex: store.profile.cardColorHex),
                    traits: ProfileTrait.showcase(from: stats),
                    memberSince: stats.memberSince
                )
                .frame(height: 420)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                Text("Choosing which traits to show and the card style are coming soon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Edit Profile Card")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
    }
}

#Preview {
    NavigationStack {
        EditProfileCardView()
            .environmentObject(AppStore())
            .environmentObject(ThemeManager())
    }
}
