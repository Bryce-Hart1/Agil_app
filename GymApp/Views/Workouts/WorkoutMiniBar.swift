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
                // Claude  Date 07/16/2026
                // Small breathing room above the tab bar now that the bar is hosted
                // as a safe-area inset (it used to float via an overlay with a
                // hardcoded 49pt tab-bar offset). Inside the `if` so a hidden bar
                // contributes zero inset.
                .padding(.bottom, 4)
                // Claude  Date 07/11/2026
                // Tap anywhere on the bar (except Skip): while resting, expand to the
                // full-screen timer; otherwise reopen the workout as before.
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onTapGesture {
                    if session.isResting || session.showRestComplete {
                        session.showFullScreenTimer = true
                    } else {
                        onOpen()
                    }
                }
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

            // Claude  Date 07/11/2026
            // Visual hint that the bar can be expanded to the full-screen timer while
            // resting/just-finished (the tap-to-expand gesture is on the row itself,
            // see .onTapGesture above — this icon has no gesture of its own).
            if session.isResting {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Skip") { session.skipRest() }
                    .buttonStyle(.bordered)
                    .tint(theme.current.accent)
            } else if session.showRestComplete {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        if session.isResting { return "Tap to view timer" }
        if session.showRestComplete { return "Back to it — tap to view" }
        let exercises = active.exercises.count
        let done = active.completedSets
        let exPart = "\(exercises) exercise\(exercises == 1 ? "" : "s")"
        let setPart = "\(done) set\(done == 1 ? "" : "s") done"
        return "\(exPart) · \(setPart)"
    }
}

// Claude  Date 07/16/2026
// Hosts the mini-bar as a bottom safe-area inset on a tab's content (applied to
// each tab in RootTabView). Previously the bar was a floating .overlay on the
// whole TabView, which painted it ON TOP of every page — the last ~55pt of
// every scroll view sat underneath it, unreachable and untappable (e.g. the
// Settings row at the bottom of Profile during an active workout). As a
// safe-area inset the bar still sits just above the tab bar, but scroll
// content now ends above it, and the inset collapses to nothing whenever the
// bar renders empty (no active workout, or already inside its editor).
extension View {
    func workoutMiniBar(onOpen: @escaping () -> Void) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            WorkoutMiniBar(onOpen: onOpen)
        }
    }
}
