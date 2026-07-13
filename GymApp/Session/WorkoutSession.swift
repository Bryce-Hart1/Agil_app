import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
import AudioToolbox
#endif

// Claude  Date 06/16/2026
// Live state for an in-progress workout that must outlive the editor view: the
// rest-timer countdown (so it keeps running and shows in the global mini-bar after
// you navigate away) and a small navigation hand-off the mini-bar uses to ask the
// Workouts list to reopen the active workout. Injected app-wide like AppStore/
// ThemeManager. The active *workout* itself lives in AppStore.workouts; this object
// only owns transient session state.
@MainActor
final class WorkoutSession: ObservableObject {
    // MARK: Rest timer
    @Published private(set) var restTotal = 0
    @Published private(set) var restRemaining = 0
    @Published private(set) var isResting = false
    // Brief "Rest complete" state shown in the bar after a timer finishes.
    @Published private(set) var showRestComplete = false
    // Claude  Date 07/11/2026
    // Tap-to-expand full-screen countdown. Set by the mini-bar/inline rest row while
    // resting; read by RootTabView's fullScreenCover. Plain toggle, not tied to a
    // specific rest period, so it just closes itself if rest ends or is skipped.
    @Published var showFullScreenTimer = false

    // MARK: Navigation hand-off
    // Set by the mini-bar; the Workouts list observes it and pushes that workout,
    // then clears it. Lets a tap anywhere in the app jump back into the session.
    @Published var requestedWorkoutID: UUID?

    // Claude  Date 06/16/2026
    // The workout editor currently on screen (nil = none). Set by WorkoutDetailView
    // while it's visible. The mini-bar hides itself for this workout — no point
    // offering "return to your workout" when you're already in it.
    @Published var viewingWorkoutID: UUID?

    private var timer: Timer?
    private var hideCompleteWork: DispatchWorkItem?
    // Claude  Date 06/18/2026
    // The wall-clock instant the current rest ends. The countdown is derived from this
    // (now → end) rather than decremented tick-by-tick, so it stays correct across
    // backgrounding / locking the phone: while suspended the Timer doesn't fire, but the
    // end time is fixed, so on return refreshRest() shows the real remaining (or finishes).
    private var restEndDate: Date?

    /// 0…1 fraction of the rest elapsed — drives the bar's sweeping progress fill.
    var restProgress: Double {
        restTotal > 0 ? Double(restTotal - restRemaining) / Double(restTotal) : 0
    }

    // Claude  Date 06/16/2026 last changed: 06/18/2026 by: Claude
    // Start (or restart) the rest countdown. Anchors a wall-clock end time so the
    // remaining time is computed from the clock (survives backgrounding); the Timer
    // just refreshes the display each second while we're on screen.
    func startRest(seconds: Int) {
        guard seconds > 0 else { return }
        cancelHide()
        restTotal = seconds
        restRemaining = seconds
        let end = Date().addingTimeInterval(TimeInterval(seconds))
        restEndDate = end
        isResting = true
        showRestComplete = false
        startTimer()
        // Claude  Date 07/11/2026
        // Alert even if the phone gets locked/backgrounded before rest ends.
        WorkoutNotifications.scheduleRestComplete(at: end)
    }

    func skipRest() {
        stopTimer()
        restEndDate = nil
        isResting = false
        restRemaining = 0
        showRestComplete = false
        showFullScreenTimer = false
        WorkoutNotifications.cancelRestComplete()
    }

    // Claude  Date 06/18/2026
    // Recompute the remaining time from the wall-clock end date, completing if it has
    // already elapsed. Called every tick AND whenever the app returns to the foreground
    // (see RootTabView), so a rest that ran out while the phone was backgrounded/locked
    // finishes correctly instead of resuming frozen.
    func refreshRest() {
        guard isResting, let end = restEndDate else { return }
        let remaining = Int(ceil(end.timeIntervalSinceNow))
        if remaining > 0 {
            restRemaining = remaining
        } else {
            completeRest()
        }
    }

    func dismissRestComplete() {
        cancelHide()
        showRestComplete = false
    }

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        refreshRest()
    }

    // Finish the rest: clear state, buzz + chime, and show the brief "Rest complete" message.
    private func completeRest() {
        restRemaining = 0
        restEndDate = nil
        isResting = false
        stopTimer()
        showRestComplete = true
        // The app was open at this exact moment, so the in-app haptic/chime below cover
        // it — no need for the OS banner too (it's cleared if already delivered while
        // backgrounded).
        WorkoutNotifications.cancelRestComplete()
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        // Claude  Date 07/11/2026
        // The app's first sound anywhere (previously haptics-only) — a short, non-
        // alarming system chime so rest completion is audible with the phone face-down.
        AudioServicesPlaySystemSound(1005)
        #endif
        scheduleHide()
    }

    // Auto-hide the "Rest complete" message after a few seconds, and collapse the
    // full-screen timer along with it (nothing left to show once it hides).
    private func scheduleHide() {
        cancelHide()
        let work = DispatchWorkItem { [weak self] in
            self?.showRestComplete = false
            self?.showFullScreenTimer = false
        }
        hideCompleteWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    private func cancelHide() {
        hideCompleteWork?.cancel()
        hideCompleteWork = nil
    }
}
