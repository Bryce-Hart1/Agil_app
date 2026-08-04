import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 08/02/2026
// Memoized asset lookup. The compositor asks "does this layer have real art yet?" once per
// layer per render — nine questions per character — and a friends list or chat thread draws
// twenty of them per scroll frame. UIImage(named:) hits the asset catalogue every time, so
// the answers are cached; the catalogue is baked into the bundle and cannot change at
// runtime, which is what makes caching safe rather than merely fast.
//
// @MainActor because it's only ever touched from a SwiftUI body, and that keeps the mutable
// static honest.
@MainActor
enum CharacterAssets {
    private static var cache: [String: Bool] = [:]

    static func exists(_ name: String) -> Bool {
        if let known = cache[name] { return known }
        #if canImport(UIKit)
        let found = UIImage(named: name) != nil
        #else
        let found = false
        #endif
        cache[name] = found
        return found
    }
}

// Claude  Date 08/02/2026
// The compositor: stacks a character's layers back-to-front and tints each with its colour
// role. Per layer it takes real artwork when the imageset exists and the code-drawn
// placeholder otherwise — the same asset-or-fallback trick as BadgeView, StrategistEmblem
// and AvatarView, but PER LAYER, so art can land one piece at a time instead of all at once.
//
// The signature deliberately mirrors AvatarView (size / discColor / ringColor / shadow) so
// this is a literal drop-in everywhere an avatar is drawn today, including inside RankRing.
struct CharacterView: View {
    let character: UserCharacter
    var size: CGFloat = 92
    /// The backing disc behind the character. The character's own `backdrop` layer usually
    /// covers it; turn it off where something else already provides the ground.
    var showsDisc: Bool = true
    var discColor: Color = Color.white.opacity(0.15)
    var ringColor: Color = Color.white.opacity(0.35)

    private var ink: Color { character.color(for: .ink) }

    // Claude  Date 08/03/2026
    // The face shape, read off the head slot's own placeholder rather than off the option
    // id, so a renamed option can't silently drop it back to `.round`. Facial hair is
    // clipped to this, which is what lets a beard hug an angular jaw instead of a round one.
    private var headStyle: CharacterHeadShape.Style {
        switch character.option(for: .head).layers[.head] {
        case .headOval:    return .oval
        case .headAngular: return .angular
        default:           return .round
        }
    }

    var body: some View {
        ZStack {
            if showsDisc { Circle().fill(discColor) }
            // CharacterLayer.allCases IS the z-order — see the warning on that enum.
            ForEach(CharacterLayer.allCases) { layer in
                layerView(layer)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(ringColor, lineWidth: max(1, size * 0.022)))
        .shadow(radius: size * 0.06, y: size * 0.03)
    }

    // Claude  Date 08/02/2026
    // One layer. An option that doesn't contribute geometry to this layer draws nothing —
    // that's how every "None" choice works, with no special-casing anywhere.
    @ViewBuilder private func layerView(_ layer: CharacterLayer) -> some View {
        let option = character.option(for: layer.slot)
        if let placeholder = option.layers[layer] {
            let color = character.color(for: layer.colorRole)
            let asset = option.assetName(for: layer)
            if CharacterAssets.exists(asset) {
                // Silhouette art is tinted at runtime (.template); multi-tone art that
                // can't be reduced to one colour ships as authored (.fullColor).
                Image(asset)
                    .renderingMode(option.tinting == .fullColor ? .original : .template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color)
            } else {
                CharacterPlaceholderLayer(placeholder: placeholder, color: color,
                                          ink: ink, size: size, headStyle: headStyle)
            }
        }
    }
}

// MARK: - Previews

// Claude  Date 08/02/2026
// The load-bearing preview. Every size here is one the app actually renders at: 28 in a
// future chat row, 38 in a friend row, 60 on the rank banner's reverse face, 65 inside the
// profile card's rank ring (RingGeometry.coreDiameter(for: 120) — the card is NOT 120), 72
// on an editor tile, 92 on a card with the rank off, 120 in the editor preview.
// If the character reads at 65 and survives 28, it works everywhere.
#Preview("Character — sizes") {
    let sizes: [CGFloat] = [28, 36, 38, 44, 60, 65, 72, 92, 120]
    return ScrollView {
        VStack(spacing: 28) {
            ForEach([Color.black, Color(.systemBackground)], id: \.self) { bg in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(sizes, id: \.self) { s in
                            VStack(spacing: 4) {
                                CharacterView(character: .default, size: s)
                                Text("\(Int(s))").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(bg)
                }
            }
        }
        .padding(.vertical, 20)
    }
}

// Claude  Date 08/02/2026
// Every option in every slot, drawn as a whole character with just that slot swapped —
// the same trick the editor's grid uses, so this preview also validates those tiles.
#Preview("Character — all options") {
    ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(CharacterSlot.allCases) { slot in
                VStack(alignment: .leading, spacing: 6) {
                    Text(slot.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ForEach(CharacterCatalog.options(for: slot)) { option in
                            VStack(spacing: 4) {
                                CharacterView(character: UserCharacter.default.setting(option.id, for: slot),
                                              size: 60)
                                Text(option.name).font(.caption2)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
    }
}

// Claude  Date 08/02/2026
// The colour roles crossed against their swatches — catches a skin tone that swallows the
// ink, or a hair colour that vanishes into a backdrop.
#Preview("Character — palettes") {
    ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(CharacterColorRole.allCases.filter(\.isUserPickable)) { role in
                VStack(alignment: .leading, spacing: 6) {
                    Text(role.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ForEach(CharacterCatalog.swatches(for: role)) { swatch in
                            CharacterView(character: UserCharacter.default.setting(token: swatch.id, for: role),
                                          size: 60)
                        }
                    }
                }
            }
            Text("Randomized").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { _ in
                    CharacterView(character: .random(), size: 60)
                }
            }
        }
        .padding(16)
    }
}
