import SwiftUI

// Claude  Date 06/16/2026
// The Spotify-style "now playing" bar for an in-progress workout. Floats above the
// tab bar (placed by RootTabView) whenever there's an active workout. Tapping it
// jumps back into the session (onOpen). While a rest timer runs it becomes a
// progress bar sweeping left→right with the countdown; when the timer finishes it
// briefly reads "Rest complete." Renders nothing when no workout is active.
struct WorkoutMiniBar: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var session: WorkoutSession

    /// Called when the bar (not the Skip button) is tapped — reopens the workout.
    let onOpen: () -> Void

    var body: some View {
        // Hidden while you're already inside the active workout's editor.
        if let active = store.activeWorkout, session.viewingWorkoutID != active.id {
            row(for: active)
                .background(theme.current.surface)
                // Thin accent progress bar across the bottom — width tracks the rest
                // elapsed ÷ total. Overlaid before the clip so it follows the rounded
                // corners. (A GeometryReader here is bounded to the row, not greedy.)
                .overlay(alignment: .bottomLeading) { progressBar }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.current.accent.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                .padding(.horizontal, 10)
                // Tap anywhere on the bar (except Skip) to reopen the workout.
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onTapGesture { onOpen() }
        }
    }

    private func row(for active: Workout) -> some View {
        HStack(spacing: 12) {
            Image(systemName: leadingIcon)
                .font(.title3)
                .foregroundStyle(theme.current.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text(subtitle(for: active))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if session.isResting {
                Button("Skip") { session.skipRest() }
                    .buttonStyle(.bordered)
                    .tint(theme.current.accent)
            } else {
                Image(systemName: "chevron.up")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // Claude  Date 06/16/2026
    // Thin theme-accent bar that grows left→right with the rest progress (elapsed ÷
    // total), like a track scrubber. Shows full while the brief "Rest complete"
    // message is up, then disappears with the bar. GeometryReader is bounded by the
    // overlay (the row's frame), so it isn't greedy.
    @ViewBuilder
    private var progressBar: some View {
        if session.isResting || session.showRestComplete {
            GeometryReader { geo in
                Rectangle()
                    .fill(theme.current.accent)
                    .frame(width: geo.size.width * (session.showRestComplete ? 1 : session.restProgress),
                           height: 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .animation(.linear(duration: 0.3), value: session.restProgress)
        }
    }

    private var leadingIcon: String {
        if session.isResting { return "timer" }
        if session.showRestComplete { return "checkmark.circle.fill" }
        return "figure.strengthtraining.traditional"
    }

    private var title: String {
        if session.isResting { return "Resting \(RestDuration.label(session.restRemaining))" }
        if session.showRestComplete { return "Rest complete" }
        return "Workout in progress"
    }

    private func subtitle(for active: Workout) -> String {
        if session.isResting { return "Tap to return to your workout" }
        if session.showRestComplete { return "Back to it — tap to continue" }
        let exercises = active.exercises.count
        let done = active.completedSets
        let exPart = "\(exercises) exercise\(exercises == 1 ? "" : "s")"
        let setPart = "\(done) set\(done == 1 ? "" : "s") done"
        return "\(exPart) · \(setPart)"
    }
}
