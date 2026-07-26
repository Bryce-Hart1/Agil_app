import SwiftUI

// Claude  Date 06/10/2026
// Navigation target for the workout editor. `isNew` distinguishes logging a
// brand-new workout ("Finish Workout") from editing an existing one ("Finish Edit").
struct WorkoutRoute: Hashable {
    let id: UUID
    let isNew: Bool
}

/// Lists workouts — an "In progress" row pinned on top for the active session, then
/// finished workouts (newest first). Tap a row to open the editor. The + starts a
/// new workout, or resumes the active one if a session is already in progress.
///
/// On a fresh install (no workouts at all) the list is replaced by the `getStarted`
/// state, which points at the premade-workout catalog or a blank session.
struct WorkoutsListView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    // Claude  Date 06/16/2026
    // Shared session — so the mini-bar can hand us a workout to reopen, and so the
    // toolbar can resume the active one.
    @EnvironmentObject private var session: WorkoutSession
    @State private var path: [WorkoutRoute] = []
    // Claude  Date 06/18/2026
    // History is collapsed to the last few by default; this expands it to the full log.
    @State private var showAllHistory = false
    // Claude  Date 07/25/2026
    // Drives the premade-workout browser raised from the get-started empty state. A
    // sheet, not a push: `path` is typed [WorkoutRoute], and widening it to an enum
    // would touch every existing push site for one screen that isn't a workout.
    @State private var showingPremade = false

    // How many recent workouts History shows before "Show all".
    private static let historyPreviewCount = 3

    // Claude  Date 06/16/2026
    // History = finished workouts only (newest first). The active one is pinned
    // separately at the top via store.activeWorkout.
    private var finishedWorkouts: [Workout] {
        store.workouts.filter { $0.isFinished }.sorted { $0.date > $1.date }
    }

    // Claude  Date 06/18/2026
    // The slice actually rendered: the last 3 by default, or everything when expanded.
    private var visibleHistory: [Workout] {
        showAllHistory ? finishedWorkouts : Array(finishedWorkouts.prefix(Self.historyPreviewCount))
    }

    // Claude  Date 07/25/2026
    // A first-run install: nothing started, nothing finished. Distinct from
    // `finishedWorkouts.isEmpty`, which is also true mid-session — that case still
    // wants the normal list with the "In progress" row pinned on top.
    private var hasNoWorkouts: Bool { store.workouts.isEmpty }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if hasNoWorkouts { getStarted } else { workoutList }
            }
            .navigationTitle("Workouts")
            .themed(theme.current)
            // Claude  Date 07/13/2026
            // Centered mode-switcher pill in the nav bar (shared by all root tabs).
            .modeNotchToolbar()
            .navigationDestination(for: WorkoutRoute.self) { route in
                WorkoutDetailView(workoutID: route.id, isNew: route.isNew)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    // Claude  Date 06/16/2026
                    // One active workout at a time: if one's in progress, + resumes it;
                    // otherwise it offers a new empty workout or one from a preset.
                    if let active = store.activeWorkout {
                        Button { open(active.id) } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Resume workout")
                    } else {
                        Menu {
                            Button {
                                start(Workout())
                            } label: {
                                Label("Empty Workout", systemImage: "square.and.pencil")
                            }

                            if !store.presets.isEmpty {
                                Menu {
                                    ForEach(store.presets) { preset in
                                        Button {
                                            start(store.workout(from: preset))
                                        } label: {
                                            // Claude  Date 06/30/2026
                                            // Custom PNG icons use image:, SF Symbols use systemImage:.
                                            let title = preset.name.isEmpty ? "Untitled Preset" : preset.name
                                            if PresetIcons.isCustomAsset(preset.symbolName) {
                                                Label(title, image: preset.symbolName)
                                            } else {
                                                Label(title, systemImage: preset.symbolName)
                                            }
                                        }
                                    }
                                } label: {
                                    Label("From Preset", systemImage: "square.stack")
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            // Claude  Date 07/25/2026
            // The premade browser, raised from the get-started state. Adding a template
            // saves a preset and pops back to its list; closing the sheet returns here,
            // where the + menu's "From Preset" now offers it.
            .sheet(isPresented: $showingPremade) {
                NavigationStack {
                    PremadeWorkoutsView(isModal: true)
                }
            }
            // Claude  Date 06/16/2026
            // Honor a jump-back request from the mini-bar (works whether this view was
            // already alive or freshly created when the tab/mode switched).
            .onAppear { consumeRequestedWorkout() }
            .onChange(of: session.requestedWorkoutID) { _ in consumeRequestedWorkout() }
        }
    }

    // Claude  Date 07/25/2026
    // First-run state, replacing a list that would otherwise hold a single line of
    // grey text. Two ways forward, in the order we want them tried: lift a proven
    // split out of the shipped catalog, or start logging from nothing.
    private var getStarted: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack(spacing: 6) {
                Text("Get Started lifting with agil")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Pick a proven split to start from, or log a workout from scratch.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .supportingTextFont()
            }
            VStack(spacing: 10) {
                Button {
                    showingPremade = true
                } label: {
                    Text("Browse Premade Workouts")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    start(Workout())
                } label: {
                    Text("Start an Empty Workout")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.current.background.ignoresSafeArea())
    }

    private var workoutList: some View {
        List {
            // Claude  Date 06/16/2026
            // The live session, pinned on top so it's always reachable.
            if let active = store.activeWorkout {
                Section("In progress") {
                    NavigationLink(value: WorkoutRoute(id: active.id, isNew: false)) {
                        ActiveWorkoutRow(workout: active)
                    }
                }
            }

            Section {
                if finishedWorkouts.isEmpty {
                    // Claude  Date 06/16/2026 last changed: 07/25/2026 by: Claude
                    // (07/25) Only the mid-session case reaches this now — a first-run
                    // install with no workouts at all gets `getStarted` instead, so the
                    // old "No workouts yet. Tap + to log one." branch is gone.
                    Text("Finish your active workout to see it here.")
                        .foregroundStyle(.secondary)
                        .supportingTextFont()
                } else {
                    ForEach(visibleHistory) { workout in
                        NavigationLink(value: WorkoutRoute(id: workout.id, isNew: false)) {
                            WorkoutRow(workout: workout)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { visibleHistory[$0].id }.forEach(store.deleteWorkout)
                    }

                    // Claude  Date 06/18/2026
                    // Keep History compact — the last 3 by default, expandable to the
                    // whole log (and collapsible again).
                    if finishedWorkouts.count > Self.historyPreviewCount {
                        Button {
                            withAnimation { showAllHistory.toggle() }
                        } label: {
                            Label(showAllHistory ? "Show less" : "Show all \(finishedWorkouts.count)",
                                  systemImage: showAllHistory ? "chevron.up" : "chevron.down")
                                .font(.subheadline)
                        }
                    }
                }
            } header: {
                if !finishedWorkouts.isEmpty { Text("History") }
            }
        }
    }

    /// Adds a new workout to the store and navigates into its editor (as new).
    private func start(_ workout: Workout) {
        store.addWorkout(workout)
        // Claude  Date 07/01/2026
        // Ask for notification permission here — the first time a workout starts — so the
        // prompt has obvious context (it powers the "workout still running" nudge). No-op
        // once the user has answered.
        WorkoutNotifications.requestAuthorizationIfNeeded()
        path.append(WorkoutRoute(id: workout.id, isNew: true))
    }

    /// Pushes a workout's editor if not already on top of the stack.
    private func open(_ id: UUID) {
        if path.last?.id != id { path.append(WorkoutRoute(id: id, isNew: false)) }
    }

    // Claude  Date 06/16/2026
    // Consume a mini-bar "open this workout" request, then clear it so it fires once.
    private func consumeRequestedWorkout() {
        guard let id = session.requestedWorkoutID else { return }
        open(id)
        session.requestedWorkoutID = nil
    }
}

// Claude  Date 06/16/2026
// The pinned "In progress" row: visually distinct (accent dumbbell + live dot) so
// the active session is obvious, with a count of checked-off sets.
private struct ActiveWorkoutRow: View {
    @EnvironmentObject private var theme: ThemeManager
    let workout: Workout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.title3)
                .foregroundStyle(theme.current.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Active workout")
                    .font(.headline)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .supportingTextFont()
            }
            Spacer()
            Circle()
                .fill(theme.current.accent)
                .frame(width: 9, height: 9)
        }
    }

    private var summary: String {
        let exerciseCount = workout.exercises.count
        let done = workout.completedSets
        let exercisePart = "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")"
        let setPart = "\(done) set\(done == 1 ? "" : "s") done"
        return "\(exercisePart) • \(setPart)"
    }
}

private struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(workout.date, format: .dateTime.weekday().month().day())
                .font(.headline)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .supportingTextFont()
        }
    }

    private var summary: String {
        let exerciseCount = workout.exercises.count
        let setCount = workout.totalSets
        let exercisePart = "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")"
        let setPart = "\(setCount) set\(setCount == 1 ? "" : "s")"
        return "\(exercisePart) • \(setPart)"
    }
}

#Preview {
    WorkoutsListView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
        .environmentObject(WorkoutSession())
}
