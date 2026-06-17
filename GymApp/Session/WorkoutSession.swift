import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
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

    /// 0…1 fraction of the rest elapsed — drives the bar's sweeping progress fill.
    var restProgress: Double {
        restTotal > 0 ? Double(restTotal - restRemaining) / Double(restTotal) : 0
    }

    // Claude  Date 06/16/2026
    // Start (or restart) the rest countdown. Runs on the common run-loop mode so it
    // keeps ticking while lists scroll.
    func startRest(seconds: Int) {
        guard seconds > 0 else { return }
        cancelHide()
        restTotal = seconds
        restRemaining = seconds
        isResting = true
        showRestComplete = false
        startTimer()
    }

    func skipRest() {
        stopTimer()
        isResting = false
        restRemaining = 0
        showRestComplete = false
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
        guard isResting else { return }
        if restRemaining > 1 {
            restRemaining -= 1
        } else {
            restRemaining = 0
            isResting = false
            stopTimer()
            showRestComplete = true
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            scheduleHide()
        }
    }

    // Auto-hide the "Rest complete" message after a few seconds.
    private func scheduleHide() {
        cancelHide()
        let work = DispatchWorkItem { [weak self] in self?.showRestComplete = false }
        hideCompleteWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    private func cancelHide() {
        hideCompleteWork?.cancel()
        hideCompleteWork = nil
    }
}
