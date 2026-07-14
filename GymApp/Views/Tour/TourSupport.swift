import SwiftUI

// Claude  Date 07/14/2026
// Spotlight-tour plumbing: the targets a tour step can highlight, the anchor
// PreferenceKey views use to report their frames, the .tourTarget modifier that
// opts a view in, and the tour script itself. The overlay that consumes all of
// this is TourOverlay (rendered by RootTabView while store.tourActive).

// Claude  Date 07/14/2026
// Everything the tour can point at. In-content views (the profile card) report
// exact frames via .tourTarget + TourAnchorKey. UIKit-hosted chrome — native
// TabView items and the ModeNotch toolbar principal item — can't carry SwiftUI
// preferences, so those targets synthesize an approximate frame instead (see
// fallbackFrame). The overlay resolves preference-first, fallback second.
enum TourTarget: String, Hashable {
    case modeNotch
    case tabWorkouts, tabBuild, tabProgress, tabProfile   // lifting world
    case tabJournal                                       // nutrition world
    case profileCard

    // Claude  Date 07/14/2026 last changed: 07/14/2026 by: Claude
    // Approximate frame for chrome targets, in FULL-SCREEN coordinates. `insets`
    // are the REAL device safe-area insets (read from the key window by
    // RootTabView — the overlay's own GeometryReader ignores safe area, which
    // zeroes proxy.safeAreaInsets; that zeroing is what mis-placed the first cut
    // of these frames). Geometry facts, measured against the iOS 26 floating tab
    // bar on an iPhone 16 Pro:
    //  - Tab items sit as a group CENTERED on the screen's midline with a fixed
    //    ~86pt center-to-center pitch (both the 4-tab lifting bar and the 3-tab
    //    nutrition bar measure the same pitch — the floating bar hugs its content
    //    rather than dividing the full width). The item row (icon + label) spans
    //    roughly the 40pt band just above the bottom safe inset.
    //  - The ModeNotch pill is the nav bar's centered principal item, starting
    //    ~8pt below the top safe inset, ~36pt tall and ~210pt wide.
    // Still approximations — the cutout padding in TourOverlay absorbs the last
    // few points of device-to-device drift.
    func fallbackFrame(size: CGSize, insets: EdgeInsets, mode: AppMode) -> CGRect? {
        let pitch: CGFloat = 86
        let itemWidth: CGFloat = 76
        let itemHeight: CGFloat = 44

        func tabRect(index: Int, of count: Int) -> CGRect {
            let centerX = size.width / 2
                + (CGFloat(index) - CGFloat(count - 1) / 2) * pitch
            return CGRect(x: centerX - itemWidth / 2,
                          y: size.height - insets.bottom - 40,
                          width: itemWidth, height: itemHeight)
        }

        switch self {
        case .modeNotch:
            let width: CGFloat = min(210, size.width * 0.6)
            return CGRect(x: (size.width - width) / 2, y: insets.top + 8,
                          width: width, height: 36)
        case .tabWorkouts: return mode == .lifting ? tabRect(index: 0, of: 4) : nil
        case .tabBuild:    return mode == .lifting ? tabRect(index: 1, of: 4) : nil
        case .tabProgress: return mode == .lifting ? tabRect(index: 2, of: 4) : nil
        case .tabProfile:
            return mode == .lifting ? tabRect(index: 3, of: 4) : tabRect(index: 2, of: 3)
        case .tabJournal:  return mode == .nutrition ? tabRect(index: 0, of: 3) : nil
        case .profileCard:
            // In-content target: no synthesized fallback — it must come from the
            // anchor preference (the overlay shows a centered card if it's missing).
            return nil
        }
    }
}

// Claude  Date 07/14/2026
// Collects [target: frame-anchor] pairs from any view tagged .tourTarget(_:),
// merged up the tree. RootTabView reads it with .overlayPreferenceValue.
struct TourAnchorKey: PreferenceKey {
    static var defaultValue: [TourTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [TourTarget: Anchor<CGRect>],
                       nextValue: () -> [TourTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    // Claude  Date 07/14/2026
    // Opt this view in as a tour spotlight target. Cheap when no tour is running —
    // it's just a preference entry.
    func tourTarget(_ target: TourTarget) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [target: $0] }
    }
}

// Claude  Date 07/14/2026
// One stop on the tour. `target == nil` means a free-floating centered card with
// a full dim (used for the intro/outro). `mode`/`tab` describe the app state the
// step needs; RootTabView applies them (switching worlds/tabs) as the tour
// advances, so the spotlight always points at something that's on screen.
struct TourStep: Identifiable {
    let id: String
    let target: TourTarget?
    let title: String
    let message: String
    let mode: AppMode
    let tab: Int?
}

// Claude  Date 07/14/2026
// The first-boot tour script: intro → the ModeNotch world-switcher → the four
// lifting tabs → the Food world's Journal → outro (which lands back on Workouts).
// Copy leans on the app's existing vocabulary ("worlds", coins, badges).
enum TourScript {
    static let steps: [TourStep] = [
        TourStep(
            id: "intro", target: nil,
            title: "Welcome to Agil",
            message: "Here's a 30-second tour of where everything lives. Tap anywhere to continue, or skip and explore on your own.",
            mode: .lifting, tab: 1),
        TourStep(
            id: "modeNotch", target: .modeNotch,
            title: "Two worlds, one pill",
            message: "This pill switches between the Lifting and Food worlds. It always shows where you are, with the other world's key stat riding along.",
            mode: .lifting, tab: 1),
        TourStep(
            id: "workouts", target: .tabWorkouts,
            title: "Workouts",
            message: "Start and log your training sessions here. Finishing a workout earns coins and drives your badges and streaks.",
            mode: .lifting, tab: 1),
        TourStep(
            id: "build", target: .tabBuild,
            title: "Build",
            message: "Create workout presets — reusable templates — and manage your exercise library from here.",
            mode: .lifting, tab: 2),
        TourStep(
            id: "progress", target: .tabProgress,
            title: "Progress",
            message: "Charts and trends from everything you've logged: volume, best lifts, and how your training is moving.",
            mode: .lifting, tab: 3),
        TourStep(
            id: "profile", target: .tabProfile,
            title: "Profile",
            message: "Your card, featured badges, Strategist rank, and coins live here — along with the Shop and Settings.",
            mode: .lifting, tab: 4),
        TourStep(
            id: "journal", target: .tabJournal,
            title: "The Food world",
            message: "Over in Food, the Journal tracks meals, water, and calories day by day — staying on goal earns badges too.",
            mode: .nutrition, tab: 1),
        TourStep(
            id: "outro", target: nil,
            title: "You're all set",
            message: "That's the lay of the land. You can replay this tour anytime from Settings. Now go lift something.",
            mode: .lifting, tab: 1),
    ]
}
