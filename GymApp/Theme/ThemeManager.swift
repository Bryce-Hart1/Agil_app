import Foundation
import SwiftUI
// Claude  Date 07/16/2026
// WidgetKit: the home-screen widget is tinted with the active theme, so theme
// changes push the new palette into the shared snapshot and reload the widget.
import WidgetKit

/// Owns the available themes (built-in presets + user-created custom ones) and
/// the current selection. Persists custom themes and the selected id to
/// `theme.json`. Injected app-wide as an `@EnvironmentObject`.
///
// Claude  Date 08/03/2026
// This type is now "cosmetics AND wallet": it also owns the coin balance (see
// Wallet). That pairing is deliberate rather than tidy — the spend ledger and the
// unlock sets must never disagree, and keeping them in one struct written by one
// atomic save makes a desync structurally impossible. A separate wallet.json could
// be half-written relative to theme.json and leave someone charged for an item they
// don't own.
@MainActor
final class ThemeManager: ObservableObject {
    @Published var customThemes: [AppTheme] { didSet { save() } }
    @Published var selectedID: UUID { didSet { save() } }
    // Claude  Date 06/13/2026
    // IDs of *paid* themes the user has bought. Free themes (price 0) are never
    // listed here — see isUnlocked.
    @Published var unlockedThemeIDs: Set<UUID> { didSet { save() } }
    // Claude  Date 06/13/2026
    // IDs of paid profile-card styles the user has bought (see CardStyle). Tracked
    // here alongside theme purchases so all coin spending flows through one wallet.
    @Published var unlockedCardStyleIDs: Set<String> { didSet { save() } }

    // Claude  Date 08/03/2026
    // The coin wallet: earned high-water mark, purchased coins, and the spend ledger.
    // private(set) because nothing outside this class may move money — go through
    // purchase(_:), creditPurchasedCoins(...) or noteEarned(_:).
    @Published private(set) var wallet: Wallet { didSet { save() } }

    // Claude  Date 08/03/2026
    // Set when theme.json existed but could not be decoded. In safe mode we refuse
    // to write anything, because the alternative is overwriting the user's only good
    // copy — including their paid balance — with the defaults we fell back to. Also
    // blocks purchases: spending against a balance we know is wrong is worse than
    // telling the user something is broken.
    @Published private(set) var isSafeMode = false

    // Claude  Date 09/18/2026
    // Settings' "Use system font": swaps the theme's typeface for Apple's default app-wide
    // (read through `fontDesign` below). A display pref, so it lives in UserDefaults rather
    // than theme.json (the wallet / iCloud payload). Side effect: re-pushes the widget snapshot.
    @Published var usesSystemFont: Bool {
        didSet {
            UserDefaults.standard.set(usesSystemFont, forKey: Self.usesSystemFontKey)
            syncWidgetSnapshot()
        }
    }
    private static let usesSystemFontKey = "useSystemFont"

    private let persistence: PersistenceService
    private static let file = "theme.json"

    // Claude  Date 08/03/2026
    // Set while a multi-field change is in flight (e.g. "record the spend AND grant
    // the item") so the individual didSets don't each write a partial state. See
    // `batched`.
    private var suppressSave = false

    // Claude  Date 06/13/2026 last changed: 08/07/2026 by: Claude
    // Added unlockedThemeIDs + unlockedCardStyleIDs. Custom decode so theme.json files
    // written before either existed still load (absent → no purchases) without wiping
    // selection/customs. (08/07: unlockedAvatarIDs and unlockedCharacterOptionIDs went with
    // the profile-face feature. Old theme.json files still carry both keys; they're ignored
    // on decode, and any coins they represented return to the user's balance because
    // coinsSpent is derived from what's still purchasable.)
    struct Stored: Codable {
        var selectedID: UUID
        var customThemes: [AppTheme]
        var unlockedThemeIDs: Set<UUID>
        var unlockedCardStyleIDs: Set<String>
        // Claude  Date 08/03/2026
        // Optional so a theme.json written before the wallet existed still loads;
        // nil is the signal to run the one-time migration in init().
        var wallet: Wallet?

