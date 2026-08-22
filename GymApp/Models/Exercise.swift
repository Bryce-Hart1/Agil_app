import Foundation

// Claude  Date 06/13/2026
// Optional "big 3" classification used by the lift achievements. nil = unspecified
// (we fall back to a name heuristic in ProfileStats). Lets users tag an exercise
// explicitly so achievements don't depend on how it's named.
enum LiftType: String, Codable, CaseIterable, Hashable {
    case squat, bench, deadlift
    // Claude  Date 07/11/2026
    // Bicep curl badge — an isolation lift, not part of the big-3, but tracked the
    // same way (see Achievement.Category.curl).
    case curl

    var title: String {
        switch self {
        case .squat:    return "Back Squat"
        case .bench:    return "Bench Press"
        case .deadlift: return "Deadlift"
        case .curl:     return "Bicep Curl"
        }
    }
}

// Claude  Date 06/14/2026
// Science-based quality tag for a movement, from the curated lift library:
// "Optimal" = high stimulus-to-fatigue / great resistance profile, "Classic" = a
// proven staple. Stored on every seed lift; nil for user-created exercises until
// they pick one. Not surfaced in the UI yet — kept for an upcoming feature.
enum LiftQuality: String, Codable, CaseIterable, Hashable {
    case optimal, classic

    var title: String { rawValue.capitalized }
}

// Claude  Date 06/14/2026
// Top-level body region — the PRIMARY grouping for browsing the library, sitting
// above the muscle sub-group (`category`). e.g. region "Legs" contains the Quads /
// Hamstrings / Glutes / Calves sub-groups. `allCases` order defines section order;
// `.other` catches custom exercises with no region assigned.
enum MuscleRegion: String, Codable, CaseIterable, Hashable {
    case legs, chest, back, shoulders, arms, core, other

    var title: String {
        switch self {
        case .legs:      return "Legs"
        case .chest:     return "Chest"
        case .back:      return "Back"
        case .shoulders: return "Shoulders"
        case .arms:      return "Arms"
        case .core:      return "Core"
        case .other:     return "Other"
        }
    }
}

// Claude  Date 08/18/2026
// How a lift is loaded — the "nameplate" shown beside its name, and the gate on
// whether branding is offered. nil on lifts saved before this field existed (see
// AppStore's backfill) and on custom lifts the user never classified.
enum EquipmentType: String, Codable, CaseIterable, Hashable {
    case machine, freeWeight, cable, smithMachine, bodyweight

    var title: String {
        switch self {
        case .machine:      return "Machine"
        case .freeWeight:   return "Free Weight"
        case .cable:        return "Cable"
        case .smithMachine: return "Smith Machine"
        case .bodyweight:   return "Bodyweight"
        }
    }

    // Claude  Date 08/18/2026
    // Whether the implementation varies enough between manufacturers that a branded
    // version tracks as a different lift. A Hammer Strength leg press and a Cybex leg
    // press are genuinely different movements; a 45 lb barbell is a 45 lb barbell
    // everywhere, so free weights and bodyweight movements aren't branded.
    var isBrandable: Bool {
        switch self {
        case .machine, .cable, .smithMachine: return true
        case .freeWeight, .bodyweight:        return false
        }
    }
}

