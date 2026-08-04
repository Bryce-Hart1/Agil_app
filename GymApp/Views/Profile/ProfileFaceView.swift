import SwiftUI

// Claude  Date 08/02/2026
// The ONE place that decides what a person's face looks like. Three possibilities, in
// precedence order:
//
//   1. a customizable character   — the user built one and left characters on
//   2. a stock Avatar             — characters turned off, falling back to the old catalogue
//   3. initials                   — nothing to draw, chiefly a friend whose character hasn't
//                                   reached this device (SharedCard.character is nil)
//
// Centralising this is the point. Before it existed the initials fallback was copy-pasted
// byte-for-byte into ProfileShowcaseCard and RankRingLabView, and every new surface had to
// re-derive the same three-way choice; now a new surface asks ProfileFaceView and is
// automatically correct. RankRingInitials stays the terminal fallback — every path still
// ends there.
//
// The parameter list matches AvatarView's on purpose so this substitutes for it directly.
struct ProfileFaceView: View {
    var character: UserCharacter? = nil
    var avatarID: String? = nil
    /// Only used by the initials fallback.
    var name: String = ""
    var size: CGFloat = 92
    /// Passed through to the character; the backing disc behind a transparent backdrop.
    var showsDisc: Bool = true
    var tint: Color = .white
    var discColor: Color = Color.white.opacity(0.15)
    var ringColor: Color = Color.white.opacity(0.35)

    var body: some View {
        if let character, character.isEnabled {
            CharacterView(character: character, size: size, showsDisc: showsDisc,
                          discColor: discColor, ringColor: ringColor)
        } else if let avatarID {
            AvatarView(avatar: Avatar.avatar(for: avatarID), size: size, tint: tint,
                       discColor: discColor, ringColor: ringColor)
        } else {
            ZStack {
                Circle().fill(discColor)
                RankRingInitials(name: name, size: size)
            }
            .frame(width: size, height: size)
        }
    }
}

// Claude  Date 08/02/2026
// The whole precedence chain at the two sizes that matter most — 65 (inside the profile
// card's rank ring) and 38 (a friend row). If all six of these read, every surface does.
#Preview("Face — fallbacks") {
    VStack(spacing: 24) {
        ForEach([CGFloat(65), CGFloat(38)], id: \.self) { size in
            HStack(spacing: 20) {
                VStack(spacing: 6) {
                    ProfileFaceView(character: .default, avatarID: "classic",
                                    name: "Bryce Hart", size: size)
                    Text("character").font(.caption2).foregroundStyle(.white.opacity(0.7))
                }
                VStack(spacing: 6) {
                    ProfileFaceView(character: UserCharacter(isEnabled: false), avatarID: "blaze",
                                    name: "Bryce Hart", size: size)
                    Text("avatar").font(.caption2).foregroundStyle(.white.opacity(0.7))
                }
                VStack(spacing: 6) {
                    ProfileFaceView(name: "Bryce Hart", size: size)
                    Text("initials").font(.caption2).foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
