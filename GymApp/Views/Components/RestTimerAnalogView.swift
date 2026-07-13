import SwiftUI

// Fable  Date 07/13/2026
// Analog stopwatch face — the opt-in alternative to the progress ring in
// RestTimerFullScreenView, chosen via the "Analog stopwatch" toggle in Settings
// (@AppStorage "restTimerAnalogStyle"). Purely a read-only consumer of
// WorkoutSession: the hand sweeps one full revolution as restProgress goes 0→1,
// so a 90s rest and a 5m rest both map to exactly one lap, mirroring how the
// ring's trim maps progress to one full circle.
struct RestTimerAnalogView: View {
    @EnvironmentObject private var session: WorkoutSession
    @EnvironmentObject private var theme: ThemeManager

    // Fable  Date 07/13/2026
    // Sized slightly larger than the ring's 260pt so the finer tick detail stays
    // legible; everything below is derived from this so the face scales as one unit.
    private let dialSize: CGFloat = 300

    var body: some View {
        ZStack {
            bezel
            ticks
            hand
            hub
            readout
        }
        .frame(width: dialSize, height: dialSize)
    }

    // Fable  Date 07/13/2026
    // Outer rim + a faint fill so the dial reads as a solid stopwatch body against
    // the full-screen background, not just floating tick marks.
    private var bezel: some View {
        ZStack {
            Circle()
                .fill(theme.current.accent.opacity(0.06))
            Circle()
                .stroke(theme.current.accent.opacity(0.35), lineWidth: 4)
        }
    }

    // Fable  Date 07/13/2026
    // 60 ticks in three weights: heavy at the quarters (12/3/6/9 positions),
    // medium at the remaining 5-tick marks, hairline elsewhere — the tiered
    // detail that distinguishes a stopwatch face from a plain clock. Each tick is
    // drawn at 12 o'clock then rotated into place (6° per tick).
    private var ticks: some View {
        ForEach(0..<60, id: \.self) { index in
            let isQuarter = index % 15 == 0
            let isFiveMark = index % 5 == 0
            let length: CGFloat = isQuarter ? 20 : (isFiveMark ? 13 : 7)
            let width: CGFloat = isQuarter ? 4 : (isFiveMark ? 2.5 : 1.5)

            Capsule()
                .fill(theme.current.accent.opacity(isQuarter ? 1 : (isFiveMark ? 0.7 : 0.35)))
                .frame(width: width, height: length)
                .offset(y: -(dialSize / 2 - 10 - length / 2))
                .rotationEffect(.degrees(Double(index) * 6))
        }
    }

    // Fable  Date 07/13/2026
    // The sweep hand: needle above the pivot, short counterweight tail below,
    // rotated as one piece so the tail stays opposite the needle. Snaps to a full
    // lap when showRestComplete is set (matching the ring forcing trim to 1), and
    // animates on restProgress with the same 0.3s linear step the ring uses so the
    // two styles feel identical in motion.
    private var hand: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(theme.current.accent)
                .frame(width: 4.5, height: dialSize / 2 - 34)
            Capsule()
                .fill(theme.current.accent)
                .frame(width: 4.5, height: 24)
        }
        .offset(y: -(dialSize / 2 - 34 - 24) / 2)
        .rotationEffect(.degrees((session.showRestComplete ? 1 : session.restProgress) * 360))
        .animation(.linear(duration: 0.3), value: session.restProgress)
    }

    // Fable  Date 07/13/2026
    // Pivot cap drawn over the hand so the needle appears to rotate around a
    // physical post rather than a bare line crossing the center.
    private var hub: some View {
        Circle()
            .fill(theme.current.accent)
            .frame(width: 14, height: 14)
    }

    // Fable  Date 07/13/2026
    // Digital sub-dial in the lower half (where a real stopwatch keeps its minute
    // register) so it never collides with the hand's pivot. Mirrors the ring's
    // complete-state swap: checkmark + "Done" once WorkoutSession flags the rest
    // as finished.
    private var readout: some View {
        VStack(spacing: 2) {
            Image(systemName: session.showRestComplete ? "checkmark.circle.fill" : "timer")
                .font(.system(size: 18))
                .foregroundStyle(theme.current.accent)
            Text(session.showRestComplete ? "Done" : RestDuration.label(session.restRemaining))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .offset(y: dialSize / 4)
    }
}

#Preview {
    RestTimerAnalogView()
        .environmentObject(WorkoutSession())
        .environmentObject(ThemeManager())
}
