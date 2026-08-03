import SwiftUI

// Claude  Date 08/02/2026
// Everything pickable about a character: the style options per slot and the colour
// swatches per role. Deliberately mirrors CardStyle / Avatar — a static catalogue of value
// types with stable ids — so it reuses the same economy (prices here, ownership in
// ThemeManager) and the same "drop art in, append one line" workflow.
//
// ⚠️ `CharacterOption.id` and `CharacterSwatch.id` are PERSISTED (UserProfile.character)
// and SYNCED (SharedCard.character). Renaming one silently resets that pick to the slot
// default on every device. Retiring art is fine — the fallback in
// UserCharacter.option(for:) handles an unknown id — but reusing an old id for different
// art is not.

// Claude  Date 08/02/2026
// How a layer's artwork takes colour. Most layers are single-colour silhouettes tinted at
// runtime, which is what keeps the asset count at one-per-STYLE instead of styles × colours.
// `.fullColor` exists for the layers that can't be: eyes need a white sclera and a dark
// iris in the same image. Shipping the case now — even though every launch option is
// `.role` — means the first real eye artwork doesn't force a compositor rewrite.
enum CharacterTinting: String, Codable, Hashable {
    case role
    case fullColor
}

// Claude  Date 08/02/2026
// Which code-drawn shape stands in for a layer until real art is imported. See
// CharacterPlaceholderShapes.swift for the geometry; the split exists so the model layer
// names the art without owning any drawing.
enum CharacterPlaceholder: String, Hashable, CaseIterable {
    case backdropDisc
    case hairBackTuck, hairBackPonytail, hairBackLong
    case bodyShoulders
    case topTee, topTank, topHoodie
    case headRound, headOval, headAngular
    case faceNeutral, faceSmile, faceFocused
    case facialHairStubble, facialHairBeard
    case hairCrop, hairSwoop, hairPonytail, hairLong
    case accessoryGlasses, accessoryHeadband
}

// Claude  Date 08/02/2026
// One pickable style. `layers` is what lets a single user-facing choice span two depths —
// a hairstyle supplies both the piece behind the skull and the piece in front of it, a face
// shape brings its own matching shoulders — without the user ever having to keep two picks
// in agreement. An EMPTY `layers` is how "None" works: nothing to draw.
struct CharacterOption: Identifiable, Hashable {
    let id: String
    let name: String
    let slot: CharacterSlot
    /// Asset-name suffix, e.g. "swoop" -> char_hair_swoop + char_hairBack_swoop.
    let suffix: String
    let price: Int
    let tinting: CharacterTinting
    let layers: [CharacterLayer: CharacterPlaceholder]

    init(id: String, name: String, slot: CharacterSlot, suffix: String,
         price: Int = 0, tinting: CharacterTinting = .role,
         layers: [CharacterLayer: CharacterPlaceholder]) {
        self.id = id
        self.name = name
        self.slot = slot
        self.suffix = suffix
        self.price = price
        self.tinting = tinting
        self.layers = layers
    }

    // Claude  Date 08/02/2026
    // The imageset this option draws into a given layer. One silhouette per style per
    // layer, tinted at runtime — so the catalogue grows by STYLES, never styles × colours.
    // Import it exactly like badge_forkKnife.imageset (preserves-vector-representation +
    // template-rendering-intent) and it replaces the placeholder with no code change.
    // House gotcha: the imageset NAME is what matters, not the SVG's filename.
    func assetName(for layer: CharacterLayer) -> String {
        "char_\(layer.rawValue)_\(suffix)"
    }
}

/// One colour choice for a role. `hex` is the value; `id` is what gets persisted.
struct CharacterSwatch: Identifiable, Hashable {
    let id: String
    let name: String
    let hex: String
}

enum CharacterCatalog {