        init(selectedID: UUID, customThemes: [AppTheme],
             unlockedThemeIDs: Set<UUID> = [], unlockedCardStyleIDs: Set<String> = [],
             wallet: Wallet? = nil) {
            self.selectedID = selectedID
            self.customThemes = customThemes
            self.unlockedThemeIDs = unlockedThemeIDs
            self.unlockedCardStyleIDs = unlockedCardStyleIDs
            self.wallet = wallet
        }

        enum CodingKeys: String, CodingKey {
            case selectedID, customThemes, unlockedThemeIDs, unlockedCardStyleIDs, wallet
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // Claude  Date 08/03/2026
            // decodeIfPresent, not decode (was a hard decode until 08/03). A single
            // malformed selectedID used to throw the whole decode, which cost the
            // user every unlock they'd bought. Falling back to Classic loses a
            // preference; throwing lost their purchases.
            selectedID = try c.decodeIfPresent(UUID.self, forKey: .selectedID) ?? AppTheme.classic.id
            customThemes = try c.decodeIfPresent([AppTheme].self, forKey: .customThemes) ?? []
            unlockedThemeIDs = try c.decodeIfPresent(Set<UUID>.self, forKey: .unlockedThemeIDs) ?? []
            unlockedCardStyleIDs = try c.decodeIfPresent(Set<String>.self, forKey: .unlockedCardStyleIDs) ?? []
            wallet = try c.decodeIfPresent(Wallet.self, forKey: .wallet)
        }
    }

    init(persistence: PersistenceService = PersistenceService()) {
        self.persistence = persistence

        // Claude  Date 08/03/2026
        // loadStrict rather than load: a decode failure must NOT silently become
        // "you own nothing and have no coins", because the very next save() would
        // make that permanent. On failure we start from defaults but lock writes.
        var stored = Stored(selectedID: AppTheme.classic.id, customThemes: [])
        var safeMode = false
        do {
            if let loaded: Stored = try persistence.loadStrict(Self.file) { stored = loaded }
        } catch {
            print("⚠️ theme.json failed to decode: \(error). Entering safe mode — no writes.")
            safeMode = true
        }

        self.selectedID = stored.selectedID
        self.customThemes = stored.customThemes
        self.unlockedThemeIDs = stored.unlockedThemeIDs
        self.unlockedCardStyleIDs = stored.unlockedCardStyleIDs
        self.isSafeMode = safeMode
        self.usesSystemFont = UserDefaults.standard.bool(forKey: Self.usesSystemFontKey)

        // Claude  Date 08/03/2026
        // One-time migration for files written before the wallet existed: rebuild a
        // spend ledger from what the user already owns, priced at today's catalogue.
        // That is exactly what the old derived `coinsSpent` was computing, so the
        // visible balance doesn't move — it just stops being recomputed, which is
        // what makes future repricing safe. earnedHighWater fills in on the first
        // noteEarned() call from the app (see GymAppApp).
        if let existing = stored.wallet {
            self.wallet = existing
        } else {
            self.wallet = Self.migratedWallet(themeIDs: stored.unlockedThemeIDs,
                                              cardIDs: stored.unlockedCardStyleIDs,
                                              customThemes: stored.customThemes)
        }

        grantFoundersCards()
    }

