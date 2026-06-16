import SwiftUI

// Claude  Date 06/15/2026
// The "Strategist" rank — a single overall standing that climbs the chess
// hierarchy as the user accumulates achievements. It's a separate axis from the
// per-badge tiers: rank = your overall ranking, tier = an individual badge's
// level. The seven ranks map 1:1 onto the seven BadgeTier colors, so a rank-up
// visibly changes the emblem's color; the King piece is reused for the top two
// ranks (Emerald King, then Legend King — which inherits the gold glimmer).
enum StrategistRank: Int, CaseIterable, Comparable, Codable {
    case pawn, bishop, knight, rook, queen, king, legendKing

    // Tier whose color (and, for legend, glimmer) themes this rank's emblem.
    var tier: BadgeTier {
        switch self {
        case .pawn:       return .bronze
        case .bishop:     return .silver
        case .knight:     return .gold
        case .rook:       return .platinum
        case .queen:      return .diamond
        case .king:       return .emerald
        case .legendKing: return .legend
        }
    }

    var title: String {
        switch self {
        case .pawn:       return "Pawn"
        case .bishop:     return "Bishop"
        case .knight:     return "Knight"
        case .rook:       return "Rook"
        case .queen:      return "Queen"
        case .king:       return "King"
        case .legendKing: return "Legend King"
        }
    }

    // Chess-piece glyph. A custom SF Symbol asset name; the emblem falls back to
    // `fallbackSymbol` until the art is imported. King is reused for the top two.
    var iconName: String {
        switch self {
        case .pawn:              return "chess_pawn_0"
        case .bishop:            return "chess_bishop_1"
        case .knight:            return "chess_knight_2"
        case .rook:              return "chess_rook_3"
        case .queen:             return "chess_queen_4"
        case .king, .legendKing: return "chess_king_5"
        }
    }

    // A valid SF Symbol shown until the custom chess art is in the asset catalog.
    var fallbackSymbol: String { "crown.fill" }

    // Minimum achievement score (see StrategistScoring) to hold this rank.
    var scoreThreshold: Int {
        switch self {
        case .pawn:       return 0
        case .bishop:     return 8
        case .knight:     return 24
        case .rook:       return 45
        case .queen:      return 75
        case .king:       return 110
        case .legendKing: return 150
        }
    }

    static func < (lhs: StrategistRank, rhs: StrategistRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// Claude  Date 06/15/2026
// Pure scoring helpers — no app state, so they're trivially testable. The score
// rewards depth: each unlocked badge is worth (tierRank + 1), i.e. Bronze 1 …
// Legend 7, for a ceiling of 6 categories × 28 = 168.
enum StrategistScoring {
    static let maxScore = 168

    static func score(unlockedIDs: Set<String>) -> Int {
        Achievement.all
            .filter { unlockedIDs.contains($0.id) }
            .reduce(0) { $0 + AchievementShowcase.tierRank($1.tier) + 1 }
    }

    static func rank(forScore score: Int) -> StrategistRank {
        StrategistRank.allCases.last { score >= $0.scoreThreshold } ?? .pawn
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