    // MARK: - Options
    //
    // Claude  Date 08/02/2026
    // ORDER MATTERS: the first option for a slot is that slot's default (see
    // defaultOption(for:)), so "None" leads the optional slots and a sensible starting
    // look leads the rest.
    static let options: [CharacterOption] = [
        // Backdrop — the disc behind the character.
        CharacterOption(id: "backdrop_plain", name: "Solid", slot: .backdrop, suffix: "plain",
                        layers: [.backdrop: .backdropDisc]),
        CharacterOption(id: "backdrop_none", name: "None", slot: .backdrop, suffix: "none",
                        layers: [:]),

        // Face shape — also supplies the matching neck/shoulders.
        CharacterOption(id: "head_round", name: "Round", slot: .head, suffix: "round",
                        layers: [.head: .headRound, .body: .bodyShoulders]),
        CharacterOption(id: "head_oval", name: "Oval", slot: .head, suffix: "oval",
                        layers: [.head: .headOval, .body: .bodyShoulders]),
        CharacterOption(id: "head_angular", name: "Angular", slot: .head, suffix: "angular",
                        layers: [.head: .headAngular, .body: .bodyShoulders]),

        // Hair — each style supplies both the behind-the-skull and in-front pieces.
        CharacterOption(id: "hair_crop", name: "Crop", slot: .hair, suffix: "crop",
                        layers: [.hair: .hairCrop, .hairBack: .hairBackTuck]),
        CharacterOption(id: "hair_swoop", name: "Swoop", slot: .hair, suffix: "swoop",
                        layers: [.hair: .hairSwoop, .hairBack: .hairBackTuck]),
        CharacterOption(id: "hair_ponytail", name: "Ponytail", slot: .hair, suffix: "ponytail",
                        layers: [.hair: .hairPonytail, .hairBack: .hairBackPonytail]),
        CharacterOption(id: "hair_long", name: "Long", slot: .hair, suffix: "long",
                        layers: [.hair: .hairLong, .hairBack: .hairBackLong]),
        CharacterOption(id: "hair_none", name: "None", slot: .hair, suffix: "none",
                        layers: [:]),

        // Expression.
        CharacterOption(id: "face_neutral", name: "Neutral", slot: .face, suffix: "neutral",
                        layers: [.face: .faceNeutral]),
        CharacterOption(id: "face_smile", name: "Smile", slot: .face, suffix: "smile",
                        layers: [.face: .faceSmile]),
        CharacterOption(id: "face_focused", name: "Focused", slot: .face, suffix: "focused",
                        layers: [.face: .faceFocused]),

        // Facial hair — optional, so "None" leads.
        CharacterOption(id: "facial_none", name: "None", slot: .facialHair, suffix: "none",
                        layers: [:]),
        CharacterOption(id: "facial_stubble", name: "Stubble", slot: .facialHair, suffix: "stubble",
                        layers: [.facialHair: .facialHairStubble]),
        CharacterOption(id: "facial_beard", name: "Beard", slot: .facialHair, suffix: "beard",
                        layers: [.facialHair: .facialHairBeard]),

        // Top.
        CharacterOption(id: "top_tee", name: "Tee", slot: .top, suffix: "tee",
                        layers: [.top: .topTee]),
        CharacterOption(id: "top_tank", name: "Tank", slot: .top, suffix: "tank",
                        layers: [.top: .topTank]),
        CharacterOption(id: "top_hoodie", name: "Hoodie", slot: .top, suffix: "hoodie",
                        layers: [.top: .topHoodie]),

        // Accessory — optional, so "None" leads.
        CharacterOption(id: "accessory_none", name: "None", slot: .accessory, suffix: "none",
                        layers: [:]),
        CharacterOption(id: "accessory_glasses", name: "Glasses", slot: .accessory, suffix: "glasses",
                        layers: [.accessory: .accessoryGlasses]),
        CharacterOption(id: "accessory_headband", name: "Headband", slot: .accessory, suffix: "headband",
                        layers: [.accessory: .accessoryHeadband]),
    ]

    static func options(for slot: CharacterSlot) -> [CharacterOption] {
        options.filter { $0.slot == slot }
    }

    static func option(id: String) -> CharacterOption? {
        options.first { $0.id == id }
    }

    // Claude  Date 08/02/2026
    // The slot's default = its first catalogue entry. The `??` is a genuine safety net
    // rather than ceremony: it keeps a slot with no options (mid-refactor, or art pulled)
    // rendering an empty layer instead of trapping.
    static func defaultOption(for slot: CharacterSlot) -> CharacterOption {
        options(for: slot).first
            ?? CharacterOption(id: "\(slot.rawValue)_empty", name: "None",
                               slot: slot, suffix: "none", layers: [:])
    }

    // MARK: - Colour swatches

    static let skinSwatches: [CharacterSwatch] = [
        CharacterSwatch(id: "skin_01", name: "Porcelain", hex: "#F6D7C4"),
        CharacterSwatch(id: "skin_02", name: "Sand",      hex: "#EFC3A4"),
        CharacterSwatch(id: "skin_03", name: "Honey",     hex: "#DFA779"),
        CharacterSwatch(id: "skin_04", name: "Amber",     hex: "#C08552"),
        CharacterSwatch(id: "skin_05", name: "Umber",     hex: "#8D5524"),
        CharacterSwatch(id: "skin_06", name: "Espresso",  hex: "#5C3317"),
    ]

