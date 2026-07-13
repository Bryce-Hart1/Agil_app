import SwiftUI

// Claude  Date 07/13/2026 last changed: 07/13/2026 by: Claude
// The top "notch" pill: shows the CURRENT world (icon + label) plus a stat from
// the OTHER world — today's calories vs goal while lifting, the lifting week
// streak while in food — and tapping it switches worlds. Replaces the old tag-0
// switcher tab in the bottom bar.
// (Rework: it now lives INSIDE each root screen's navigation bar as the centered
// principal toolbar item — see modeNotchToolbar() below — instead of a top
// safe-area strip, which turned out to cover the nav bars' own buttons. It owns
// the mode flip directly via @AppStorage; RootTabView reacts to the change.)
struct ModeNotch: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    // Claude  Date 07/13/2026
    // Same persisted key RootTabView reads — flipping it here swaps the whole
    // tab set there (and its onChange restores that world's last-selected tab).
    @AppStorage("appMode") private var modeRaw = AppMode.lifting.rawValue
    private var mode: AppMode { AppMode(rawValue: modeRaw) ?? .lifting }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                modeRaw = mode.toggled.rawValue
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.subheadline)
                    .foregroundStyle(theme.current.accent)
                Text(mode.label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(stat)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.current.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(theme.current.accent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Switch to \(mode.toggled.label)")
    }

    // Claude  Date 07/13/2026
    // Cross-mode stat, recomputed in body: nutritionDay(for:) is the same O(n)
    // filter the Journal already runs per render, and the streak helper only
    // buckets workout dates into week-starts. Alpha-scale data makes memoization
    // pure overhead. Date() here means a midnight rollover shows the old "today"
    // until the next store publish — accepted for alpha.
    private var stat: String {
        switch mode {
        case .lifting:
            let eaten = Int(store.nutritionDay(for: Date()).totals.calories)
            let goal = Int(store.nutritionGoals.calories)
            return "\(eaten.formatted()) / \(goal.formatted()) cal"
        case .nutrition:
            let streak = ProfileStats.weekStreak(of: store.workouts.map(\.date))
            return "\(streak)-wk streak"
        }
    }
}

extension View {
    // Claude  Date 07/13/2026
    // Mounts the notch as the nav bar's centered (principal) item. Each root tab
    // view applies this; the screen's own leading/trailing buttons keep their
    // spots on either side. Pushed detail screens have their own toolbars, so the
    // notch naturally disappears there — including the live workout editor.
    func modeNotchToolbar() -> some View {
        toolbar {
            ToolbarItem(placement: .principal) {
                ModeNotch()
            }
        }
    }
}

#Preview {
    NavigationStack {
        Text("Content")
            .navigationTitle("Preview")
            .modeNotchToolbar()
    }
    .environmentObject(AppStore())
    .environmentObject(ThemeManager())
}
