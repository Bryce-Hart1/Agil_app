import Foundation
import SwiftUI

/// Owns the available themes (built-in presets + user-created custom ones) and
/// the current selection. Persists custom themes and the selected id to
/// `theme.json`. Injected app-wide as an `@EnvironmentObject`.
@MainActor
final class ThemeManager: ObservableObject {
    @Published var customThemes: [AppTheme] { didSet { save() } }
    @Published var selectedID: UUID { didSet { save() } }
    // Claude  Date 06/13/2026
    // IDs of *paid* themes the user has bought. Free themes (price 0) are never
    // listed here — see isUnlocked. This is the only purchase state we store;
    // the spendable balance is derived (earned coins − coinsSpent).
    @Published var unlockedThemeIDs: Set<UUID> { didSet { save() } }
    // Claude  Date 06/13/2026
    // IDs of paid profile-card styles the user has bought (see CardStyle). Tracked
    // here alongside theme purchases so all coin spending flows through coinsSpent.
    @Published var unlockedCardStyleIDs: Set<String> { didSet { save() } }

    private let persistence: PersistenceService
    private static let file = "theme.json"

    // Claude  Date 06/13/2026 last changed: 06/13/2026 by: Claude
    // Added unlockedThemeIDs + unlockedCardStyleIDs. Custom decode so theme.json
    // files written before these existed still load (absent → no purchases)
    // without wiping selection/customs.
    private struct Stored: Codable {
        var selectedID: UUID
        var customThemes: [AppTheme]
        var unlockedThemeIDs: Set<UUID>
        var unlockedCardStyleIDs: Set<String>

        init(selectedID: UUID, customThemes: [AppTheme],
             unlockedThemeIDs: Set<UUID> = [], unlockedCardStyleIDs: Set<String> = []) {
            self.selectedID = selectedID
            self.customThemes = customThemes
            self.unlockedThemeIDs = unlockedThemeIDs
            self.unlockedCardStyleIDs = unlockedCardStyleIDs
        }

        enum CodingKeys: String, CodingKey {
            case selectedID, customThemes, unlockedThemeIDs, unlockedCardStyleIDs
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            selectedID = try c.decode(UUID.self, forKey: .selectedID)
            customThemes = try c.decodeIfPresent([AppTheme].self, forKey: .customThemes) ?? []
            unlockedThemeIDs = try c.decodeIfPresent(Set<UUID>.self, forKey: .unlockedThemeIDs) ?? []
            unlockedCardStyleIDs = try c.decodeIfPresent(Set<String>.self, forKey: .unlockedCardStyleIDs) ?? []
        }
    }

    init(persistence: PersistenceService = PersistenceService()) {
        self.persistence = persistence
        let stored = persistence.load(
            Self.file,
            default: Stored(selectedID: AppTheme.classic.id, customThemes: [])
        )
        self.selectedID = stored.selectedID
        self.customThemes = stored.customThemes
        self.unlockedThemeIDs = stored.unlockedThemeIDs
        self.unlockedCardStyleIDs = stored.unlockedCardStyleIDs
    }

    /// Presets first, then the user's custom themes.
    var allThemes: [AppTheme] { AppTheme.builtIns + customThemes }

    /// The active theme (falls back to Classic if the saved id is missing).
    var current: AppTheme {
        allThemes.first { $0.id == selectedID } ?? AppTheme.classic
    }

    // Claude  Date 06/13/2026 last changed: 06/13/2026 by: Claude
    // Refuse to select a theme that hasn't been unlocked (bought) yet.
    func select(_ theme: AppTheme) {
        guard isUnlocked(theme) else { return }
        selectedID = theme.id
    }

    // MARK: - Shop / unlocking

    // Claude  Date 06/13/2026
    // A theme is usable if it's free (price 0 — Classic + customs) or bought.
    func isUnlocked(_ theme: AppTheme) -> Bool {
        theme.price == 0 || unlockedThemeIDs.contains(theme.id)
    }

    // Claude  Date 06/13/2026 last changed: 06/13/2026 by: Claude
    // Coins already spent = prices of every paid item we own (themes + card
    // styles). Derived (not stored) so it can never drift from what's owned.
    var coinsSpent: Int {
        let themeSpent = allThemes.filter { unlockedThemeIDs.contains($0.id) }.reduce(0) { $0 + $1.price }
        let cardSpent = CardStyle.all.filter { unlockedCardStyleIDs.contains($0.id) }.reduce(0) { $0 + $1.price }
        return themeSpent + cardSpent
    }

    // Claude  Date 06/13/2026
    // The spendable balance given a lifetime-earned total (Coins.earned). Clamped
    // at 0 so deleting workouts (which lowers earned) can't show a negative wallet;
    // already-owned items stay owned regardless.
    func balance(earned: Int) -> Int {
        max(0, earned - coinsSpent)
    }

    // Claude  Date 06/13/2026
    // Buy a theme if the caller's current balance covers its price. Returns true
    // on success (or if already unlocked). Records ownership only — the balance
    // recomputes itself from coinsSpent, so there's nothing to decrement.
    @discardableResult
    func purchase(_ theme: AppTheme, balance: Int) -> Bool {
        if isUnlocked(theme) { return true }
        guard balance >= theme.price else { return false }
        unlockedThemeIDs.insert(theme.id)
        return true
    }

    // Claude  Date 06/13/2026
    // Card-style equivalents of isUnlocked / purchase. The free default style is
    // always unlocked; paid ones are recorded in unlockedCardStyleIDs once bought.
    func isCardStyleUnlocked(_ style: CardStyle) -> Bool {
        style.price == 0 || unlockedCardStyleIDs.contains(style.id)
    }

    @discardableResult
    func purchaseCardStyle(_ style: CardStyle, balance: Int) -> Bool {
        if isCardStyleUnlocked(style) { return true }
        guard balance >= style.price else { return false }
        unlockedCardStyleIDs.insert(style.id)
        return true
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
        persistence.save(
            Stored(selectedID: selectedID, customThemes: customThemes,
                   unlockedThemeIDs: unlockedThemeIDs, unlockedCardStyleIDs: unlockedCardStyleIDs),
            to: Self.file
        )
    }
}