/// A movement you can perform, e.g. "Barbell Bench Press".
/// This is your reusable exercise library; individual workouts reference it by `id`.
struct Exercise: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    // Claude  Date 06/14/2026
    // Two-level grouping: `region` is the body region (Legs, Back…) used as the
    // primary browse section; `category` is the muscle sub-group within it.
    var region: MuscleRegion
    var category: String   // muscle sub-group, e.g. "Quads", "Lats" — drives graphs
    // Claude  Date 06/09/2026
    // Whether the movement is performed one side at a time (e.g. single-arm row).
    // Set when creating the exercise; used to track it differently on graphs.
    var isUnilateral: Bool
    // Claude  Date 06/13/2026 last changed: 06/14/2026 by: Claude
    // Explicit "big 3" tag for the lift achievements. Now the SOLE source of big-3
    // truth (the old name heuristic is gone) — nil simply means "not a big-3 lift".
    var liftType: LiftType?
    // Claude  Date 06/14/2026
    // The muscle this movement primarily drives, e.g. "Quadriceps", "Gluteus
    // Maximus", "Latissimus Dorsi". The science detail for the curated library;
    // `category` holds the coarser sub-group used for grouping/graphs.
    var primaryMover: String
    // Claude  Date 07/20/2026
    // Whether the movement is a bodyweight lift (pull-up, dip, chin-up…). When true,
    // a logged set's `weight` means ADDED weight on top of bodyweight, so the UI shows
    // it as "+25 lb" (and a bare "+0" for pure bodyweight) rather than a raw load.
    var isBodyweight: Bool
    // Claude  Date 06/14/2026
    // Optimal/Classic quality tag (see LiftQuality). nil for untagged custom lifts.
    var quality: LiftQuality?
    // Claude  Date 08/04/2026
    // The "perma note": a form cue that belongs to the LIFT, not to any one
    // session — it surfaces wherever this exercise appears (workout editor,
    // preset editor) and edits write straight back to the library. Contrast with
    // LoggedExercise.note / PresetItem.note, which are per-session/per-template.
    var note: String?
    // Claude  Date 08/18/2026
    // The manufacturer of the specific machine this entry tracks, e.g. "Hammer
    // Strength". "" = the generic lift. A branded version is a SEPARATE library entry
    // with its own id — that's what makes it graph on its own, since every workout,
    // event and PR keys off exerciseId, so the generic lift keeps all its history.
    // Free text, but snapped to the spelling already in the library by
    // `normalizedBrand` so "hammer strength" and "Hammer Strength" stay one brand.
    var brand: String
    // Claude  Date 08/18/2026
    // How the lift is loaded (see EquipmentType) — drives the nameplate chip beside the
    // name and gates `canBeBranded`. Optional because existing installs genuinely don't
    // know it until AppStore's backfill matches them against the seed library.
    var equipmentType: EquipmentType?

    init(id: UUID = UUID(), name: String, region: MuscleRegion = .other, category: String,
         isUnilateral: Bool = false, liftType: LiftType? = nil,
         primaryMover: String = "", quality: LiftQuality? = nil,
         isBodyweight: Bool = false, note: String? = nil,
         brand: String = "", equipmentType: EquipmentType? = nil) {
        self.id = id
        self.name = name
        self.region = region
        self.category = category
        self.isUnilateral = isUnilateral
        self.liftType = liftType
        self.primaryMover = primaryMover
        self.quality = quality
        self.isBodyweight = isBodyweight
        self.note = note
        self.brand = brand
        self.equipmentType = equipmentType
    }

    // Claude  Date 08/18/2026
    // The brand, trimmed, or nil when this is the generic (unbranded) lift.
    var brandLabel: String? {
        let trimmed = brand.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    var isBrandVariant: Bool { brandLabel != nil }

    // Claude  Date 08/18/2026
    // Name plus the brand when set — "Leg Press · Hammer Strength" (same separator as
    // FoodItem.displayLabel). Use this, not displayLabel, wherever the consumer already
    // renders the unilateral flag itself, so it isn't labeled twice.
    var brandedName: String {
        brandLabel.map { "\(name) · \($0)" } ?? name
    }

    // Claude  Date 06/09/2026 Edited 6/10/2026 Bryce Hart last changed: 08/18/2026 by: Claude
    // Name with a "(unilateral)" suffix when applicable, for graph/stat labels.
    //made capital
    // (08/18) Now built on brandedName so branded versions of one lift are
    // distinguishable everywhere a label appears — the Progress picker most of all.
    var displayLabel: String {
        isUnilateral ? "\(brandedName) (Unilateral)" : brandedName
    }

    // Claude  Date 08/18/2026
    // Whether the "Add Brand" action is offered for this lift. Permissive when the
    // equipment is unknown: nil means "not classified yet" (every lift created before
    // the field existed, and every custom lift), and hiding branding behind a field the
    // user never filled in would make the feature look broken.
    var canBeBranded: Bool { equipmentType?.isBrandable ?? true }

    // Claude  Date 07/09/2026
    // Muscle subtitle for library rows: the sub-group, plus the specific primary mover
    // when one is set (e.g. "Calves · Soleus"). Falls back to just the sub-group when the
    // mover is blank (custom lifts left it empty).
    var muscleSubtitle: String {
        primaryMover.isEmpty ? category : "\(category) · \(primaryMover)"
    }

    // Claude  Date 06/13/2026 last changed: 06/14/2026 by: Claude
    // Whether this exercise counts toward the "big 3" lift achievements. Driven
    // solely by the explicit `liftType` tag now — the old name heuristic was
    // dropped because the expanded library (Hack Squat, Bulgarian Split Squat,
    // Close-Grip Bench Press…) would otherwise false-match on "squat"/"bench".
    var countsAsBig3: Bool {
        liftType != nil
    }

    // Claude  Date 07/11/2026
    // The lift type actually credited for achievements. Unlike the big-3 (which
    // require an explicit tag, since the library has name collisions like "Hack
    // Squat"), any Arms/Biceps exercise automatically counts as a curl — no manual
    // tagging needed, so every existing and future biceps exercise (Hammer Curl,
    // Cable Curl, a custom curl the user adds, etc.) credits the Bicep Curl badge.
    // Explicit tags still take priority when present.
    var effectiveLiftType: LiftType? {
        liftType ?? (region == .arms && category == "Biceps" ? .curl : nil)
    }

    // Claude  Date 06/09/2026 last changed: 08/04/2026 by: Claude
    // Custom decode so exercises saved before newer fields existed still load
    // (missing keys default to false / nil / ""). encode(to:) is synthesized.
    // (07/20) Added isBodyweight — absent on older exercises, so defaults false.
    // (08/04) Added note (the perma note) — absent on older exercises, so nil.
    // (08/18) Added brand + equipmentType — absent on older exercises, so "" / nil.
    // NOTE: encode(to:) is synthesized off CodingKeys, so a field left out of the enum
    // below is silently dropped on every save. Add new fields to BOTH lists.
    enum CodingKeys: String, CodingKey {
        case id, name, region, category, isUnilateral, liftType, primaryMover, quality, isBodyweight,
             note, brand, equipmentType
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        region = try c.decodeIfPresent(MuscleRegion.self, forKey: .region) ?? .other
        category = try c.decode(String.self, forKey: .category)
        isUnilateral = try c.decodeIfPresent(Bool.self, forKey: .isUnilateral) ?? false
        liftType = try c.decodeIfPresent(LiftType.self, forKey: .liftType)
        primaryMover = try c.decodeIfPresent(String.self, forKey: .primaryMover) ?? ""
        quality = try c.decodeIfPresent(LiftQuality.self, forKey: .quality)
        isBodyweight = try c.decodeIfPresent(Bool.self, forKey: .isBodyweight) ?? false
        note = try c.decodeIfPresent(String.self, forKey: .note)
        brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        equipmentType = try c.decodeIfPresent(EquipmentType.self, forKey: .equipmentType)
    }
}

