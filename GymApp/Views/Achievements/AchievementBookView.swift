import SwiftUI

// Peer reviewed Jul 29th 26 Bryce Hart


// MARK: - Summary

// The Achievement Book — the collection screen that replaced AchievementsView's
// flat 56-row List. Two things drove the redesign:
//
//  1. Unlocks no longer interrupt. Earning a badge used to slam a full-screen
//     CelebrationOverlay over whatever you were doing, mid-set included. Now the
//     unlock lands silently, the Profile tab shows a red count, and the reveal
//     waits here as a sealed slot until the user taps it — see AppStore's
//     openedAchievementIDs / openAchievement.
//  2. A list doesn't read as a collection. A paged book does: one spread per
//     category with its seven tier slots, so the empty ones look like unfilled
//     space in a stamp album rather than rows you haven't got to yet.
//
// The last page is Secrets, the home for hidden achievements. None are authored
// yet (Achievement.isSecret is false across the catalog), so it draws
// AchievementShowcase.secretSlotCount mystery slots — deliberate room for the
// feature rather than a screen that appears later out of nowhere.
struct AchievementBookView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @State private var page = 0
    // Claude  Date 07/25/2026
    // Latches the open-on-what's-new jump so it happens once per visit. Without it,
    // .onAppear re-firing (it does on any pop back into this screen) would yank the
    // user off whatever spread they were reading.
    @State private var didJumpToNew = false

    // The gender-calibrated catalog, minus secrets — those live on their own page
    // and must not leak into the category spreads.
    private var catalog: [Achievement] {
        store.achievementCatalog.filter { !$0.isSecret }
    }

    // Claude  Date 07/25/2026
    // The page to open on: the first spread holding something the user hasn't
    // revealed yet, so earning a badge and coming here lands you on it instead of
    // making you hunt. "First" is BOOK order — categories left to right, Secrets at
    // the back — not lowest-tier or most-recent, because that's the one you'd reach
    // first flipping through, and it's the only ordering the page dots make visible.
    // nil when nothing is waiting, in which case the book opens at page 0 as before.
    private var firstUnopenedPage: Int? {
        let waiting = store.unopenedAchievementIDs
        guard !waiting.isEmpty else { return nil }
        for (index, category) in categories.enumerated() {
            if catalog.contains(where: { $0.category == category && waiting.contains($0.id) }) {
                return index
            }
        }
        // Secrets sit past the category spreads and can also be the only thing new.
        if store.achievementCatalog.contains(where: { $0.isSecret && waiting.contains($0.id) }) {
            return categories.count
        }
        return nil
    }

    private var unlockedCount: Int {
        catalog.filter { store.unlockedAchievementIDs.contains($0.id) }.count
    }

    private var unopenedCount: Int { store.unopenedAchievementCount }

    private var categories: [Achievement.Category] { Achievement.Category.allCases }

    var body: some View {
        VStack(spacing: 0) {
            header

            // Claude  Date 07/24/2026
            // The pager. .always keeps the page dots visible even on a single-page
            // build, so the book always advertises how much of it there is. Index
            // dots are tinted by hand because the system default is white-on-white
            // against a light theme background.
            TabView(selection: $page) {
                ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                    AchievementBookPage(category: category, catalog: catalog)
                        .tag(index)
                }
                AchievementSecretsPage()
                    .tag(categories.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationTitle("Achievement Book")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Open straight onto the whats new. Set before the first render settles, so
            // it reads as the book opened there rather than a visible page flip.
            if !didJumpToNew {
                didJumpToNew = true
                if let target = firstUnopenedPage { page = target }
            }
            #if canImport(UIKit)
            // The page dots are UIKit-drawn and don't inherit SwiftUI's tint. This is
            // a global appearance proxy, which is safe only because this is the app's
            // one paged TabView — add another and this needs to move somewhere shared.
            UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(theme.current.accent)
            UIPageControl.appearance().pageIndicatorTintColor = UIColor(theme.current.accent.opacity(0.25))
            #endif
        }
    }

    // Claude  Date 07/24/2026
    // Fixed above the pager (not inside a page) so overall progress and the "open
    // what's waiting" action stay reachable no matter which spread you're on.
    private var header: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(unlockedCount) / \(catalog.count)")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                Text("collected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if unopenedCount > 0 {
                    Button {
                        store.openAllUnopened()
                    } label: {
                        Label("Open \(unopenedCount) new", systemImage: "sparkles")
                            .font(.footnote.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(theme.current.accent, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }

            ProgressView(value: Double(unlockedCount),
                         total: Double(max(catalog.count, 1)))
                .tint(theme.current.accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }
}

// MARK: - Category spread

// Claude  Date 07/24/2026 
// One spread: a category's seven tier slots, bronze → legend. Three columns leaves
// the seventh slot alone on its own row, which reads as album space rather than a
// layout bug — legend sitting apart is the point. Scrolls because the tallest
// locked captions overflow a 3-row grid on the smallest phones.
struct AchievementBookPage: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    let category: Achievement.Category
    let catalog: [Achievement]

    @State private var showBig3Info = false

    // Powerlifting's three competition lifts; worded to match how we track them.
    // (Carried over verbatim from AchievementsView, which this screen replaced.)
    private let big3Explanation = """
    The "Big Three" are the back squat, bench press, and conventional dead-lift (traditional stance, not sumo): the three competition lifts whose one-rep maxes add up to your total.

    Each lift has its own badge, unlocked from the heaviest weight you've logged on that lift. Do these lifts to earn special badges!
    """

    // Claude  Date 07/25/2026 last changed: 07/26/2026 by: Claude
    // Sorted low → high here rather than by walking BadgeTier.allCases and looking up
    // one achievement per tier, which is how this used to work. That lookup rendered
    // `first(where: tier)` and silently dropped anything after it, so a category with
    // two badges at the same tier would hide one — countable in the unopened total,
    // impossible to open. Driving the grid off the entries themselves means every
    // achievement in the category gets a slot, whatever the catalog does.
    private var entries: [Achievement] {
        catalog
            .filter { $0.category == category }
            .sorted { AchievementShowcase.tierRank($0.tier) < AchievementShowcase.tierRank($1.tier) }
    }

    private var earned: Int {
        entries.filter { store.unlockedAchievementIDs.contains($0.id) }.count
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                pageHeader

                LazyVGrid(columns: columns, spacing: 20) {
                    // `entries` is already tier-ordered, so the grid reads as a
                    // ladder bronze → legend.
                    ForEach(entries) { achievement in
                        AchievementSlotView(achievement: achievement)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 4)
            // Clears the pager's index dots.
            .padding(.bottom, 40)
        }
        .alert("The Big Three", isPresented: $showBig3Info) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text(big3Explanation)
        }
    }

    private var pageHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(category.title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                if category.isBig3Lift {
                    Button { showBig3Info = true } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("What is a Big-3 lift?")
                }
            }
            Text("\(earned) / \(entries.count)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Slot

// Claude  Date 07/24/2026
// One slot in the book, in one of three states:
//
//   locked            — hollow gray badge + the requirement, so the page doubles as
//                       the "what do I have to do" reference the old list was.
//   unlocked, sealed  — earned but never watched. Shows the TIER (a tease: you can
//                       see a legend is waiting) while hiding the badge art, pulses,
//                       and carries the same red dot as the tab. Tapping plays it.
//   unlocked, opened  — the real badge. Tapping replays the reveal, which costs
//                       nothing and is the whole reason unlocks stopped auto-playing.
//
// Locked slots deliberately use BadgeView(unlocked: false) rather than LockedBadge:
// that one is styled white-on-card for the profile showcase and disappears against
// a light theme background here.
struct AchievementSlotView: View {
    @EnvironmentObject private var store: AppStore

    let achievement: Achievement
    var size: CGFloat = 72

    @State private var pulse = false

    private var unlocked: Bool { store.unlockedAchievementIDs.contains(achievement.id) }
    private var opened: Bool { store.openedAchievementIDs.contains(achievement.id) }
    private var showcased: Bool { store.profile.showcasedAchievementIDs.contains(achievement.id) }

    var body: some View {
        VStack(spacing: 6) {
            badge
                .frame(width: size, height: size)

            VStack(spacing: 2) {
                HStack(spacing: 3) {
                    Text(unlocked && !opened ? "New badge" : achievement.displayTitle(unlocked: unlocked))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(unlocked ? .primary : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if showcased {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(achievement.tier.color)
                    }
                }
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 24, alignment: .top)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: tap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(unlocked ? .isButton : [])
        // Featuring a badge on the profile card used to mean a trip to Edit Profile
        // Card → Featured Badges; the pin is right here now, reusing that same store
        // call (which enforces the 4-slot cap).
        .contextMenu {
            if unlocked {
                Button {
                    _ = store.toggleShowcased(achievement.id)
                } label: {
                    Label(showcased ? "Unfeature" : "Feature on card",
                          systemImage: showcased ? "pin.slash" : "pin")
                }
            }
        }
    }

    @ViewBuilder
    private var badge: some View {
        if unlocked && !opened {
            sealed
        } else {
            BadgeView(icon: achievement.icon, tier: achievement.tier,
                      unlocked: unlocked, size: size, glimmer: unlocked)
        }
    }

    // Claude  Date 07/24/2026 - Edited Bryce Hart Jul 29 26
    // The sealed state: the tier's own material with a sparkle standing in for the
    // category glyph, so the badge's identity stays a surprise until it's opened.
    // The breathing ring is what draws the eye down the page to what's new.
    // EDIT (jul 29 26) - rewrote text and fixed formatting.
    private var sealed: some View {
        ZStack {
            Circle()
                .stroke(achievement.tier.color.opacity(0.55), lineWidth: 2)
                .scaleEffect(pulse ? 1.22 : 1)
                .opacity(pulse ? 0 : 0.9)

            Circle().fill(achievement.tier.fillGradient)
            Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)

            Image(systemName: "sparkles")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.28), radius: 1, y: 0.5)
        }
        .shadow(color: achievement.tier.color.opacity(0.55), radius: size * 0.14)
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                .offset(x: 2, y: -2)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }

    private var caption: String {
        if !unlocked { return achievement.displayDetail(unlocked: false) }
        return opened ? achievement.tier.title : "Tap to reveal"
    }

    private var accessibilityLabel: String {
        if !unlocked { return "Locked. \(achievement.displayDetail(unlocked: false))" }
        if !opened { return "New \(achievement.tier.title) badge. Tap to reveal." }
        return "\(achievement.title), \(achievement.tier.title). Tap to replay."
    }

    private func tap() {
        guard unlocked else { return }
        // Opening marks it seen (on dismiss); replaying leaves persisted state alone.
        if opened {
            store.replayCelebration(achievement)
        } else {
            store.openAchievement(achievement)
        }
    }
}

// MARK: - Secrets

// Peer review Bryce Hart Jul 29, 26
// The back of the book. Any catalog entry flagged isSecret lands here instead of
// its category spread, concealed behind displayTitle/displayDetail until earned;
// the remaining slots are drawn as empty mystery placeholders so the page reads as
// reserved space. Nothing is authored yet — the first secret needs no change here,
// only an `isSecret: true` entry in Achievement.build.
struct AchievementSecretsPage: View {
    @EnvironmentObject private var store: AppStore

    private var secrets: [Achievement] {
        store.achievementCatalog.filter(\.isSecret)
    }

    private var found: Int {
        secrets.filter { store.unlockedAchievementIDs.contains($0.id) }.count
    }

    // Real secrets fill from the front; the rest of the row stays a question mark.
    private var slotCount: Int { max(AchievementShowcase.secretSlotCount, secrets.count) }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text("Secrets")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text("\(found) / \(slotCount) discovered")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Text("Secret achievements are unlocked as you use Agil. Keep coming back to unlock more secrets!")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(0..<slotCount, id: \.self) { index in
                        if index < secrets.count {
                            AchievementSlotView(achievement: secrets[index])
                        } else {
                            MysterySlot()
                        }
                    }
                }
                .padding(.horizontal, 20)

                Text("Feature up to \(AchievementShowcase.maxFeatured) badges on your profile card: press and hold any badge you've earned.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
    }
}

// Claude  Date 07/24/2026
// An empty reserved slot: no tier, no colour, nothing to read into. Sized to match
// AchievementSlotView so the grid stays even where the two mix.
private struct MysterySlot: View {
    var size: CGFloat = 72

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.4),
                            style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                Image(systemName: "questionmark")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
            .opacity(0.6)

            VStack(spacing: 2) {
                Text("???")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Undiscovered")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 24, alignment: .top)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Undiscovered secret achievement")
    }
}

#Preview {
    NavigationStack { AchievementBookView() }
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
