import SwiftUI

// Spotlight-tour plumbing: the targets a tour step can highlight, the anchor
// PreferenceKey views use to report their frames, the .tourTarget modifier that
// opts a view in, and the tour script itself. The overlay that consumes all of
// this is TourOverlay (rendered by RootTabView while store.tourActive).

// Claude  Date 07/14/2026 last changed: 07/27/2026 by: Claude
// Everything the tour can point at. In-content views (the profile card) report
// exact frames via .tourTarget + TourAnchorKey — and so do the tab targets now
// that the bottom bar is our own AgilTabBar rather than the native, UIKit-hosted
// tab items. The ModeNotch (a toolbar principal item) is still UIKit-hosted and
// can't carry a SwiftUI preference. (07/27) It no longer settles for a synthesized
// rect either: it reports frame(in: .global) through TourFrames, which crosses the
// UIKit boundary that preferences can't. The overlay resolves anchor first, global
// registry second, fallbackFrame third.
// (07/28) The Workouts screen's two start-a-workout buttons and the Profile screen's
// Achievements/Settings buttons are toolbar items too, so they take the same
// global-registry route as the notch.
enum TourTarget: String, Hashable {
    case modeNotch
    case newBlankWorkout, newFromPreset                   // Workouts nav bar
    case profileAchievements, profileSettings             // Profile nav bar
    case tabWorkouts, tabBuild, tabProgress, tabProfile   // lifting world
    case tabJournal                                       // nutrition world
    case profileCard

    // Claude  Date 07/14/2026 last changed: 07/21/2026 by: Claude
    // Approximate frame for chrome targets, in FULL-SCREEN coordinates. `insets`
    // are the REAL device safe-area insets (read from the key window by
    // RootTabView — the overlay's own GeometryReader ignores safe area, which
    // zeroes proxy.safeAreaInsets; that zeroing is what mis-placed the first cut
    // of these frames). Geometry facts:
    //  - The tab targets are now BACKSTOPS ONLY: since the bottom bar became our
    //    own AgilTabBar, its buttons report exact frames via .tourTarget, and the
    //    overlay prefers those. The synthesized rects match that bar's layout —
    //    cells split the full width evenly, in a AgilTabBar.contentHeight band
    //    sitting directly on top of the bottom safe inset. (They used to model
    //    the iOS 26 floating pill, which hugged its content on the midline with a
    //    fixed ~86pt pitch; that geometry no longer exists in the app.)
    //  - The ModeNotch case is a LAST-RESORT BACKSTOP as of 07/27, not the live
    //    path: the notch now reports its real frame via TourFrames. Its numbers
    //    were never right — the pill hugs its content (so the monospaced theme font
    //    widens it well past 210), it's ~33pt tall centered in the 44pt bar rather
    //    than 36pt at +8, and UIKit shifts a principal item off-center to make room
    //    for the screen's own trailing button. Kept only so a step still points
    //    somewhere sane if the registry is ever empty.
    // Still approximations — the spotlight's soft falloff in TourOverlay absorbs the
    // last few points of device-to-device drift.
    func fallbackFrame(size: CGSize, insets: EdgeInsets, mode: AppMode) -> CGRect? {
        let barHeight = AgilTabBar.contentHeight
        let itemHeight: CGFloat = 44

        func tabRect(index: Int, of count: Int) -> CGRect {
            let cellWidth = size.width / CGFloat(count)
            let itemWidth = min(76, cellWidth)
            let centerX = cellWidth * (CGFloat(index) + 0.5)
            return CGRect(x: centerX - itemWidth / 2,
                          y: size.height - insets.bottom - barHeight + (barHeight - itemHeight) / 2,
                          width: itemWidth, height: itemHeight)
        }

        switch self {
        case .modeNotch:
            let width: CGFloat = min(210, size.width * 0.6)
            return CGRect(x: (size.width - width) / 2, y: insets.top + 8,
                          width: width, height: 36)
        // Claude  Date 07/28/2026
        // No synthesized rect for the Workouts toolbar buttons: they report real
        // frames through TourFrames, and inventing coordinates for a nav bar is
        // exactly the mistake the .modeNotch case above documents. A nil frame
        // degrades to a centered card with a full dim — honest about not knowing
        // where the control is, rather than confidently pointing at empty space.
        case .newBlankWorkout, .newFromPreset,
             .profileAchievements, .profileSettings:
            return nil
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
    // Opt this view in as a tour spotlight target. Cheap when no tour is running —
    // it's just a preference entry.
    func tourTarget(_ target: TourTarget) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [target: $0] }
    }
}

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

