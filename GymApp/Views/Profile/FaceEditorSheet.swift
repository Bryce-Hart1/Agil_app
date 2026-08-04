import SwiftUI

// Claude  Date 06/12/2026 last changed: 08/03/2026 by: Claude
// The face editor as a bottom sheet, raised by tapping the face on the live profile card —
// the tap-to-edit paradigm this screen was rebuilt around on 07/22. (08/03: the rank title
// used to raise it too, which put a second, redundant pencil on the card. It doesn't now.)
//
// (Was AvatarPickerSheet, a strip of stock avatars plus the rank toggle.) The editor itself
// now lives in CharacterCustomizerView, because Edit Profile Card also hosts it inline as
// its Character tab. This file is deliberately only the sheet chrome — navigation stack,
// title, Done — so the two entry points can never drift apart.
struct FaceEditorSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CharacterCustomizerView()
                .navigationTitle(store.profile.character.isEnabled ? "Your Character" : "Your Avatar")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - Avatar cell

// Claude  Date 06/30/2026 last changed: 08/02/2026 by: Claude
// One avatar in the horizontal picker: the avatar art in a ring (accent when selected),
// its name, and a state line below — selected, "Owned", or a coin price to buy. Tapping
// an owned/free avatar equips it; a locked one triggers the buy alert.
// (Moved here out of EditProfileCardView when the sheet split out; unchanged otherwise.)
struct AvatarPickCell: View {
    let avatar: Avatar
    let accent: Color
    let isSelected: Bool
    let isUnlocked: Bool
    let canAfford: Bool
    let onSelect: () -> Void
    let onBuy: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            AvatarView(avatar: avatar, size: 60, tint: accent,
                       discColor: Color.gray.opacity(0.15),
                       ringColor: isSelected ? accent : Color.gray.opacity(0.3))
                .overlay(alignment: .bottomTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(accent)
                            .background(Circle().fill(.background))
                    }
                }

            Text(avatar.name).font(.caption).lineLimit(1)

            trailing
                .font(.caption2)
                .frame(height: 16)
        }
        .frame(width: 72)
        .contentShape(Rectangle())
        .onTapGesture { if isUnlocked { onSelect() } else { onBuy() } }
    }

    @ViewBuilder private var trailing: some View {
        if isSelected {
            Text("Equipped").foregroundStyle(.secondary)
        } else if isUnlocked {
            Text("Owned").foregroundStyle(.secondary)
        } else {
            Label("\(avatar.price)", systemImage: "circle.hexagongrid.fill")
                .foregroundStyle(canAfford ? accent : .secondary)
                .opacity(canAfford ? 1 : 0.6)
        }
    }
}

#Preview {
    FaceEditorSheet()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
