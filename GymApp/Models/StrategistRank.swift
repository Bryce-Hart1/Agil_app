import SwiftUI

// Claude  Date 06/15/2026 last changed: 06/18/2026 by: Claude
// The "Strategist" rank — a single overall standing that climbs a warrior
// hierarchy as the user accumulates achievements. It's a separate axis from the
// per-badge tiers: rank = your overall ranking, tier = an individual badge's
// level. The seven ranks map 1:1 onto the seven BadgeTier colors, so a rank-up
// visibly changes the emblem's color. (The emblem ART is still the original chess
// glyphs for now — to be replaced with warrior art later; the top two ranks share
// the king glyph until then.) Int-backed, so renaming cases keeps saved rawValues.
enum StrategistRank: Int, CaseIterable, Comparable, Codable {
    case initiate, squire, warrior, gladiator, centurion, spartan, legend

    // Tier whose color (and, for the top rank, glimmer) themes this rank's emblem.
    var tier: BadgeTier {
        switch self {
        case .initiate:  return .bronze
        case .squire:    return .silver
        case .warrior:   return .gold
        case .gladiator: return .platinum
        case .centurion: return .diamond
        case .spartan:   return .emerald
        case .legend:    return .legend
        }
    }

    var title: String {
        switch self {
        case .initiate:  return "Initiate"
        case .squire:    return "Squire"
        case .warrior:   return "Warrior"
        case .gladiator: return "Gladiator"
        case .centurion: return "Centurion"
        case .spartan:   return "Spartan"
        case .legend:    return "Legend"
        }
    }

    // Emblem glyph (custom asset name); falls back to `fallbackSymbol` until the art
    // is imported. Still the original chess art for now — Spartan + Legend share the
    // king glyph — pending warrior-themed replacements.
    var iconName: String {
        switch self {
        case .initiate:           return "chess_pawn_0"
        case .squire:             return "chess_bishop_1"
        case .warrior:            return "chess_knight_2"
        case .gladiator:          return "chess_rook_3"
        case .centurion:          return "chess_queen_4"
        case .spartan, .legend:   return "chess_king_5"
        }
    }

    // A valid SF Symbol shown until the custom art is in the asset catalog.
    var fallbackSymbol: String { "crown.fill" }

    // Minimum achievement score (see StrategistScoring) to hold this rank.
    var scoreThreshold: Int {
        switch self {
        case .initiate:  return 0
        case .squire:    return 8
        case .warrior:   return 24
        case .gladiator: return 45
        case .centurion: return 75
        case .spartan:   return 110
        case .legend:    return 150
        }
    }

    static func < (lhs: StrategistRank, rhs: StrategistRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// Claude  Date 06/15/2026 last changed: 07/25/2026 by: Claude
// Pure scoring helpers — no app state, so they're trivially testable. The score
// rewards depth: each unlocked badge is worth (tierRank + 1), i.e. Bronze 1 …
// Legend 7.
// (07/25) maxScore is now DERIVED from the catalog instead of hardcoded at 168.
// That literal was a full 7-tier ladder × 6 categories, and had been wrong since
// the catalog grew to 8 — StrategistRankView shows it as "your score: X / max", so
// the ceiling read low. Deriving it means adding a badge (the First Step secret)
// can't desync it again.
enum StrategistScoring {
    static let maxScore = Achievement.all
        .reduce(0) { $0 + AchievementShowcase.tierRank($1.tier) + 1 }

    // Claude  Date 07/14/2026
    // Stays on Achievement.all (not the gender-calibrated catalog): scoring reads
    // only id + tier, which are identical across catalog variants by invariant.
    static func score(unlockedIDs: Set<String>) -> Int {
        Achievement.all
            .filter { unlockedIDs.contains($0.id) }
            .reduce(0) { $0 + AchievementShowcase.tierRank($1.tier) + 1 }
    }

    static func rank(forScore score: Int) -> StrategistRank {
        StrategistRank.allCases.last { score >= $0.scoreThreshold } ?? .initiate
    }

    static func nextRank(after rank: StrategistRank) -> StrategistRank? {
        StrategistRank(rawValue: rank.rawValue + 1)
    }

    // Progress 0...1 from the current rank's threshold toward the next (1 at top).
    static func progress(forScore score: Int) -> Double {
        let current = rank(forScore: score)
        guard let next = nextRank(after: current) else { return 1 }
        let lo = current.scoreThreshold, hi = next.scoreThreshold
        guard hi > lo else { return 1 }
        return min(1, max(0, Double(score - lo) / Double(hi - lo)))
    }

    // Points remaining to the next rank (0 at the top).
    static func pointsToNext(forScore score: Int) -> Int {
        let current = rank(forScore: score)
        guard let next = nextRank(after: current) else { return 0 }
        return max(0, next.scoreThreshold - score)
    }
}
