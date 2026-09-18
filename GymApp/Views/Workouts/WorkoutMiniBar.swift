import SwiftUI

// Reviewed 6-26-26 Bryce Hart
// The Spotify-style "now playing" bar for an in-progress workout. Floats above the
// tab bar (placed by RootTabView) whenever there's an active workout. Tapping it
// jumps back into the session (onOpen). Renders nothing when no workout is active.
//
// CLAUDE  Date 09/17/2026
// ONE bar, one state (Bryce, 9/17/26). It used to become a second, differently worded
// bar while resting — "Resting 1:04 / Tap to view timer" — that opened the full-screen
// timer. Now rest shows as the wash crossing this bar, plus the time left beside Skip.
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
                // CLAUDE  Date 09/17/2026
                // Rest progress is a translucent accent wash crossing the whole bar now
                // (Bryce, 9/17/26), not a 3pt line along the bottom. Overlaid before the
                // clip so it follows the capsule's ends.
                .overlay(alignment: .leading) { progressWash }
                // CLAUDE  Date 09/17/2026
                // Capsule + accent rim, so the bar matches the top pill and the keyboard
                // bar rather than being the one 14pt rounded rectangle among them.
                .clipShape(Capsule())
                .overlay(AccentRim(shape: Capsule(), accent: theme.current.accent))
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                .padding(.horizontal, 10)
                // Claude  Date 07/16/2026
                // Small breathing room above the tab bar now that the bar is hosted
                // as a safe-area inset (it used to float via an overlay with a
                // hardcoded 49pt tab-bar offset). Inside the `if` so a hidden bar
                // contributes zero inset.
                .padding(.bottom, 4)
                // Claude  Date 07/11/2026 last changed: 09/17/2026 by: CLAUDE
                // Tap anywhere on the bar (except Skip) to reopen the workout — resting or
                // not. The full-screen timer is still reachable from the rest row inside
                // the workout itself (see RestTimer), just not from here.
                .contentShape(Capsule())
                .onTapGesture { onOpen() }
        }
    }

    private func row(for active: Workout) -> some View {
        // CLAUDE  Date 09/17/2026 — the leading workout glyph is gone (Bryce, 9/17/26); the
        // text starts the row now.
        HStack(spacing: 10) {
            // CLAUDE  Date 09/17/2026
            // One line each, scaled down rather than wrapped or clipped: the theme face is
            // monospaced, so at its widest ("Workout in progress" beside a countdown and
            // Skip) the title wrapped to two lines and the subtitle lost its last word.
            VStack(alignment: .leading, spacing: 2) {
                Text("Workout in progress")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(subtitle(for: active))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer()

            // CLAUDE  Date 09/17/2026
            // Resting is a trailing change only: the time left, then Skip. The chevron it
            // replaces is just an affordance, and the row still opens the workout on tap.
            if session.isResting {
                Text(RestDuration.label(session.restRemaining))
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(.secondary)
                Button("Skip") { session.skipRest() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)   // 09/17: gives the title back the width it needs
                    .tint(theme.current.accent)
            } else {
                Image(systemName: "chevron.up")
                    .foregroundStyle(.secondary)
            }
        }
        // CLAUDE  Date 09/17/2026 — 14 → 20 horizontally: a capsule's ends curve away, so
        // the icon and the Skip button need the extra room to clear them.
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // Claude  Date 06/16/2026 last changed: 09/17/2026 by: CLAUDE
    // The rest countdown, as a faint accent fill crossing the bar left→right (elapsed ÷
    // total). Full while the brief "Rest complete" message is up, then gone with the bar.
    // Transparent enough to read the row straight through it. GeometryReader is bounded by
    // the overlay (the row's frame), so it isn't greedy.
    @ViewBuilder
    private var progressWash: some View {
        if session.isResting || session.showRestComplete {
            GeometryReader { geo in
                Rectangle()
                    .fill(theme.current.accent.opacity(0.18))
                    .frame(width: geo.size.width * (session.showRestComplete ? 1 : session.restProgress))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .animation(.linear(duration: 0.3), value: session.restProgress)
        }
    }

    // CLAUDE  Date 09/17/2026 — the same line whether you're resting or lifting; the wash
    // and the countdown beside Skip are what change.
    private func subtitle(for active: Workout) -> String {
        let exercises = active.exercises.count
        let done = active.completedSets
        let exPart = "\(exercises) exercise\(exercises == 1 ? "" : "s")"
        let setPart = "\(done) set\(done == 1 ? "" : "s") done"
        return "\(exPart) · \(setPart)"
    }
}

// Claude  Date 07/16/2026 last changed: 07/21/2026 by: Claude
// Where this bar lives, and why it keeps moving:
//  - It began as a floating .overlay on the whole TabView, which painted it ON TOP
//    of every page — the last ~55pt of every scroll view sat underneath it,
//    unreachable and untappable (e.g. the Settings row at the bottom of Profile
//    during an active workout).
//  - 07/16 it became a bottom safe-area inset per tab, which fixed that for a tab's
//    root page but not for anything the tab pushed: a safe-area inset applied
//    outside a NavigationStack doesn't reach its destinations. Nobody caught it
//    because this bar hides itself inside the one pushed page it would have covered
//    (the editor for the active workout).
//  - 07/21 it moved into RootTabView's VStack, stacked directly above the tab bar.
//    It's plain layout now: when there's nothing to show the view is empty and
//    contributes zero height, and when there is, the pages above simply get shorter.
// So there's no modifier to apply — RootTabView places WorkoutMiniBar itself.