    // Claude  Date 08/03/2026
    // Synthesise the ledger the old derived model implied. Static so it can run
    // before `self` is fully initialised.
    private static func migratedWallet(themeIDs: Set<UUID>, cardIDs: Set<String>,
                                       customThemes: [AppTheme]) -> Wallet {
        var wallet = Wallet()
        for theme in (AppTheme.builtIns + customThemes) where themeIDs.contains(theme.id) && theme.price > 0 {
            wallet.spend(itemID: ShopItem.theme(theme).id, price: theme.price)
        }
        for card in CardStyle.all where cardIDs.contains(card.id) && card.price > 0 {
            wallet.spend(itemID: ShopItem.card(card).id, price: card.price)
        }
        return wallet
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

    // Claude  Date 09/18/2026
    // The typeface the app actually renders in: the theme's, unless "Use system font" is on.
    // Everything that draws live app text reads this, not current.fontDesign; theme previews
    // (Shop showcase, theme editor) deliberately keep the theme's own face.
    var fontDesign: AppFontDesign { usesSystemFont ? .system : current.fontDesign }

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

    // MARK: - Wallet

    // Claude  Date 06/13/2026 last changed: 08/03/2026 by: Claude
    // Coins already spent. Read off the ledger now instead of being recomputed by
    // re-pricing everything you own against the live catalogue. That old approach
    // meant repricing or removing an item retroactively changed every user's balance
    // — and it actually happened when avatars were removed on 08/07 and everyone got
    // those coins back. The ledger records what was paid, so the catalogue is free
    // to move afterwards.
    var coinsSpent: Int { wallet.spentTotal }

    // Claude  Date 06/13/2026 last changed: 08/03/2026 by: Claude
    // The spendable balance. No max(0,…) clamp any more: every term of the wallet is
    // monotonic, so it can't go negative on its own, and the clamp was capable of
    // absorbing coins the user had paid real money for.
    var balance: Int { wallet.balance }

    // Claude  Date 08/03/2026
    // Feed in the lifetime-earned total (AppStore.totalCoinsEarned) so the wallet can
    // raise its high-water mark. Called at launch and whenever the earned total
    // changes; safe to call repeatedly, and it never lowers anything — deleting a
    // workout no longer takes coins away from you.
    func noteEarned(_ earned: Int) {
        guard earned > wallet.earnedHighWater else { return }
        wallet.noteEarned(earned)
    }

    // Claude  Date 08/03/2026
    // Credit a verified StoreKit purchase. Returns false if this transaction id was
    // already credited (StoreKit re-delivers) or if we're in safe mode. The caller
    // must not finish() the transaction unless this returned true — see CoinStore.
    @discardableResult
    func creditPurchasedCoins(transactionID: UInt64, coins: Int) -> Bool {
        guard !isSafeMode else { return false }
        return wallet.credit(transactionID: transactionID, coins: coins)
    }

    // Claude  Date 08/03/2026
    // Replace the wallet with the result of merging in a copy from iCloud. Only ever
    // called by CloudWalletSync; the merge itself is max/union, so this can't lose
    // coins or unlocks.
    func mergeWallet(_ incoming: Wallet, unlockedThemes: Set<UUID>, unlockedCards: Set<String>) {
        guard !isSafeMode else { return }
        let merged = wallet.merged(with: incoming)
        // Nothing new — don't write, don't reload the widget, don't push back to
        // iCloud. Merges run on every launch and every external change, and the
        // common case is that both sides already agree.
        guard merged != wallet
                || !unlockedThemes.isSubset(of: unlockedThemeIDs)
                || !unlockedCards.isSubset(of: unlockedCardStyleIDs) else { return }
        batched {
            wallet = merged
            unlockedThemeIDs.formUnion(unlockedThemes)
            unlockedCardStyleIDs.formUnion(unlockedCards)
        }
    }

    // MARK: - Buying

    // Claude  Date 06/13/2026 last changed: 08/03/2026 by: Claude
    // Buy a theme. The balance is no longer passed in by the caller — the wallet
    // lives here now, so the affordability check can't be bypassed by a caller that
    // computes it differently. Returns true on success (or if already unlocked).
    @discardableResult
    func purchase(_ theme: AppTheme) -> Bool {
        if isUnlocked(theme) { return true }
        guard !isSafeMode, balance >= theme.price else { return false }
        // One write, so the receipt and the item can never be persisted apart.
        batched {
            wallet.spend(itemID: ShopItem.theme(theme).id, price: theme.price)
            unlockedThemeIDs.insert(theme.id)
        }
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
    func purchaseCardStyle(_ style: CardStyle) -> Bool {
        if isCardStyleUnlocked(style) { return true }
        guard !isSafeMode, balance >= style.price else { return false }
        batched {
            wallet.spend(itemID: ShopItem.card(style).id, price: style.price)
            unlockedCardStyleIDs.insert(style.id)
        }
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

    // Claude  Date 08/03/2026
    // Run several wallet/unlock mutations as ONE persisted change. Without this,
    // "record the spend" and "grant the item" are two didSets and therefore two
    // writes, and a crash in between leaves the user charged for something they
    // don't own. Reentrant-safe: a nested call doesn't clear the flag early.
    private func batched(_ body: () -> Void) {
        let wasSuppressed = suppressSave
        suppressSave = true
        body()
        suppressSave = wasSuppressed
        if !wasSuppressed { save() }
    }

    /// The current on-disk shape, also used as the iCloud payload.
    var snapshot: Stored {
        Stored(selectedID: selectedID, customThemes: customThemes,
               unlockedThemeIDs: unlockedThemeIDs, unlockedCardStyleIDs: unlockedCardStyleIDs,
               wallet: wallet)
    }

    private func save() {
        guard !suppressSave else { return }
        // Claude  Date 08/03/2026
        // Safe mode: we failed to read this file, so writing would replace data we
        // couldn't parse with defaults we invented. Refuse.
        guard !isSafeMode else { return }
        persistence.save(snapshot, to: Self.file)
        syncWidgetSnapshot()
        onWalletChanged?(self)
    }

    #if DEBUG
    // Claude  Date 08/03/2026
    // Debug-only wallet reset. Needed because the earned total is now held at a
    // high-water mark: "Reset dev coins" lowers AppStore.devBonusCoins but can no
    // longer lower the balance on its own, which is the whole point of the mark.
    func debugResetWallet() {
        wallet = Wallet()
    }
    #endif

    // Claude  Date 09/06/2026
    // "Delete Account": themes, purchases and wallet back to first-install state, as
    // one atomic write. Only AccountDeletion calls this.
    //
    // Clears isSafeMode first ON PURPOSE — safe mode exists to stop us overwriting a
    // file we couldn't parse, but a deliberate account deletion is exactly the case
    // where destroying that file is the goal. Side effect: this wipes PURCHASED coins
    // and everything bought with them, and the save() it triggers pushes the emptied
    // wallet to iCloud through onWalletChanged (AccountDeletion also removes the
    // iCloud copy outright).
    func eraseAllData() {
        isSafeMode = false
        batched {
            customThemes = []
            selectedID = AppTheme.classic.id
            unlockedThemeIDs = []
            unlockedCardStyleIDs = []
            wallet = Wallet()
        }
    }

    // Claude  Date 08/03/2026
    // Called after every successful save. CloudWalletSync hooks in here to push the
    // wallet to iCloud; kept as a closure so ThemeManager doesn't have to know that
    // iCloud exists (and so tests can leave it nil).
    var onWalletChanged: ((ThemeManager) -> Void)?

    // Claude  Date 07/16/2026 last changed: 09/18/2026 by: Claude
    // Push the active theme into the widget's shared snapshot (App Group) so the
    // home-screen widget re-tints itself. Called from save() (any selection /
    // custom-theme edit lands there) and once at launch from GymAppApp — didSets
    // don't fire during init, so a launch call is needed for the first write.
    // (09/18) Ships the effective typeface, so the widget honors "Use system font".
    func syncWidgetSnapshot() {
        var widgetTheme = current
        widgetTheme.fontDesignRaw = fontDesign.rawValue
        WidgetSnapshot.update { $0.theme = widgetTheme }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
