import SwiftUI

// Claude  Date 08/16/2026
// The rolling 30-day recap card that opens the Progress tab. Presentation only — every
// number and every phrase comes from MonthlyRecap or from WorkoutSummary.BestSet's
// existing wording helpers (loadText / oneRepMaxText / contextText), so the card can't
// invent a second way of describing a set.
//
// Themed surface rather than the profile card's art: this sits directly above three
// charts, and a full-bleed animated card there fought them for attention. Accent-tinted
// tiles on `surface` keep it clearly the headline without turning the tab into a poster.
//
// Everything animates in from a single `shown` flag flipped on appear, with per-section
// delays for a cascade. That flag is also the count-up gate: numbers render as 0 until
// it flips, and `.contentTransition(.numericText())` rolls the digits up — the app's
// established substitute for a custom Animatable counter (see MacroSummaryView).
// `shown` resets on disappear so the card replays each time the tab is opened.
struct MonthlyRecapCard: View {
    let recap: MonthlyRecap
    var title = "Last 30 days"
    let surface: Color
    let accent: Color

    @State private var shown = false

    /// Gold, matching the performance card's personal-record treatment.
    private let gold = Color(red: 1.0, green: 0.84, blue: 0.35)

    /// Four rows is what fits before the section starts competing with the
    /// sets-per-muscle-group chart further down the tab.
    private var topRegions: [MonthlyRecap.RegionShift] { Array(recap.regionShifts.prefix(4)) }
    private var topStrength: [MonthlyRecap.StrengthShift] { Array(recap.strengthShifts.prefix(3)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header.reveal(shown, delay: 0)
            totalsStrip.reveal(shown, delay: 0.05)
            bestSessionTile.reveal(shown, delay: 0.12)
            recordsRow.reveal(shown, delay: 0.18)
            regionSection
            strengthSection.reveal(shown, delay: 0.32)
            footer.reveal(shown, delay: 0.38)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
        .onAppear { shown = true }
        .onDisappear { shown = false }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 26, height: 26)
                .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline)
                Text(dateRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var dateRange: String {
        let start = recap.windowStart.formatted(.dateTime.month(.abbreviated).day())
        let end = recap.windowEnd.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) – \(end)"
    }

    // MARK: - Totals

