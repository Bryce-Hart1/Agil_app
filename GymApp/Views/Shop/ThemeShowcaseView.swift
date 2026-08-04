import SwiftUI

// Claude  Date 08/03/2026
// "What the app actually looks like in this theme" — the hero of the theme detail
// screen in the Shop.
//
// It replaces ThemeMiniMock, which drew abstract capsules and rounded rectangles.
// That showed the palette but not the product: you could see three colours without
// knowing whether your stat tiles would be legible or what the typeface did to a
// heading. This renders a small slice of real app UI instead — a Progress-style
// header, a row of StatCards, a workout row, a progress bar and a primary button.
//
// The one hard rule in this file: EVERY colour comes from the `theme` that was
// passed in, never from the equipped one. Do not add @EnvironmentObject
// ThemeManager here, and do not compose views that read theme.current internally
// (AgilTabBar is the trap — it looks reusable but renders in the equipped theme).
// "Just temporarily select the theme" is not an option either: ThemeManager.select
// hard-guards on isUnlocked, and the whole point is previewing a theme you don't
// own yet.
struct ThemeShowcaseView: View {
    let theme: AppTheme

    // Claude  Date 08/03/2026
    // The scheme the host screen is in, used only as the fallback for adaptive
    // themes (Classic), whose preferredColorScheme is nil because they follow the
    // system. Fixed themes ignore this and pin their own.
    @Environment(\.colorScheme) private var hostScheme

    // Claude  Date 08/03/2026
    // Forcing the scheme does two jobs at once: it makes .primary / .secondary text
    // resolve for the previewed theme, and it drives the trait lookup inside
    // AppTheme.dynamicColor so adaptive themes resolve to the right hex. Without it,
    // previewing a light theme while a dark theme is equipped paints white text onto
    // a white surface.
    private var previewScheme: ColorScheme { theme.preferredColorScheme ?? hostScheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            statRow
            workoutRow
            progressRow
            primaryButton
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.background)
        // Themes carry a typeface as well as a palette, so preview that too.
        .fontDesign(theme.fontDesign.design)
        .environment(\.colorScheme, previewScheme)
        // It's a picture of the app, not the app — nothing in here should be tappable.
        .allowsHitTesting(false)
    }

    // A stand-in for a screen title, so the theme's heading type is visible.
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundStyle(theme.accent)
            Text("Progress")
                .font(.title3.weight(.bold))
            Spacer()
            Image(systemName: "person.crop.circle.fill")
                .font(.title3)
                .foregroundStyle(theme.accent)
        }
    }

    // Claude  Date 08/03/2026
    // The real StatCard from the Progress dashboard — it already takes surface and
    // accent as parameters, which is exactly why it can be reused here: it renders
    // in whatever palette it's handed rather than reaching for the equipped theme.
    private var statRow: some View {
        HStack(spacing: 8) {
            StatCard(title: "Workouts", value: "128", systemImage: "figure.strengthtraining.traditional",
                     surface: theme.surface, accent: theme.accent)
            StatCard(title: "Streak", value: "12", systemImage: "flame.fill",
                     surface: theme.surface, accent: theme.accent)
            StatCard(title: "Volume", value: "24.6k", systemImage: "scalemass.fill",
                     surface: theme.surface, accent: theme.accent)
        }
    }

    // A set row, mirroring the shape of the theme editor's PreviewCard.
    private var workoutRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Bench Press").font(.subheadline.weight(.semibold))
                Text("3 × 8").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("135 lb")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accent)
                .monospacedDigit()
        }
        .padding(10)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 10))
    }

    // Claude  Date 08/03/2026
    // An accent-filled meter in the same visual language as the nutrition MacroBar,
    // rebuilt in four lines here rather than reused — MacroBar brings its own
    // grow-in animation and MacroPalette tints, neither of which belongs in a still
    // preview that has to stay on the theme's own colours.
    private var progressRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Weekly goal").font(.caption)
                Spacer()
                Text("4 / 5").font(.caption.weight(.semibold)).monospacedDigit()
            }
            .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.surface)
                    Capsule().fill(theme.accent).frame(width: geo.size.width * 0.8)
                }
            }
            .frame(height: 8)
        }
    }

    private var primaryButton: some View {
        Text("Start Workout")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: 12))
            // White, not .primary: the label sits on the accent fill, not on the
            // background, so it must not flip with the colour scheme. Every built-in
            // accent is mid-to-dark enough to carry white text.
            .foregroundStyle(.white)
    }
}

#Preview("Midnight") {
    ThemeShowcaseView(theme: .midnight)
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
}

#Preview("Deep Sea") {
    ThemeShowcaseView(theme: .deep_sea)
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
}