    static let hairSwatches: [CharacterSwatch] = [
        CharacterSwatch(id: "hair_01", name: "Chestnut",  hex: "#6E4630"),
        CharacterSwatch(id: "hair_02", name: "Ash",       hex: "#A8896B"),
        CharacterSwatch(id: "hair_03", name: "Espresso",  hex: "#3B2A21"),
        CharacterSwatch(id: "hair_04", name: "Jet",       hex: "#1F1B1B"),
        CharacterSwatch(id: "hair_05", name: "Gold",      hex: "#E0B441"),
        CharacterSwatch(id: "hair_06", name: "Platinum",  hex: "#F2E2B6"),
    ]

    static let topSwatches: [CharacterSwatch] = [
        CharacterSwatch(id: "top_01", name: "Forest", hex: "#2E7D5B"),
        CharacterSwatch(id: "top_02", name: "Ink",    hex: "#2B2B33"),
        CharacterSwatch(id: "top_03", name: "Slate",  hex: "#4A5A6A"),
        CharacterSwatch(id: "top_04", name: "Clay",   hex: "#C4573F"),
        CharacterSwatch(id: "top_05", name: "Denim",  hex: "#33628F"),
        CharacterSwatch(id: "top_06", name: "Plum",   hex: "#6B4A7A"),
    ]

    static let accessorySwatches: [CharacterSwatch] = [
        CharacterSwatch(id: "acc_01", name: "Ink",   hex: "#2B2B33"),
        CharacterSwatch(id: "acc_02", name: "Gold",  hex: "#D8A93F"),
        CharacterSwatch(id: "acc_03", name: "Rose",  hex: "#D98A9A"),
        CharacterSwatch(id: "acc_04", name: "Steel", hex: "#8A939E"),
    ]

    static let backdropSwatches: [CharacterSwatch] = [
        CharacterSwatch(id: "bg_01", name: "Mist", hex: "#E9EDF2"),
        CharacterSwatch(id: "bg_02", name: "Sky",  hex: "#BFD9E8"),
        CharacterSwatch(id: "bg_03", name: "Sage", hex: "#CBDCC7"),
        CharacterSwatch(id: "bg_04", name: "Dusk", hex: "#3A3F4B"),
    ]

    /// The one non-pickable role: line work, eyes, brows, mouth.
    static let inkHex = "#2A2530"

    static func swatches(for role: CharacterColorRole) -> [CharacterSwatch] {
        switch role {
        case .skin:      return skinSwatches
        case .hair:      return hairSwatches
        case .top:       return topSwatches
        case .accessory: return accessorySwatches
        case .backdrop:  return backdropSwatches
        case .ink:       return []
        }
    }

    static func defaultToken(for role: CharacterColorRole) -> String {
        swatches(for: role).first?.id ?? inkHex
    }

    // MARK: - Token resolution

    // Claude  Date 08/02/2026
    // A colour token is ONE string with two meanings, told apart by a leading "#": a
    // catalogue swatch id ("skin_03") or a literal hex the user mixed themselves.
    // That's what lets the curated swatches stay small and stable on the wire while a full
    // ColorPicker costs zero model changes — the difference between "a few options" and
    // actual control. Unknown tokens fall back to the role's default swatch, so retiring a
    // swatch degrades to a sensible colour rather than to nothing.
    static func hex(token: String, role: CharacterColorRole) -> String {
        if token.hasPrefix("#") { return token }
        if let swatch = swatches(for: role).first(where: { $0.id == token }) { return swatch.hex }
        if role == .ink { return inkHex }
        return swatches(for: role).first?.hex ?? inkHex
    }

    static func color(token: String, role: CharacterColorRole) -> Color {
        Color(hex: hex(token: token, role: role))
    }
}

// Claude  Date 08/02/2026
// The resolved-colour accessor lives here rather than on UserCharacter so the saved value
// stays Foundation-only (it has to encode into SharedCard, which the sync layer handles
// without any view code in scope). Callers just ask the character for a role's colour.
extension UserCharacter {
    func color(for role: CharacterColorRole) -> Color {
        CharacterCatalog.color(token: token(for: role), role: role)
    }
}
