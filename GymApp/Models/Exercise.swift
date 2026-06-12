import Foundation

/// A movement you can perform, e.g. "Barbell Bench Press".
/// This is your reusable exercise library; individual workouts reference it by `id`.
struct Exercise: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var category: String   // e.g. "Chest", "Legs" — used for filtering/graphs later
    // Claude  Date 06/09/2026
    // Whether the movement is performed one side at a time (e.g. single-arm row).
    // Set when creating the exercise; used to track it differently on graphs.
    var isUnilateral: Bool

    init(id: UUID = UUID(), name: String, category: String, isUnilateral: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.isUnilateral = isUnilateral
    }

    // Claude  Date 06/09/2026 Edited 6/10/2026 Bryce Hart
    // Name with a "(unilateral)" suffix when applicable, for graph/stat labels.
    //made capital
    var displayLabel: String {
        isUnilateral ? "\(name) (Unilateral)" : name
    }

    // Claude  Date 06/09/2026
    // Custom decode so exercises saved before `isUnilateral` existed still load
    // (missing key defaults to false). encode(to:) is synthesized.
    enum CodingKeys: String, CodingKey { case id, name, category, isUnilateral }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(String.self, forKey: .category)
        isUnilateral = try c.decodeIfPresent(Bool.self, forKey: .isUnilateral) ?? false
    }
}
