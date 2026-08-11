import Foundation
import SwiftUI
// Claude  Date 07/16/2026
// WidgetKit: the home-screen widget is tinted with the active theme, so theme
// changes push the new palette into the shared snapshot and reload the widget.
import WidgetKit

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

    // Claude  Date 06/13/2026 last changed: 08/07/2026 by: Claude
    // Added unlockedThemeIDs + unlockedCardStyleIDs. Custom decode so theme.json files
    // written before either existed still load (absent → no purchases) without wiping
    // selection/customs. (08/07: unlockedAvatarIDs and unlockedCharacterOptionIDs went with
    // the profile-face feature. Old theme.json files still carry both keys; they're ignored
    // on decode, and any coins they represented return to the user's balance because
    // coinsSpent is derived from what's still purchasable.)
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
        grantFoundersCards()
    }

    // Claude  Date 07/12/2026 last changed: 07/12/2026 by: Claude
    // Grant every Founders Edition card. Idempotent — returns true only if something
    // was newly granted, so a caller can decide whether to celebrate. Founders cards
    // aren't sold anywhere, so there's no purchase flow to unlock them through; the
    // real IAP purchase-success handler will call this later. There's no accounts/IAP
    // system yet to gate on, so today it's simply "if you're running this build, you're
    // a founder" (true while Bryce is the only tester) — see the launch-time call in
    // init(). Swap that gate for a real receipt/account check before a wider release.
    @discardableResult
    func grantFoundersCards() -> Bool {
        var granted = false
        for style in CardStyle.all where style.isFounders {
            if unlockedCardStyleIDs.insert(style.id).inserted { granted = true }
        }
        return granted
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

    // Claude  Date 06/13/2026 last changed: 08/07/2026 by: Claude
    // Coins already spent = prices of every paid item we own (themes + card
    // styles). Derived (not stored) so it can never drift from what's owned.
    // (08/07: the avatar and character terms went with that feature. Because this is
    // derived, anyone who had bought an avatar simply gets those coins back in their
    // balance — there's no stored total to migrate.)
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

    // Claude  Date 06/13/2026 last changed: 07/12/2026 by: Claude
    // Card-style equivalents of isUnlocked / purchase. The free default style is
    // always unlocked; paid ones are recorded in unlockedCardStyleIDs once bought.
    // Founders cards are the exception: they're never "free for everyone" just
    // because their price is 0 — they only count as unlocked once explicitly
    // granted (see grantFoundersCards), so they stay exclusive.
    // Claude  Date 06/13/2026 last changed: 07/23/2026 by: Claude
    // (Generalised the founders check to isGrantOnly so the achievement-earned gem
    // cards are gated the same way — exclusive until explicitly granted, never free
    // at price 0.)
    func isCardStyleUnlocked(_ style: CardStyle) -> Bool {
        if style.isGrantOnly { return unlockedCardStyleIDs.contains(style.id) }
        return style.price == 0 || unlockedCardStyleIDs.contains(style.id)
    }

    // Claude  Date 07/23/2026
    // Grant a single card by id (idempotent — returns true only if newly added, so a
    // caller can decide whether to play a reveal). Used to award the gemstone cards
    // when an achievement tier is first earned; the didSet persists to theme.json.
    @discardableResult
    func grantCardStyle(_ id: String) -> Bool { unlockedCardStyleIDs.insert(id).inserted }

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
        syncWidgetSnapshot()
    }

    // Claude  Date 07/16/2026
    // Push the active theme into the widget's shared snapshot (App Group) so the
    // home-screen widget re-tints itself. Called from save() (any selection /
    // custom-theme edit lands there) and once at launch from GymAppApp — didSets
    // don't fire during init, so a launch call is needed for the first write.
    func syncWidgetSnapshot() {
        WidgetSnapshot.update { $0.theme = current }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