// Bryce Hart Jul 16
// went in and humanized this text.
enum TourScript {
    static let steps: [TourStep] = [
        TourStep(
            id: "intro", target: nil,
            title: "Hello, welcome to Agil!",
            message: "Here's a quick tour of where everything lives. Tap anywhere to continue, or skip and explore on your own.",
            mode: .lifting, tab: 1),
        TourStep(
            id: "modeNotch", target: .modeNotch,
            title: "The Notch",
            message: "This notch switches between the Lifting and Food sides. It always shows where you are, with the other's key stat sitting in the top.",
            mode: .lifting, tab: 1),
        TourStep(
            id: "workouts", target: .tabWorkouts,
            title: "Workouts",
            message: "Start and log your training sessions here. Finishing a workout earns coins and drives your badges and streaks.",
            mode: .lifting, tab: 1),
        // Claude  Date 07/28/2026
        // The two ways to start a workout, taken right after the Workouts tab step
        // — the user has just been told what the tab is, so now we open its drawer.
        // Both stay on that tab, so the spotlight only travels from the bar up to
        // the nav bar and back down again once.
        TourStep(
            id: "newBlankWorkout", target: .newBlankWorkout,
            title: "Start from scratch",
            message: "A blank workout you fill in as you go — add lifts and sets while you train.",
            mode: .lifting, tab: 1),
        TourStep(
            id: "newFromPreset", target: .newFromPreset,
            title: "Start from a preset",
            message: "Pick one of your saved presets and it comes pre-filled. Build them over in Build, or lift one from the premade catalog.",
            mode: .lifting, tab: 1),
        TourStep(
            id: "build", target: .tabBuild,
            title: "Build",
            message: "Create workout presets: reusable templates, and manage your own custom library here",
            mode: .lifting, tab: 2),
        TourStep(
            id: "progress", target: .tabProgress,
            title: "Progress",
            message: "Charts and trends from everything you've logged: volume, best lifts, and how your training is moving.",
            mode: .lifting, tab: 3),
        TourStep(
            id: "profile", target: .tabProfile,
            title: "Profile",
            message: "Your card, featured badges, rank, and coins live here, along with the Shop and Settings.",
            mode: .lifting, tab: 4),
        // Claude  Date 07/28/2026
        // The Profile screen's two nav-bar shortcuts, taken straight after the
        // Profile tab step — same pattern as the Workouts pair: name the tab, then
        // open its drawer. Both stay on tab 4, so the spotlight travels up to the
        // nav bar and back down once.
        TourStep(
            id: "profileAchievements", target: .profileAchievements,
            title: "Achievements",
            message: "Every badge you've earned lives in the book. The red count is how many you haven't opened yet.",
            mode: .lifting, tab: 4),
        TourStep(
            id: "profileSettings", target: .profileSettings,
            title: "Settings",
            message: "Themes, your identity, replaying this tour — it's all in here, and further down this page too.",
            mode: .lifting, tab: 4),
        TourStep(
            id: "journal", target: .tabJournal,
            title: "The Food Side",
            message: "Over in Food, the Journal tracks meals, water, and calories day by day, staying on goal earns badges too.",
            mode: .nutrition, tab: 1),
        TourStep(
            id: "outro", target: nil,
            title: "You're all set",
            message: "That's the lay of the land. You can replay this tour anytime from Settings. Thanks for downloading Agil, Enjoy :)",
            mode: .lifting, tab: 1),
    ]
}
