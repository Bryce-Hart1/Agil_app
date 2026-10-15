import Foundation

// CLAUDE  Date 10/14/2026
// The arithmetic behind the plate calculator: which plates exist, what a bar weighs, what a
// loaded bar or machine totals, and the greedy solve from a target weight back to plates.
// Pure (no SwiftUI) so it can be checked with a swiftc harness. Pounds only, like set logging.

/// Which calculator layout a lift gets (see Exercise.plateCalculatorMode).
enum PlateCalculatorMode: Hashable {
    /// A bar you load by hand: bar weight + plates on both sleeves.
    case barbell
    /// Plate-loaded or Smith machine: a starting resistance + plates on one or two sleeves.
    case machine
}

// CLAUDE  Date 10/14/2026
// The bar on a free-weight lift. Olympic and EZ are fixed weights; Custom reads
// PlateSetup.customBarWeight, for a technique bar, a trap bar, a gym's odd fixed bar.
enum BarChoice: String, Codable, CaseIterable, Hashable {
    case olympic, ez, custom

    var title: String {
        switch self {
        case .olympic: return "Olympic"
        case .ez:      return "EZ Bar"
        case .custom:  return "Custom"
        }
    }

    /// The bar's fixed weight, or nil for Custom (which uses the setup's own number).
    var presetWeight: Double? {
        switch self {
        case .olympic: return 45
        case .ez:      return 20
        case .custom:  return nil
        }
    }
}

// CLAUDE  Date 10/14/2026
// What the calculator remembers per lift (stored on Exercise.plateSetup): the bar for a free
// weight, and the sled weight + sides for a machine. Keeping it per lift is what makes a
// machine's logged totals consistent week to week. Decodes missing keys to defaults.
struct PlateSetup: Codable, Hashable {
    var bar: BarChoice = .olympic
    var customBarWeight: Double = 45
    var startingResistance: Double = 0
    /// 2 = plates go on both sleeves, 1 = one sleeve (landmine, iso-lateral per-arm logging).
    var loadedSides: Int = 2

    init(bar: BarChoice = .olympic, customBarWeight: Double = 45,
         startingResistance: Double = 0, loadedSides: Int = 2) {
        self.bar = bar
        self.customBarWeight = customBarWeight
        self.startingResistance = startingResistance
        self.loadedSides = loadedSides
    }

    /// The default when a lift has never been calculated: unilateral lifts log per side, so
    /// their machine plates count once.
    static func defaultSetup(isUnilateral: Bool) -> PlateSetup {
        PlateSetup(loadedSides: isUnilateral ? 1 : 2)
    }

    var barWeight: Double { bar.presetWeight ?? customBarWeight }

    /// What the lift weighs before any plates: the bar, or the machine's own resistance.
    func base(for mode: PlateCalculatorMode) -> Double {
        mode == .barbell ? barWeight : startingResistance
    }

    /// How many sleeves the plates are counted on. A barbell is always loaded evenly.
    func sides(for mode: PlateCalculatorMode) -> Int {
        mode == .barbell ? 2 : (loadedSides == 1 ? 1 : 2)
    }

    enum CodingKeys: String, CodingKey {
        case bar, customBarWeight, startingResistance, loadedSides
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bar = try c.decodeIfPresent(BarChoice.self, forKey: .bar) ?? .olympic
        customBarWeight = try c.decodeIfPresent(Double.self, forKey: .customBarWeight) ?? 45
        startingResistance = try c.decodeIfPresent(Double.self, forKey: .startingResistance) ?? 0
        loadedSides = try c.decodeIfPresent(Int.self, forKey: .loadedSides) ?? 2
    }
}

// CLAUDE  Date 10/14/2026
// The plates on ONE sleeve, as a count per denomination (indexed like PlateMath.plates).
// Both sleeves always mirror each other, so one sleeve is the whole description.
struct PlateLoad: Hashable {
    var counts: [Int] = Array(repeating: 0, count: PlateMath.plates.count)

    var perSleeve: Double {
        zip(PlateMath.plates, counts).reduce(0) { $0 + $1.0 * Double($1.1) }
    }

    var isEmpty: Bool { counts.allSatisfy { $0 == 0 } }

    /// The plates in loading order: heaviest first, so it sits against the collar.
    var stack: [Double] {
        zip(PlateMath.plates, counts).flatMap { plate, count in
            Array(repeating: plate, count: count)
        }
    }
}

enum PlateMath {
    /// Standard pound plates, heaviest first. The solve and the stage both rely on this order.
    static let plates: [Double] = [45, 35, 25, 10, 5, 2.5]

    static func total(base: Double, sides: Int, load: PlateLoad) -> Double {
        base + Double(sides) * load.perSleeve
    }

    // CLAUDE  Date 10/14/2026
    // A solve's result. `shortBy` > 0 when the target can't be made exactly with these plates
    // (the load is the closest weight under it); `belowBase` when it's lighter than the bar.
    struct Solution: Equatable {
        let load: PlateLoad
        let total: Double
        let shortBy: Double
        let belowBase: Bool
    }

    // CLAUDE  Date 10/14/2026
    // Target weight to plates per sleeve, heaviest plate first (how lifters load a bar).
    // Never overshoots: anything that doesn't divide evenly lands on the closest weight
    // below the target. A target of 0 is an empty bar with no note, not "below the bar".
    static func solve(target: Double, base: Double, sides: Int) -> Solution {
        let sideCount = max(1, sides)
        guard target >= base else {
            return Solution(load: PlateLoad(), total: base, shortBy: 0,
                            belowBase: target > 0)
        }
        var remaining = (target - base) / Double(sideCount)
        var load = PlateLoad()
        for (index, plate) in plates.enumerated() {
            // The epsilon absorbs float noise, e.g. 92.49999 per side reading as one 2.5 short.
            let count = Int((remaining + 1e-6) / plate)
            load.counts[index] = count
            remaining -= Double(count) * plate
        }
        let total = total(base: base, sides: sideCount, load: load)
        let short = ((target - total) * 100).rounded() / 100
        return Solution(load: load, total: total, shortBy: max(0, short), belowBase: false)
    }
}
