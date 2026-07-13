import SwiftUI

// Claude  Date 07/11/2026
// Full-screen expansion of the rest countdown — tap-to-expand from the mini-bar or
// the inline rest row (see WorkoutMiniBar / RestTimerView), which set
// WorkoutSession.showFullScreenTimer. Presented via RootTabView's fullScreenCover
// bound to that flag, so it persists across tab switches exactly like the mini-bar,
// and collapses itself automatically when WorkoutSession hides "Rest complete" (see
// WorkoutSession.scheduleHide) or when Skip is tapped.
struct RestTimerFullScreenView: View {
    @EnvironmentObject private var session: WorkoutSession
    @EnvironmentObject private var theme: ThemeManager

    @State private var appear = false

    // Fable  Date 07/13/2026
    // Same key the "Analog stopwatch" toggle in SettingsView writes — picks which
    // face fills the timer slot below. Defaults false so the ring stays the
    // out-of-the-box look unless the user opts in.
    @AppStorage("restTimerAnalogStyle") private var restTimerAnalogStyle = false

    var body: some View {
        ZStack {
            theme.current.background.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { close() }

            VStack(spacing: 28) {
                closeButton
                Spacer()
                // Fable  Date 07/13/2026
                // Settings-driven face swap: the analog stopwatch (RestTimerAnalogView)
                // replaces only this slot — the surrounding close/label/action layout is
                // shared by both styles so they stay in lockstep.
                if restTimerAnalogStyle {
                    RestTimerAnalogView()
                } else {
                    ring
                }
                Text(session.showRestComplete ? "Rest complete" : "Resting")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                actionButton
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .scaleEffect(appear ? 1 : 0.94)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { appear = true }
        }
    }

    private var closeButton: some View {
        HStack {
            Button(action: close) {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            Spacer()
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(theme.current.accent.opacity(0.15), lineWidth: 14)
            Circle()
                .trim(from: 0, to: session.showRestComplete ? 1 : session.restProgress)
                .stroke(theme.current.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: session.restProgress)

            VStack(spacing: 6) {
                Image(systemName: session.showRestComplete ? "checkmark.circle.fill" : "timer")
                    .font(.system(size: 34))
                    .foregroundStyle(theme.current.accent)
                Text(session.showRestComplete ? "Done" : RestDuration.label(session.restRemaining))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: 260, height: 260)
    }

    @ViewBuilder
    private var actionButton: some View {
        if session.isResting {
            Button {
                session.skipRest()
            } label: {
                Label("Skip Rest", systemImage: "forward.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.current.accent)
            .controlSize(.large)
        } else {
            Button(action: close) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.current.accent)
            .controlSize(.large)
        }
    }

    private func close() {
        session.showFullScreenTimer = false
    }
}

#Preview {
    RestTimerFullScreenView()
        .environmentObject(WorkoutSession())
        .environmentObject(ThemeManager())
}
