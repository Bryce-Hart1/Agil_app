import SwiftUI

// Claude  Date 07/21/2026
// The app's own bottom tab bar: a SOLID, full-width rectangle flush with the
// bottom edge (Spotify / Instagram / adidas Running style), replacing the iOS 26
// floating "liquid glass" pill the system TabView draws. The system bar can't be
// made opaque/edge-to-edge under iOS 26's design (UITabBarAppearance background
// customisation is ignored there), so RootTabView hides it with
// .toolbar(.hidden, for: .tabBar) on every tab and mounts this as a bottom
// safe-area inset instead. Both worlds (lifting + nutrition) use it — the item
// list is the only thing that differs.

// Claude  Date 07/21/2026
// One bar item. Declared once and used for BOTH the (hidden) native .tabItem and
// this bar, so the icon/title for a tab lives in exactly one place. `tour` is the
// spotlight target the tour points at, if any — the buttons report real frames
// now, where the native tab items could only be approximated (see TourTarget).
struct AgilTabItem: Identifiable, Hashable {
    /// Matches the `.tag(_:)` on the matching TabView child.
    let tag: Int
    let title: String
    let icon: Icon
    let tour: TourTarget?

    // Icons are a mix of SF Symbols and Bryce's custom template assets.
    enum Icon: Hashable {
        case system(String)
        case asset(String)
    }

    var id: Int { tag }

    // Claude  Date 07/21/2026
    // The icon at bar size. Custom assets are vector SVGs with a template
    // rendering intent, so they resize cleanly and pick up the tint; SF Symbols
    // are left as text-sized glyphs (resizing those throws off their optical
    // weight). Both land in the same 26pt box so the row stays on one baseline.
    @ViewBuilder var image: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 21, weight: .regular))
                .frame(width: 26, height: 26)
        case .asset(let name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .frame(width: 26, height: 26)
        }
    }

    /// The label handed to the native `.tabItem` (kept as a safety net in case a
    /// future OS ignores the hide-the-tab-bar request).
    var label: some View {
        Label { Text(title) } icon: { icon.plainImage }
    }
}

extension AgilTabItem.Icon {
    // Unstyled image, for the native tab item (UIKit does its own sizing there).
    @ViewBuilder var plainImage: some View {
        switch self {
        case .system(let name): Image(systemName: name)
        case .asset(let name):  Image(name)
        }
    }
}

// Claude  Date 07/21/2026
// The two worlds' tab sets. Tags match the `.tag(_:)` values in RootTabView (and
// the persisted liftingTab / nutritionTab), so they start at 1 in both worlds.
extension AgilTabItem {
    static let workouts = AgilTabItem(tag: 1, title: "Workouts",
                                      icon: .system("dumbbell"), tour: .tabWorkouts)
    static let build = AgilTabItem(tag: 2, title: "Build",
                                   icon: .asset("hammer"), tour: .tabBuild)
    static let progress = AgilTabItem(tag: 3, title: "Progress",
                                      icon: .asset("chart-scatter"), tour: .tabProgress)
    static let liftingProfile = AgilTabItem(tag: 4, title: "Profile",
                                            icon: .asset("user-circle-dashed"), tour: .tabProfile)

    static let journal = AgilTabItem(tag: 1, title: "Journal",
                                     icon: .asset("notepad"), tour: .tabJournal)
    static let foods = AgilTabItem(tag: 2, title: "Foods",
                                   icon: .asset("orange"), tour: nil)
    static let nutritionProfile = AgilTabItem(tag: 3, title: "Profile",
                                              icon: .asset("user-circle-dashed"), tour: .tabProfile)

    static func items(for mode: AppMode) -> [AgilTabItem] {
        switch mode {
        case .lifting:   return [.workouts, .build, .progress, .liftingProfile]
        case .nutrition: return [.journal, .foods, .nutritionProfile]
        }
    }
}

struct AgilTabBar: View {
    @EnvironmentObject private var theme: ThemeManager

    let items: [AgilTabItem]
    @Binding var selection: Int

    // Claude  Date 07/21/2026
    // Height of the item row — everything ABOVE the home-indicator inset, which
    // the bar's background fills separately. TourTarget.fallbackFrame reads this
    // so a synthesized tab spotlight lands on the real bar.
    static let contentHeight: CGFloat = 54

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button {
                    guard selection != item.tag else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selection = item.tag
                } label: {
                    cell(for: item)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selection == item.tag ? [.isButton, .isSelected] : .isButton)
                // Claude  Date 07/21/2026
                // Real spotlight frames for the tour (the native tab items are
                // UIKit-hosted and couldn't carry a SwiftUI preference).
                .modifier(TourTargetIfPresent(target: item.tour))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.contentHeight)
        // Claude  Date 07/21/2026
        // The solid slab. `.ignoresSafeArea(edges: .bottom)` on the fill (not on
        // the bar itself) is what makes it read as flush with the bottom of the
        // screen: the colour runs under the home indicator while the icons stay
        // above it. The hairline is the only edge — no rounding, no shadow.
        .background(alignment: .top) {
            theme.current.surface
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(height: 0.5)
        }
    }

    // Claude  Date 07/21/2026
    // One tab cell. Cells split the width evenly (maxWidth: .infinity), which is
    // what gives the bar its even, edge-to-edge rhythm. Selected = accent tint +
    // a heavier label; unselected = secondary. contentShape makes the whole cell
    // tappable, not just the icon and text.
    private func cell(for item: AgilTabItem) -> some View {
        let isSelected = selection == item.tag
        return VStack(spacing: 3) {
            item.image
            Text(item.title)
                // Claude  Date 07/21/2026 — 11pt (was 10): the native bar's 10pt
                // felt undersized once the labels were ours to set. The scale
                // factor is the guard for the longest label ("Workouts") in the
                // 4-tab lifting bar, which is the tightest cell in the app.
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(isSelected ? AnyShapeStyle(theme.current.accent)
                                    : AnyShapeStyle(Color.secondary))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

// Claude  Date 07/21/2026 last changed: 07/21/2026 by: Claude
// What a RootTabView tab needs: the native tab item + tag (kept as a fallback but
// normally invisible) and the hide-the-native-tab-bar request that lets our bar
// stand in for the iOS 26 floating glass pill.
//
// Neither bar is mounted here. Both were, as safe-area insets, through two attempts
// that drew correctly but left pages scrolling under them — insets applied outside a
// NavigationStack don't reach what it pushes. RootTabView now stacks the bars under
// a shortened TabView instead, which is geometry rather than plumbing; see the note
// on its `body`.
extension View {
    func agilTab(_ item: AgilTabItem) -> some View {
        self
            .toolbar(.hidden, for: .tabBar)
            .tabItem { item.label }
            .tag(item.tag)
    }
}

// Claude  Date 07/21/2026
// Applies .tourTarget only when the item actually has a spotlight target — a
// modifier because you can't conditionally apply one inline without changing the
// view's type identity (which would remount the button).
private struct TourTargetIfPresent: ViewModifier {
    let target: TourTarget?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let target {
            content.tourTarget(target)
        } else {
            content
        }
    }
}

#Preview {
    VStack {
        Spacer()
        AgilTabBar(items: AgilTabItem.items(for: .lifting), selection: .constant(1))
    }
    .background(AppTheme.classic.background)
    .environmentObject(ThemeManager())
}
