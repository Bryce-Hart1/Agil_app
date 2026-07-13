import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 06/12/2026
// Rest-duration helpers shared by the preset editor (picker) and the workout
// editor (live timer).
enum RestDuration {
    static let options = [30, 45, 60, 75, 90, 120, 150, 180, 240, 300]

    static func label(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// Claude  Date 06/12/2026 last changed: 06/16/2026 by: Claude
// A rest control for one exercise in the workout editor. Start/Skip now drive the
// shared WorkoutSession (not local @State), so the countdown survives navigating
// away from the workout and is mirrored in the global mini-bar. Display reflects the
// session's single live timer; the haptic on completion fires in WorkoutSession.
struct RestTimerView: View {
    let duration: Int
    let accent: Color
    @EnvironmentObject private var session: WorkoutSession

    var body: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(session.isResting ? accent : .secondary)

            Text(session.isResting
                 ? "Resting \(RestDuration.label(session.restRemaining))"
                 : "Rest \(RestDuration.label(duration))")
                .monospacedDigit()
                .foregroundStyle(session.isResting ? .primary : .secondary)

            Spacer()

            if session.isResting {
                // Claude  Date 07/11/2026
                // Visual hint that tapping the row expands to the full-screen timer
                // (see .onTapGesture below — this icon has no gesture of its own).
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Skip") { session.skipRest() }
                    .buttonStyle(.bordered)
            } else {
                Button { session.startRest(seconds: duration) } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .tint(accent)
            }
        }
        // Claude  Date 07/11/2026
        // Tap the row (not Skip) while resting to expand the full-screen timer.
        .contentShape(Rectangle())
        .onTapGesture {
            guard session.isResting else { return }
            session.showFullScreenTimer = true
        }
    }
}
