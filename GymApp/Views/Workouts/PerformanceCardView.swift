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
// First pass: a handful of session stats. Designed to grow (more stats, a smarter
// "best set"); the layout just adds tiles.
struct PerformanceCardView: View {
    let summary: WorkoutSummary
    let style: CardStyle
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
        VStack(spacing: 18) {
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

            statsGrid

            if let best = summary.bestSet {
                bestSetTile(best)
            }

            Text("Tap to continue")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 2)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(CardBackgroundView(background: style.background))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: shadowColor.opacity(0.4), radius: 14, y: 6)
    }

    // The same AGIL logo + wordmark as the profile card.
    private var header: some View {
        HStack(spacing: 8) {
            Image("AppLogo")
                .resizable().scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            Text("AGIL")
                .font(.caption.bold()).tracking(3)
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statTile("Duration", summary.durationText, systemImage: "clock")
            statTile("Sets", "\(summary.completedSets)", systemImage: "checklist")
            statTile("Volume", "\(Int(summary.totalVolume.rounded())) lb", systemImage: "scalemass")
            statTile("Exercises", "\(summary.exerciseCount)", systemImage: "dumbbell")
        }
    }

    private func statTile(_ title: String, _ value: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private func bestSetTile(_ best: WorkoutSummary.BestSet) -> some View {
        VStack(spacing: 4) {
            Label("Best Set", systemImage: "star.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.yellow)
            Text(best.exerciseName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text("\(Int(best.weight)) lb × \(best.reps)  ·  ~\(Int(best.estimatedOneRepMax)) lb 1RM")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var shadowColor: Color {
        if case .color(let hex) = style.background { return Color(hex: hex) }
        return .black
    }
}

#Preview {
    let store = AppStore()
    let workout = Workout(exercises: [
        LoggedExercise(exerciseId: store.exercises[0].id, sets: [
            ExerciseSet(reps: 8, weight: 185, completedAt: Date().addingTimeInterval(-1800)),
            ExerciseSet(reps: 5, weight: 225, completedAt: Date())
        ])
    ])
    return PerformanceCardView(
        summary: WorkoutSummary(workout: workout, exercises: store.exercises),
        style: CardStyle.defaultStyle,
        onDismiss: {}
    )
}
