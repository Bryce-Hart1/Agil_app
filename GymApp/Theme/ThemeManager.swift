import Foundation
import SwiftUI

/// Owns the available themes (built-in presets + user-created custom ones) and
/// the current selection. Persists custom themes and the selected id to
/// `theme.json`. Injected app-wide as an `@EnvironmentObject`.
@MainActor
final class ThemeManager: ObservableObject {
    @Published var customThemes: [AppTheme] { didSet { save() } }
    @Published var selectedID: UUID { didSet { save() } }

    private let persistence: PersistenceService
    private static let file = "theme.json"

    private struct Stored: Codable {
        var selectedID: UUID
        var customThemes: [AppTheme]
    }

    init(persistence: PersistenceService = PersistenceService()) {
        self.persistence = persistence
        let stored = persistence.load(
            Self.file,
            default: Stored(selectedID: AppTheme.classic.id, customThemes: [])
        )
        self.selectedID = stored.selectedID
        self.customThemes = stored.customThemes
    }

    /// Presets first, then the user's custom themes.
    var allThemes: [AppTheme] { AppTheme.builtIns + customThemes }

    /// The active theme (falls back to Classic if the saved id is missing).
    var current: AppTheme {
        allThemes.first { $0.id == selectedID } ?? AppTheme.classic
    }

    func select(_ theme: AppTheme) {
        selectedID = theme.id
    }

    /// Insert a new custom theme or update an existing one with the same id.
    func addOrUpdate(_ theme: AppTheme) {
        if let index = customThemes.firstIndex(where: { $0.id == theme.id }) {
            customThemes[index] = theme
        } else {
            customThemes.append(theme)
        }
    }

    func delete(_ theme: AppTheme) {
        customThemes.removeAll { $0.id == theme.id }
        if selectedID == theme.id {
            selectedID = AppTheme.classic.id
        }
    }

    private func save() {
        persistence.save(Stored(selectedID: selectedID, customThemes: customThemes), to: Self.file)
    }
}
