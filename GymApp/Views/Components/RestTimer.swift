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

// Claude  Date 06/12/2026
// A live rest countdown for one exercise in the workout editor. Tap Start to
// count down from `duration`; Skip cancels. Fires a success haptic at zero.
// (Foreground only — the timer pauses if the app is backgrounded.)
struct RestTimerView: View {
    let duration: Int
    let accent: Color

    @State private var remaining = 0
    @State private var isRunning = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(isRunning ? accent : .secondary)

            Text(isRunning
                 ? "Resting \(RestDuration.label(remaining))"
                 : "Rest \(RestDuration.label(duration))")
                .monospacedDigit()
                .foregroundStyle(isRunning ? .primary : .secondary)

            Spacer()

            if isRunning {
                Button("Skip") { isRunning = false }
                    .buttonStyle(.bordered)
            } else {
                Button { start() } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .tint(accent)
            }
        }
        .onReceive(ticker) { _ in tick() }
    }

    private func start() {
        remaining = duration
        isRunning = true
    }

    private func tick() {
        guard isRunning else { return }
        if remaining > 1 {
            remaining -= 1
        } else {
            isRunning = false
            remaining = 0
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        }
    }
}