// MARK: - Relatedness

extension Exercise {
    // Claude  Date 08/16/2026
    // Which lifts are plausible substitutes for `target` — what the Swap picker floats
    // to the top so you don't scroll the whole library to trade a Barbell Bench Press
    // for an Incline Dumbbell Press.
    //
    // Scored on the tags the library already carries rather than a hand-kept synonym
    // table, so it stays correct as lifts are added:
    //
    //   sub-group (`category`)  +3  — the strongest signal; "Chest" ≈ "Chest"
    //   primary mover           +3  — catches cross-group matches (a Lats pulldown and a
    //                                 Lats row) and separates Triceps (Long Head) work
    //                                 from general Triceps work within one group
    //   lift type               +2  — bench/squat/deadlift/curl variants of each other
    //   equipment               +1  — a cable movement prefers another cable movement
    //   region                  +1  — the loosest tie, on its own only a weak match
    //
    // Anything scoring 0 isn't offered. Ties prefer a like-for-like swap — same
    // unilateral and bodyweight character, since those change how the lift is logged —
    // then fall to name so the order is stable between openings.
    static func related(to target: Exercise, in library: [Exercise], limit: Int = 6) -> [Exercise] {
        func score(_ candidate: Exercise) -> Int {
            var score = 0
            if candidate.category == target.category { score += 3 }
            if !target.primaryMover.isEmpty, candidate.primaryMover == target.primaryMover { score += 3 }
            if let lift = target.effectiveLiftType, candidate.effectiveLiftType == lift { score += 2 }
            if let equipment = target.equipmentType, candidate.equipmentType == equipment { score += 1 }
            if candidate.region == target.region { score += 1 }
            return score
        }

        func modalityMatch(_ candidate: Exercise) -> Int {
            (candidate.isUnilateral == target.isUnilateral ? 1 : 0)
                + (candidate.isBodyweight == target.isBodyweight ? 1 : 0)
        }

        return library
            // Claude  Date 08/18/2026
            // Branded versions of the SAME lift are excluded here — they'd otherwise fill
            // the whole 6-slot list and crowd out real substitutes. The picker shows them
            // in their own section instead (see brandSiblings).
            .filter { $0.id != target.id
                      && $0.name.caseInsensitiveCompare(target.name) != .orderedSame }
            .map { (exercise: $0, score: score($0)) }
            .filter { $0.score > 0 }
            .sorted { a, b in
                (a.score, modalityMatch(a.exercise), b.exercise.brandedName)
                    > (b.score, modalityMatch(b.exercise), a.exercise.brandedName)
            }
            .prefix(limit)
            .map(\.exercise)
    }
}

