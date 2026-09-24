import SwiftUI

// Claude  Date 07/27/2026
// The escape hatch for tour targets that can't carry a preference anchor.
//
// .tourTarget uses anchorPreference (see TourSupport), and preferences don't
// propagate out of a UIKit-hosted container — which is exactly where the ModeNotch
// lives, as a ToolbarItem(placement: .principal) inside a UINavigationBar. Before
// this, the notch step fell back to a hand-written rect that was wrong in width,
// height, x-center AND y: the pill hugs its content (so the theme's monospaced font
// widens it), it's ~33pt tall centered in the 44pt bar rather than 36pt at +8, and
// UIKit shifts a principal item off-center to make room for the screen's own
// trailing button. The spotlight landed on the "+" instead.
//
// frame(in: .global) crosses that boundary fine. .global is the window's coordinate
// space, which is the SAME space TourOverlay resolves anchors in — RootTabView's
// overlay GeometryReader calls .ignoresSafeArea(), putting its origin at the window's
// top-left. So a global frame and a resolved anchor are directly comparable; no
// inset math is needed on either side.
//
// Deliberately NOT part of AppStore: this republishes on layout changes, and AppStore
// drives the entire app. Only the overlay observes it, and only while a tour runs.
final class TourFrames: ObservableObject {
    @Published var frames: [TourTarget: CGRect] = [:]
}

// Claude  Date 07/27/2026
// Carried as an EnvironmentKey rather than an @EnvironmentObject specifically so it
// has a default: every root screen mounts the ModeNotch, and each one has an Xcode
// preview that doesn't build a RootTabView. A missing @EnvironmentObject traps at
// render time, which would have meant injecting this into six previews that have no
// interest in the tour. Reporters only ever WRITE, so they don't need to observe the
// object — RootTabView owns it as a @StateObject and observes it from there.
private struct TourFramesKey: EnvironmentKey {
    static let defaultValue = TourFrames()
}

extension EnvironmentValues {
    var tourFrames: TourFrames {
        get { self[TourFramesKey.self] }
        set { self[TourFramesKey.self] = newValue }
    }
}

// Claude  Date 07/28/2026
// The selected tab's tag, published by RootTabView.
//
// Every root screen mounts its own ModeNotch, and a TabView keeps visited tabs
// alive — so four notches can be reporting to the same .modeNotch key at once, and
// last-writer-wins decided where the spotlight went. That was not academic: the
// pill's real x differs per screen, because UIKit centers a principal item in the
// space the bar buttons leave (Workouts has only a trailing +, Build has a wide
// leading link), so the tour could light up a frame from a screen the user wasn't
// looking at. A notch compares this against its own tab and only reports when it's
// the visible one.
//
// CLAUDE  Date 09/20/2026
// Screen tags are globally unique (Journal is 11, Workouts 1), so this alone identifies
// the on-screen tab in either world.
private struct ActiveTabTagKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var activeTabTag: Int {
        get { self[ActiveTabTagKey.self] }
        set { self[ActiveTabTagKey.self] = newValue }
    }
}

extension View {
    // Claude  Date 07/27/2026
    // Report this view's frame into the registry above. Use ONLY for targets that
    // can't use .tourTarget — everything else should stay on the preference path,
    // which needs no gating and no shared object.
    //
    // `active` should be store.tourActive: with no tour running the reader is inert,
    // so an unrelated animation over this view doesn't publish a CGRect per frame to
    // an object the whole overlay observes. Writes happen in onAppear/onChange, never
    // inline in body, so this never mutates observable state during a view update.
    func tourTargetGlobal(_ target: TourTarget, active: Bool) -> some View {
        modifier(TourGlobalFrameReporter(target: target, active: active))
    }
}

private struct TourGlobalFrameReporter: ViewModifier {
    let target: TourTarget
    let active: Bool

    @Environment(\.tourFrames) private var tourFrames

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { report(geo.frame(in: .global)) }
                    .onChange(of: geo.frame(in: .global)) { report($0) }
                    // The tour can start long after this view appeared (it's
                    // replayable from Settings), and the notch's frame won't
                    // change just because the tour began — so publish on the
                    // gate flipping too, not only on layout.
                    .onChange(of: active) { _ in report(geo.frame(in: .global)) }
            }
        )
    }

    private func report(_ frame: CGRect) {
        guard active, tourFrames.frames[target] != frame else { return }
        tourFrames.frames[target] = frame
    }
}
