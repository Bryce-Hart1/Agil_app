import SwiftUI

// Claude  Date 08/02/2026
// A person's face at list-row scale — the friend row today, and the drop-in for a message
// thread whenever chat gets built. It is deliberately the DUMBEST view in the feature, and
// the two properties that make it dumb are the two that make it reusable:
//
//   1. It reads NOTHING from the environment. No @EnvironmentObject, no AppStore. A chat row
//      constructs it straight from a SharedCard, in a file that has never heard of the store.
//   2. It has a FIXED SQUARE FRAME and no intrinsic growth. Whatever ends up inside it, it
//      can never push a message row's height around.
//
// Everything about which face to draw is ProfileFaceView's problem, so this stays correct as
// that precedence evolves.
struct CharacterBubbleView: View {
    var character: UserCharacter? = nil
    var avatarID: String? = nil
    var name: String = ""
    var size: CGFloat = 36
    /// Off by default: a list row wants a flat disc, not the card's white rim.
    var showsRing: Bool = false

    var body: some View {
        ProfileFaceView(
            character: character,
            avatarID: avatarID,
            name: name,
            size: size,
            discColor: Color.secondary.opacity(0.2),
            ringColor: showsRing ? Color.white.opacity(0.35) : .clear
        )
        .frame(width: size, height: size)
    }
}

// Claude  Date 08/02/2026
// The one-liner a row actually wants. Note there's no avatarID: SharedCard never carries one
// (privacy contract), so a friend without a character correctly lands on initials.
extension CharacterBubbleView {
    init(card: SharedCard, size: CGFloat = 36) {
        self.init(character: card.character, avatarID: nil,
                  name: card.displayName, size: size)
    }
}

#Preview("Bubble — row sizes") {
    VStack(alignment: .leading, spacing: 16) {
        ForEach([CGFloat(28), CGFloat(36), CGFloat(38), CGFloat(44)], id: \.self) { size in
            HStack(spacing: 12) {
                CharacterBubbleView(character: .default, name: "Bryce Hart", size: size)
                CharacterBubbleView(character: .random(), name: "Ada L", size: size)
                CharacterBubbleView(name: "Grace Hopper", size: size)
                Text("\(Int(size))pt").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    .padding()
}
