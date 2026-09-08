import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 06/16/2026
// The performance card shown the moment a workout is completed (before achievement
// pops). It reuses the profile card's look — the user's selected CardStyle
// background (CardBackgroundView), the AGIL logo/wordmark header, rounded white
// type — so it feels like "their" card. Tap anywhere to dismiss, which then lets
// any queued achievement celebrations play.
//
// A handful of session stats in a single condensed row, plus a full-width "Best Set" tile below it.
// The best set is picked by relative effort against the user's own history and can show a
// personal-record treatment — see WorkoutSummary / BestSetScoring for the scoring.
struct PerformanceCardView: View {
    let summary: WorkoutSummary
    let style: CardStyle
    // CLAUDE  Date 09/03/2026
    // The equipped theme's logo asset (see ThemeIcon). Passed in rather than read from
    // ThemeManager because this view has no environment object — and the card is also used
    // to render other people's synced cards, so the mark should be the viewer's, not baked in.
    var logoAsset: String = ThemeIcon.classicLogoAsset
    let onDismiss: () -> Void

    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            card
                .frame(maxWidth: 360)
                .padding(24)
                .scaleEffect(appear ? 1 : 0.92)
                .opacity(appear ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { appear = true }
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        }
    }

    private var card: some View {
        // Claude  Date 06/18/2026 last changed: 07/22/2026 by: Claude
        // Roomier vertically (more inter-section spacing + taller top/bottom padding)
        // so the card reads a little longer on the y-axis. (07/22: the stat tiles that
        // used to carry most of that height collapsed into one row — see statsRow.)
        VStack(spacing: 24) {
            header

            VStack(spacing: 4) {
                Text("Workout Complete")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(summary.date.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            statsRow

            if let best = summary.bestSet {
                bestSetTile(best)
            }

            Text("Tap to continue")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 34)
        .frame(maxWidth: .infinity)
        .background(CardBackgroundView(background: style.background, cornerRadius: 28))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        // Claude  Date 09/02/2026: see ProfileShowcaseCard — outline cards supply
        // their own border, so the white hairline would double it.
        .overlay(RoundedRectangle(cornerRadius: 28)
            .stroke(.white.opacity(style.isOutlined ? 0 : 0.18), lineWidth: 1))
        .shadow(color: shadowColor.opacity(0.4), radius: 14, y: 6)
    }

    // The same AGIL logo + wordmark as the profile card.
    private var header: some View {
        HStack(spacing: 8) {
            AgilLogoMark(assetName: logoAsset, size: 28, cornerRadius: 7)
            Text("AGIL")
                .font(.caption.bold()).tracking(3)
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
    }

    // Claude  Date 06/16/2026 last changed: 07/22/2026 by: Claude
    // (07/22) Was a 2×2 grid of chunky tiles that dominated the card; now a single
    // strip — four equal columns in one shared pill, separated by hairlines — so the
    // session stats read as a caption under the title instead of the main event. The
    // per-tile icons are gone (they cost the width the numbers need at 4-up) and the
    // volume figure is abbreviated past 10k so nothing has to shrink to stay on one line.
    private var statsRow: some View {
        HStack(spacing: 0) {
            // Claude  Date 09/07/2026
            // A cardio-only session swaps the two lifting columns for its own: Sets and
            // Volume are both structurally 0 for bouts, so showing them would read as a
            // failed workout. Still four columns — the strip's widths depend on it. A MIXED
            // session keeps the lifting four; its cardio shows in the History row's label.
            if isCardioOnly {
                statCell("Duration", summary.durationText)
                statDivider
                statCell("Bouts", "\(summary.cardioBouts)")
                statDivider
                statCell("Distance", cardioDistanceText)
                statDivider
                statCell("Calories", cardioCaloriesText)
            } else {
                statCell("Duration", summary.durationText)
                statDivider
                statCell("Sets", "\(summary.completedSets)")
                statDivider
                statCell("Volume", volumeText)
                statDivider
                statCell("Exercises", "\(summary.exerciseCount)")
            }
        }
        .padding(.vertical, 12)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    /// Nothing was lifted and something was ridden/run/rowed.
    private var isCardioOnly: Bool {
        summary.cardioSeconds > 0 && summary.completedSets == 0
    }

    /// "3.10 mi", or an em dash for a machine with no honest distance (stair climber).
    private var cardioDistanceText: String {
        CardioFormat.distance(meters: summary.cardioDistanceMeters, unit: distanceUnit) ?? "—"
    }

    // Claude  Date 09/07/2026
    // An em dash, never a zero, when there's no honest figure: no bodyweight on file, or
    // every bout fell outside CardioPolicy's plausibility band. "0" would read as a fact.
    private var cardioCaloriesText: String {
        summary.cardioCalories.map { "~\(Int($0.rounded()))" } ?? "—"
    }

    // Claude  Date 09/07/2026 — display unit only; the summary carries canonical meters.
    @AppStorage(DistanceUnit.storageKey) private var distanceUnitRaw = DistanceUnit.miles.rawValue
    private var distanceUnit: DistanceUnit { DistanceUnit(rawValue: distanceUnitRaw) ?? .miles }

    private func statCell(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .minimumScaleFactor(0.8).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.18))
            .frame(width: 1, height: 26)
    }

    /// Volume in pounds, abbreviated once it stops fitting a quarter-width column
    /// (12,480 → "12.5k lb").
    private var volumeText: String {
        let pounds = summary.totalVolume.rounded()
        if pounds >= 10_000 {
            return String(format: "%.1fk lb", pounds / 1_000)
        }
        return "\(Int(pounds)) lb"
    }

    // Claude  Date 06/16/2026 last changed: 07/21/2026 by: Claude
    // (07/21) Same single full-width tile, but it now explains WHY the set won. A set
    // that beat the user's all-time best for that lift gets the gold personal-record
    // treatment (trophy, brighter fill, gold hairline); anything else keeps the familiar
    // yellow star. All the wording lives on BestSet (loadText / oneRepMaxText /
    // contextText) so this stays presentation-only.
    private func bestSetTile(_ best: WorkoutSummary.BestSet) -> some View {
        let isPR = best.isPersonalRecord
        let accent = isPR ? Color(red: 1.0, green: 0.84, blue: 0.35) : .yellow

        return VStack(spacing: 4) {
            Label(isPR ? "Personal Record" : "Best Set",
                  systemImage: isPR ? "trophy.fill" : "star.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
            Text(best.exerciseName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text([best.loadText, best.oneRepMaxText].compactMap { $0 }.joined(separator: "  ·  "))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1).minimumScaleFactor(0.7)
            if let context = best.contextText {
                Text(context)
                    .font(.caption2)
                    .foregroundStyle(isPR ? accent : .white.opacity(0.75))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(.white.opacity(isPR ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            if isPR {
                RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.5), lineWidth: 1)
            }
        }
    }

    private var shadowColor: Color {
        if case .color(let hex) = style.background { return Color(hex: hex) }
        // Claude  Date 09/02/2026: outline cards glow in their border colour.
        if case .outlined(_, let stroke) = style.background { return Color(hex: stroke) }
        return .black
    }
}

// Claude  Date 06/16/2026 last changed: 07/21/2026 by: Claude
// (07/21) Builds its own lifts instead of borrowing the seed library, so the tile's new
// wordings are all reachable: the bench set beats three weeks of 225×5 history (gold PR
// path), while the pull-up and single-arm row cover the bodyweight and "per side" load
// text. Drop the `history` argument to see the no-history fallback instead.
#Preview {
    let bench = Exercise(name: "Barbell Bench Press", region: .chest,
                         category: "Chest", liftType: .bench)
    let pullUp = Exercise(name: "Pull-Up", region: .back,
                          category: "Lats", isBodyweight: true)
    let row = Exercise(name: "Single-Arm Row", region: .back,
                       category: "Lats", isUnilateral: true)

    let workout = Workout(
        exercises: [
            LoggedExercise(exerciseId: bench.id, sets: [
                ExerciseSet(reps: 8, weight: 185, completedAt: Date().addingTimeInterval(-1800)),
                ExerciseSet(reps: 5, weight: 245, completedAt: Date())
            ]),
            LoggedExercise(exerciseId: pullUp.id, sets: [
                ExerciseSet(reps: 12, weight: 0, completedAt: Date())
            ]),
            LoggedExercise(exerciseId: row.id, sets: [
                ExerciseSet(reps: 10, weight: 70, completedAt: Date())
            ])
        ],
        startedAt: Date().addingTimeInterval(-3900),
        finishedAt: Date())

    let history = (1...3).map { week in
        ActivityEvent(setId: UUID(), exerciseId: bench.id, reps: 5, weight: 225,
                      loggedAt: Date().addingTimeInterval(-Double(week) * 7 * 86_400))
    }

    return PerformanceCardView(
        summary: WorkoutSummary(workout: workout,
                                exercises: [bench, pullUp, row],
                                history: history),
        style: CardStyle.defaultStyle,
        onDismiss: {}
    )
}
