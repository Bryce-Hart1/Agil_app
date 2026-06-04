import Foundation

/// A movement you can perform, e.g. "Barbell Bench Press".
/// This is your reusable exercise library; individual workouts reference it by `id`.
struct Exercise: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var category: String   // e.g. "Chest", "Legs" — used for filtering/graphs later

    init(id: UUID = UUID(), name: String, category: String) {
        self.id = id
        self.name = name
        self.category = category
    }
}