    // Claude  Date 08/16/2026
    // Four equal columns in one shared pill with hairline dividers — the same strip the
    // performance card uses for session stats, so the two cards read as a family. Each
    // column carries a delta against the preceding 30 days; the delta is omitted (not
    // shown as "+100%") when there's no previous window to compare against.
    private var totalsStrip: some View {
        HStack(spacing: 0) {
            totalCell("Workouts", value: Double(recap.workouts), previous: Double(recap.previousWorkouts),
                      delay: 0.10) { "\(Int($0))" }
            statDivider
            totalCell("Volume", value: recap.totalVolume, previous: recap.previousVolume,
                      delay: 0.14, format: volumeText)
            statDivider
            totalCell("Sets", value: Double(recap.totalSets), previous: Double(recap.previousSets),
                      delay: 0.18) { "\(Int($0))" }
            statDivider
            totalCell("Days", value: Double(recap.trainingDays), previous: Double(recap.previousTrainingDays),
                      delay: 0.22) { "\(Int($0))" }
        }
        .padding(.vertical, 10)
        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    private func totalCell(_ title: String, value: Double, previous: Double,
                           delay: Double, format: @escaping (Double) -> String) -> some View {
        VStack(spacing: 3) {
            CountUpText(value: value, shown: shown, delay: delay, format: format)
                .font(.subheadline.weight(.bold))
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(title)
                .font(.caption2).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
            deltaPill(current: value, previous: previous, delay: delay + 0.12)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(width: 1, height: 34)
    }

    @ViewBuilder
    private func deltaPill(current: Double, previous: Double, delay: Double) -> some View {
        if previous > 0 {
            let change = (current - previous) / previous
            let up = change >= 0
            Label(percentText(change), systemImage: up ? "arrow.up" : "arrow.down")
                .font(.system(size: 9).weight(.semibold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(abs(change) < 0.01 ? Color.secondary : (up ? .green : .red))
                .lineLimit(1).minimumScaleFactor(0.7)
                .scaleEffect(shown ? 1 : 0.6)
                .opacity(shown ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(delay), value: shown)
        }
    }

    // MARK: - Best session

    // Claude  Date 08/16/2026
    // The window's standout session, with the same gold personal-record treatment the
    // performance card gives a record-setting best set — a PR month should look like one
    // at a glance. The wording under the lift name is BestSet's own, unchanged.
    @ViewBuilder
    private var bestSessionTile: some View {
        if let session = recap.bestSession, let best = session.bestSet {
            let isPR = best.isPersonalRecord
            let tint = isPR ? gold : accent

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: isPR ? "trophy.fill" : "star.fill")
                    Text(isPR ? "Best session · personal record" : "Best session")
                    Spacer(minLength: 0)
                    Text(session.date.formatted(.dateTime.month(.abbreviated).day()))
                        .foregroundStyle(.secondary)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.7)

                Text(best.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text([best.loadText, best.oneRepMaxText].compactMap { $0 }.joined(separator: "  ·  "))
                    .font(.caption)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if let context = best.contextText {
                    Text(context)
                        .font(.caption2)
                        .foregroundStyle(isPR ? tint : .secondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Text(sessionCaption(session))
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(tint.opacity(isPR ? 0.16 : 0.12), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                if isPR {
                    RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.5), lineWidth: 1)
                }
            }
        }
    }

    private func sessionCaption(_ session: WorkoutSummary) -> String {
        "\(session.durationText)  ·  \(session.completedSets) sets  ·  \(volumeText(session.totalVolume))"
    }

    // MARK: - Records

    @ViewBuilder
    private var recordsRow: some View {
        if !recap.personalRecords.isEmpty {
            let names = recap.personalRecords.prefix(3).map(\.displayName).joined(separator: ", ")
            let extra = recap.personalRecords.count - min(3, recap.personalRecords.count)

            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.caption)
                    .foregroundStyle(gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text(recordCountText)
                        .font(.caption.weight(.semibold))
                    Text(extra > 0 ? "\(names) +\(extra) more" : names)
                        .font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var recordCountText: String {
        let count = recap.personalRecords.count
        return count == 1 ? "1 personal record" : "\(count) personal records"
    }

    // MARK: - Body-part frequency

    // Claude  Date 08/16/2026
    // What actually changed in the training split, ranked by how far each region moved
    // rather than by raw volume — a region that doubled is the story, even if legs still
    // out-set it. The raw per-group counts live in the chart further down the tab, so
    // the trailing figure here is the CHANGE, not the count.
    @ViewBuilder
    private var regionSection: some View {
        if !topRegions.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                sectionLabel("Body-part focus")
                    .reveal(shown, delay: 0.24)
                ForEach(Array(topRegions.enumerated()), id: \.element.id) { index, shift in
                    regionBar(shift, index: index)
                }
            }
        }
    }

    private func regionBar(_ shift: MonthlyRecap.RegionShift, index: Int) -> some View {
        let peak = max(topRegions.map(\.sets).max() ?? 1, 1)
        let fraction = min(1, Double(shift.sets) / Double(peak))

        return HStack(spacing: 10) {
            Text(shift.region.title)
                .font(.caption)
                .frame(width: 66, alignment: .leading)
                .lineLimit(1).minimumScaleFactor(0.7)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(accent.opacity(0.12))
                    Capsule().fill(accent)
                        .frame(width: geo.size.width * (shown ? fraction : 0))
                }
            }
            .frame(height: 8)
            .animation(.spring(response: 0.6, dampingFraction: 0.85)
                .delay(0.26 + Double(index) * 0.07), value: shown)

            regionDelta(shift)
                .frame(width: 50, alignment: .trailing)
                .scaleEffect(shown ? 1 : 0.6)
                .opacity(shown ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7)
                    .delay(0.36 + Double(index) * 0.07), value: shown)
        }
    }

