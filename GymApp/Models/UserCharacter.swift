import Foundation

// Claude  Date 08/02/2026
// The user's customizable character — the flat-vector cartoon face that replaces the
// generic flame/trophy/weights avatars. It shows on the profile card, on the reverse
// ("tails") face of the strategist badge, and in friend rows / a future chat thread.
//
// It is stored as OPTION IDS AND COLOUR TOKENS, never as pixels. The renderer
// (CharacterView) turns that into a stack of tinted layers, so one saved value works at
// 28pt in a list row and 120pt in the editor, and survives the art being redrawn from
// scratch. Turning characters off is `isEnabled = false`, which falls back to the old
// Avatar catalogue — see ProfileFaceView, the one place that decision is made.
//
// The model layer is three files:
//   UserCharacter.swift    — this file: the layer/slot/role vocabulary + the saved value
//   CharacterCatalog.swift — the pickable options and the colour swatches
//   Views/Character/       — the compositor and the code-drawn placeholder geometry

// Claude  Date 08/02/2026
// ⚠️ `allCases` ORDER IS THE Z-ORDER, back to front. CharacterView draws the layers in
// exactly this sequence, so REORDERING THESE CASES SILENTLY RESTACKS THE ARTWORK — put
// a new layer where it belongs in depth, not where it reads nicely.
//
// Depth reasoning: the backdrop fills the disc; hair behind the skull sits under the
// body so a ponytail tucks behind the shoulder; the top covers the body; the head sits
// over the neck; the beard, face and front hair paint onto the head in that order; and
// accessories (glasses) go over everything.
//
// Claude 08/03/2026: facialHair moved BELOW face. A full beard's moustache has to reach the
// lip line to read as a beard rather than as a stripe floating on the philtrum, and while
// facial hair drew last that reach cost the near corner of every expression — the mouth was
// simply painted over. Drawing the mouth on top of the beard instead is also what the
// reference art does; the trade is that on the very darkest hair the covered corner of the
// mouth goes low-contrast, which is a far cheaper loss than losing the expression outright.
enum CharacterLayer: String, CaseIterable, Identifiable, Hashable {
    case backdrop, hairBack, body, top, head, facialHair, face, hair, accessory

    var id: String { rawValue }

    // Claude  Date 08/02/2026
    // Which pickable slot supplies this layer's geometry. Mostly 1:1, with two joins that
    // exist because one user-facing choice spans two depths: a hairstyle draws both behind
    // (hairBack) and in front of (hair) the skull, and a head shape brings its own matching
    // neck/shoulders (body). Keeping those as ONE choice each is the whole point — a user
    // picking "Ponytail" should never also have to pick a matching back-of-head.
    var slot: CharacterSlot {
        switch self {
        case .backdrop:          return .backdrop
        case .hairBack, .hair:   return .hair
        case .body, .head:       return .head
        case .top:               return .top
        case .face:              return .face
        case .facialHair:        return .facialHair
        case .accessory:         return .accessory
        }
    }

    // Claude  Date 08/02/2026
    // Which colour this layer tints with. Roles (not per-layer colours) are why picking
    // "hair colour" once tints the back hair, the front hair AND the beard together —
    // per-layer colours would give three hair pickers that can disagree with each other.
    var colorRole: CharacterColorRole {
        switch self {
        case .backdrop:                       return .backdrop
        case .hairBack, .hair, .facialHair:   return .hair
        case .body, .head:                    return .skin
        case .top:                            return .top
        case .face:                           return .ink
        case .accessory:                      return .accessory
        }
    }
}

// Claude  Date 08/02/2026
// What the user actually picks. Deliberately shorter than CharacterLayer — see
// CharacterLayer.slot for the two joins. Codable because the raw values are the keys in
// UserCharacter.optionIDs, so renaming a case orphans saved picks (they'd fall back to the
// slot default). Alpha build with no users, so a rename is currently free.
enum CharacterSlot: String, Codable, CaseIterable, Identifiable, Hashable {
    case backdrop, head, hair, face, facialHair, top, accessory

    var id: String { rawValue }

    /// Shown as the section title in the editor.
    var title: String {
        switch self {
        case .backdrop:   return "Backdrop"
        case .head:       return "Face Shape"
        case .hair:       return "Hair"
        case .face:       return "Expression"
        case .facialHair: return "Facial Hair"
        case .top:        return "Top"
        case .accessory:  return "Accessory"
        }
    }
}

