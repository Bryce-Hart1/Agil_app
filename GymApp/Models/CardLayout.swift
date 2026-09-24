import SwiftUI

// CLAUDE  Date 09/24/2026
// Everything about the card's arrangement that isn't its background or content: which
// header shows, what sits in the avatar disc, how rank progress is drawn, and the ink
// colour for all text. Stored on UserProfile and synced to friends via SharedCard.
struct CardLayout: Hashable {
    var header: CardHeaderMode = .logoAndName
    var avatar: CardAvatar = .rank
    var progress: CardProgressStyle = .ring
    var ink: CardInk = .white

    static let `default` = CardLayout()

    // A ring needs a picture to frame, so with no avatar a ring reads as a bar.
    var resolvedProgress: CardProgressStyle {
        avatar == .none && progress == .ring ? .bar : progress
    }

    // CLAUDE  Date 09/24/2026
    // Picking "no picture" while the ring is on would leave nothing to draw it around,
    // so the choice carries progress over to the bar rather than silently hiding it.
    mutating func setAvatar(_ newValue: CardAvatar) {
        avatar = newValue
        if newValue == .none && progress == .ring { progress = .bar }
    }
}

// CLAUDE  Date 09/24/2026
// Tolerant coding: every field travels as a plain string and anything unknown (a newer
// build's avatar, a typo from the backend) falls back to its default instead of throwing.
// A throw here would reset the whole saved profile, or drop a friend's entire card.
extension CardLayout: Codable {
    private enum CodingKeys: String, CodingKey { case header, avatar, progress, ink }

    init(from decoder: Decoder) throws {
        // Not even an object (a bad backend echo) → the default, not a failed friend card.
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = .default
            return
        }
        func string(_ key: CodingKeys) -> String? { try? c.decodeIfPresent(String.self, forKey: key) }
        header = string(.header).flatMap(CardHeaderMode.init(rawValue:)) ?? .logoAndName
        avatar = string(.avatar).flatMap(CardAvatar.init(id:)) ?? .rank
        progress = string(.progress).flatMap(CardProgressStyle.init(rawValue:)) ?? .ring
        ink = string(.ink).flatMap(CardInk.init(rawValue:)) ?? .white
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(header.rawValue, forKey: .header)
        try c.encode(avatar.id, forKey: .avatar)
        try c.encode(progress.rawValue, forKey: .progress)
        try c.encode(ink.rawValue, forKey: .ink)
    }
}

// The AGIL mark row at the top of both faces.
enum CardHeaderMode: String, CaseIterable, Identifiable, Hashable {
    case logoAndName, logoOnly, nameOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .logoAndName: return "Logo and name"
        case .logoOnly:    return "Logo only"
        case .nameOnly:    return "Name only"
        }
    }

    var showsLogo: Bool { self != .nameOnly }
    var showsName: Bool { self != .logoOnly }
}

// CLAUDE  Date 09/24/2026
// What fills the avatar disc: the earned rank piece, one of the AGIL icons, or nothing
// (the card leads with the name). Coded as one string — "rank", "none", or an icon id.
enum CardAvatar: Hashable, Identifiable {
    case rank
    case icon(ProfileIcon)
    case none

    static let allCases: [CardAvatar] = [.rank] + ProfileIcon.allCases.map { .icon($0) } + [.none]

    init?(id: String) {
        switch id {
        case "rank": self = .rank
        case "none": self = .none
        default:
            guard let icon = ProfileIcon(rawValue: id) else { return nil }
            self = .icon(icon)
        }
    }

    var id: String {
        switch self {
        case .rank:           return "rank"
        case .none:           return "none"
        case .icon(let icon): return icon.rawValue
        }
    }
}

// How rank progress is drawn around/under the avatar.
enum CardProgressStyle: String, CaseIterable, Identifiable, Hashable {
    case ring, bar, off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ring: return "Ring"
        case .bar:  return "Bar"
        case .off:  return "Off"
        }
    }
}

// The colour of every piece of text (and the faint fills behind it) on the card.
enum CardInk: String, CaseIterable, Identifiable, Hashable {
    case white, black

    var id: String { rawValue }

    var title: String {
        switch self {
        case .white: return "White"
        case .black: return "Black"
        }
    }

    var color: Color {
        switch self {
        case .white: return .white
        case .black: return .black
        }
    }
}