    @ViewBuilder
    private func regionDelta(_ shift: MonthlyRecap.RegionShift) -> some View {
        if !recap.hasComparisonWindow {
            Text("\(shift.sets) sets")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        } else if let change = shift.percentChange {
            Text(percentText(change))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(abs(change) < 0.01 ? Color.secondary : (change > 0 ? .green : .red))
                .lineLimit(1).minimumScaleFactor(0.7)
        } else {
            Text("New")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent)
        }
    }

    // MARK: - Strength

    @ViewBuilder
    private var strengthSection: some View {
        if !topStrength.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                sectionLabel("Strength gained")
                ForEach(topStrength) { shift in
                    HStack(spacing: 8) {
                        Text(shift.name)
                            .font(.caption)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Spacer(minLength: 8)
                        Text("+\(Int(shift.deltaPounds.rounded())) lb 1RM")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        let parts = [
            recap.longestStreak > 0 ? "\(recap.longestStreak)-day streak" : nil,
            recap.topExerciseName.map { "Most trained: \($0)" }
        ].compactMap { $0 }

        if !parts.isEmpty {
            Text(parts.joined(separator: "  ·  "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }

    // MARK: - Formatting

    /// Volume in pounds, abbreviated once it stops fitting a quarter-width column
    /// (12,480 → "12.5k lb") — same rule as the performance card's stat strip.
    private func volumeText(_ pounds: Double) -> String {
        let value = pounds.rounded()
        if value >= 10_000 { return String(format: "%.1fk lb", value / 1_000) }
        return "\(Int(value)) lb"
    }

    /// "+38%" / "−12%" — a real minus sign, and always rounded to a whole percent.
    private func percentText(_ change: Double) -> String {
        let percent = Int((change * 100).rounded())
        return percent >= 0 ? "+\(percent)%" : "−\(abs(percent))%"
    }
}

// Claude  Date 08/16/2026
// The count-up: render 0 until the card's `shown` gate flips, then let
// `.contentTransition(.numericText())` roll the digits to the real figure. The app has
// no custom Animatable counter and doesn't need one — this is the same idiom the
// nutrition macro numbers use, and it works from iOS 16.
private struct CountUpText: View {
    let value: Double
    let shown: Bool
    let delay: Double
    let format: (Double) -> String

    var body: some View {
        Text(format(shown ? value : 0))
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.spring(response: 0.7, dampingFraction: 0.9).delay(delay), value: shown)
    }
}

// Claude  Date 08/16/2026
// Fade-and-rise entrance with a per-section delay, so the card assembles top-down
// instead of snapping in all at once. Each call site owns its own delay rather than
// relying on one enclosing withAnimation, which can't stagger.
private struct Reveal: ViewModifier {
    let shown: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 8)
            .animation(.spring(response: 0.45, dampingFraction: 0.85).delay(delay), value: shown)
    }
}

private extension View {
    func reveal(_ shown: Bool, delay: Double) -> some View {
        modifier(Reveal(shown: shown, delay: delay))
    }
}

// Claude  Date 08/16/2026
// Fixtures rather than the seed library so all three states are reachable without
// running the app: a rich window (bench PR, back way up, legs down, 1RM gains), a
// sparse one (two sessions, no records, a single region — sections 3–6 should vanish),
// and an empty one (renders nothing on the tab, since `hasData` is false).
#Preview {
    let bench = Exercise(name: "Barbell Bench Press", region: .chest, category: "Chest", liftType: .bench)
    let row = Exercise(name: "Barbell Row", region: .back, category: "Lats")
    let squat = Exercise(name: "Back Squat", region: .legs, category: "Quads", liftType: .squat)
    let library = [bench, row, squat]

    func day(_ ago: Double) -> Date { Date().addingTimeInterval(-ago * 86_400) }

    func event(_ exercise: Exercise, _ reps: Int, _ weight: Double, _ ago: Double) -> ActivityEvent {
        ActivityEvent(setId: UUID(), exerciseId: exercise.id, reps: reps, weight: weight,
                      loggedAt: day(ago))
    }

    // Previous window (30–60 days ago): lots of legs, a little back, lighter bench.
    var events = (0..<6).flatMap { i -> [ActivityEvent] in
        let ago = 32.0 + Double(i) * 4
        return [event(squat, 5, 275, ago), event(squat, 5, 275, ago),
                event(bench, 5, 205, ago), event(row, 8, 135, ago)]
    }
    // Current window: back volume way up, legs down, and a bench PR eight days ago.
    events += (0..<7).flatMap { i -> [ActivityEvent] in
        let ago = 2.0 + Double(i) * 4
        return [event(row, 8, 165, ago), event(row, 8, 165, ago), event(row, 10, 155, ago),
                event(bench, 5, 225, ago)]
    }
    events.append(event(bench, 3, 255, 8))
    events.append(event(squat, 5, 285, 12))

    let prSets = [ExerciseSet(reps: 3, weight: 255, completedAt: day(8)),
                  ExerciseSet(reps: 8, weight: 165, completedAt: day(8))]
    let prWorkout = Workout(date: day(8),
                            exercises: [LoggedExercise(exerciseId: bench.id, sets: [prSets[0]]),
                                        LoggedExercise(exerciseId: row.id, sets: [prSets[1]])],
                            isFinished: true,
                            startedAt: day(8).addingTimeInterval(-4_200),
                            finishedAt: day(8))
    let plainWorkout = Workout(date: day(2),
                               exercises: [LoggedExercise(exerciseId: row.id, sets: [
                                   ExerciseSet(reps: 8, weight: 165, completedAt: day(2))])],
                               isFinished: true,
                               startedAt: day(2).addingTimeInterval(-3_000),
                               finishedAt: day(2))

    let rich = MonthlyRecap(workouts: [prWorkout, plainWorkout], events: events, exercises: library)
    let sparse = MonthlyRecap(workouts: [plainWorkout],
                              events: [event(row, 8, 165, 2), event(row, 8, 165, 5)],
                              exercises: library)
    let empty = MonthlyRecap(workouts: [], events: [], exercises: library)

    return ScrollView {
        VStack(spacing: 16) {
            MonthlyRecapCard(recap: rich, surface: Color(.secondarySystemBackground), accent: .pink)
            MonthlyRecapCard(recap: sparse, surface: Color(.secondarySystemBackground), accent: .pink)
            Text(empty.hasData ? "empty recap unexpectedly has data" : "empty recap renders nothing")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