// Claude  Date 08/02/2026
// The tintable colours. `ink` (eyes, brows, mouth, outlines) is deliberately NOT offered
// in the editor — a user-chosen eye colour reads as broken far more often than it reads as
// expressive — but it's a role like any other so the face layer has something to tint with
// and a later "high contrast" option has somewhere to live.
enum CharacterColorRole: String, Codable, CaseIterable, Identifiable, Hashable {
    case skin, hair, top, accessory, backdrop, ink

    var id: String { rawValue }

    /// Whether the editor offers swatches for this role.
    var isUserPickable: Bool { self != .ink }

    var title: String {
        switch self {
        case .skin:      return "Skin"
        case .hair:      return "Hair Colour"
        case .top:       return "Top Colour"
        case .accessory: return "Accessory Colour"
        case .backdrop:  return "Backdrop Colour"
        case .ink:       return "Ink"
        }
    }
}

// Claude  Date 08/02/2026
// The saved character. Two dictionaries rather than a field per slot: adding a slot later
// is then ONE enum case, with no change to Codable, UserProfile, SharedCard or the editor —
// which matters because this is groundwork and the option list is expected to grow.
//
// The trade is real: a bad key fails at runtime as a silent fall-back-to-default rather
// than at compile time. The mitigation is that NOTHING outside this type touches the
// dictionaries — go through option(for:) / color(for:) / set(_:for:) instead.
//
// Hashable is load-bearing, not decoration: UserProfile is Hashable and RootTabView
// watches `.onChange(of: store.profile)` to trigger a card sync.
struct UserCharacter: Codable, Hashable {
    // Claude  Date 08/02/2026
    // The on/off switch, as a flag rather than making the whole character optional on
    // UserProfile. An optional would throw the user's entire configuration away the moment
    // they switched to a classic avatar; this way toggling back is instant and lossless.
    var isEnabled: Bool
    /// CharacterSlot.rawValue -> CharacterOption.id. Missing key = the slot's default.
    private(set) var optionIDs: [String: String]
    /// CharacterColorRole.rawValue -> colour token. Missing key = the role's default.
    private(set) var colorTokens: [String: String]

    init(isEnabled: Bool = true,
         optionIDs: [String: String] = [:],
         colorTokens: [String: String] = [:]) {
        self.isEnabled = isEnabled
        self.optionIDs = optionIDs
        self.colorTokens = colorTokens
    }

    // MARK: - Typed access (the only supported way in)

    /// The chosen option for a slot, falling back to the slot's default when the stored id
    /// is missing, unknown (art retired), or somehow belongs to a different slot.
    func option(for slot: CharacterSlot) -> CharacterOption {
        if let id = optionIDs[slot.rawValue],
           let option = CharacterCatalog.option(id: id),
           option.slot == slot {
            return option
        }
        return CharacterCatalog.defaultOption(for: slot)
    }

    /// The stored colour token for a role (a swatch id like "skin_03", or a literal
    /// "#RRGGBB"), falling back to the role's default swatch.
    func token(for role: CharacterColorRole) -> String {
        colorTokens[role.rawValue] ?? CharacterCatalog.defaultToken(for: role)
    }

    mutating func set(_ optionID: String, for slot: CharacterSlot) {
        optionIDs[slot.rawValue] = optionID
    }

    mutating func set(token: String, for role: CharacterColorRole) {
        colorTokens[role.rawValue] = token
    }

    // Claude  Date 08/02/2026
    // Non-mutating copies. The editor's option grid renders each tile as the WHOLE
    // character with just that one slot swapped — far more legible than a floating
    // disembodied hairstyle — and this is what builds those variants.
    func setting(_ optionID: String, for slot: CharacterSlot) -> UserCharacter {
        var copy = self
        copy.set(optionID, for: slot)
        return copy
    }

    func setting(token: String, for role: CharacterColorRole) -> UserCharacter {
        var copy = self
        copy.set(token: token, for: role)
        return copy
    }

    // MARK: - Presets

    /// A new profile's character: every slot on its catalogue default.
    static var `default`: UserCharacter { UserCharacter() }

    // Claude  Date 08/02/2026
    // A random character. Worth its keep beyond the editor's shuffle button: it's the
    // fastest way to sweep every option/colour combination by hand in the DEBUG lab.
    static func random() -> UserCharacter {
        var character = UserCharacter()
        for slot in CharacterSlot.allCases {
            if let option = CharacterCatalog.options(for: slot).randomElement() {
                character.set(option.id, for: slot)
            }
        }
        for role in CharacterColorRole.allCases where role.isUserPickable {
            if let swatch = CharacterCatalog.swatches(for: role).randomElement() {
                character.set(token: swatch.id, for: role)
            }
        }
        return character
    }
}