// MARK: - Primary movers

extension Exercise {
    // Claude  Date 06/16/2026
    // The canonical set of primary movers the app uses (every one appears in the
    // seed library, plus a few common extras). The exercise editor offers these as
    // autocomplete and snaps a typed name to the canonical spelling, so custom lifts
    // reuse consistent muscle names instead of free-typed variants/typos. Not a full
    // anatomy list — just the movers worth grouping/labeling by.
    static let commonPrimaryMovers: [String] = [
        "Quadriceps",
        "Hamstrings",
        "Gluteus Maximus",
        "Adductors",
        "Abductors",
        "Gastrocnemius",
        "Soleus",
        "Pectorals",
        "Pectorals (Upper)",
        "Pectorals (Lower)",
        "Latissimus Dorsi",
        "Mid-Back",
        "Rhomboids / Mid Traps",
        "Upper Trapezius",
        "Spinal Erectors",
        "Lateral Deltoid",
        "Anterior / Lateral Deltoid",
        "Posterior Deltoid",
        "Biceps Brachii",
        "Brachialis / Brachioradialis",
        "Triceps",
        "Triceps (Long Head)",
        "Triceps (Lateral Head)",
        "Wrist Flexors",
        "Wrist Extensors",
        "Grip / Forearms",
        "Rectus Abdominis",
        "Rectus Abdominis (Lower)",
        "Obliques",
        "Transverse Abdominis",
        "Serratus Anterior",
    ]

    // Claude  Date 06/16/2026
    // Snap a typed mover to the canonical spelling when it matches one case-
    // insensitively (e.g. "quadriceps" → "Quadriceps"); otherwise return it as-is
    // (trimmed) so genuinely new movers are still allowed. Empty stays empty.
    static func normalizedPrimaryMover(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        return commonPrimaryMovers.first { $0.caseInsensitiveCompare(trimmed) == .orderedSame } ?? trimmed
    }
}

// MARK: - Brands

extension Exercise {
    // Claude  Date 08/18/2026
    // The other versions of this same movement — the generic lift plus every branded
    // one. Kept OUT of `related(to:in:)` and rendered as its own picker section, so a
    // leg press with four brands doesn't swallow the "Similar" list. Matched on `name`
    // because that's what stays constant across versions: the brand never enters the
    // name (the premade catalog and search both resolve on the base name).
    static func brandSiblings(of target: Exercise, in library: [Exercise]) -> [Exercise] {
        library
            .filter { $0.id != target.id
                      && $0.name.caseInsensitiveCompare(target.name) == .orderedSame }
            .sorted { $0.brand.localizedCaseInsensitiveCompare($1.brand) == .orderedAscending }
    }

    // Claude  Date 08/18/2026
    // Distinct brands in the library, canonically spelled. Unlike primary movers there's
    // no fixed list to snap to — the user's own library IS the canon, so the first
    // spelling to enter it wins (append-ordered, and edits replace in place).
    static func knownBrands(in library: [Exercise]) -> [String] {
        var canonical: [String: String] = [:]   // lowercased key -> first-seen spelling
        for exercise in library {
            guard let brand = exercise.brandLabel else { continue }
            let key = brand.lowercased()
            if canonical[key] == nil { canonical[key] = brand }
        }
        return canonical.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // Claude  Date 08/18/2026
    // Snap a typed brand to the spelling already in the library when it matches case-
    // insensitively ("hammer strength" → "Hammer Strength"), so one machine brand never
    // splits into two entries you have to scroll past. A genuinely new brand is
    // title-cased instead, so it enters the library well-formed. Empty stays empty.
    // Mirrors normalizedPrimaryMover, with the library standing in for the canon list.
    static func normalizedBrand(_ input: String, in library: [Exercise]) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        if let existing = knownBrands(in: library)
            .first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        return titleCasedBrand(trimmed)
    }

    // Claude  Date 08/18/2026
    // Title-case for brands. NOT String.capitalized — that flattens interior caps the
    // user typed on purpose ("EZ" → "Ez", "iFit" → "Ifit"). Rule: a word already
    // containing an uppercase letter is left verbatim; an all-lowercase word gets its
    // first character uppercased. Runs of whitespace collapse to a single space.
    static func titleCasedBrand(_ input: String) -> String {
        input
            .split(whereSeparator: { $0.isWhitespace })
            .map { word in
                word.contains(where: \.isUppercase)
                    ? String(word)
                    : word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}
