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
    // Claude  Date 07/28/2026
    // The tag of the tab this notch belongs to. Only used to decide whether this
    // instance is the visible one when reporting its frame to the tour — see
    // activeTabTag in TourFrames.swift for why that matters.
    let tab: Int

    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.activeTabTag) private var activeTabTag
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
            // Claude  Date 07/13/2026 last changed: 07/21/2026 by: Claude
            // Tightened to fit: the pill is the nav bar's principal item, so its width
            // is whatever the screen's leading/trailing buttons leave behind, and the
            // monospaced theme font pushed the lifting-side content ("Lifting · 1,850
            // / 2,200 cal") past that — it clipped. Savings, in order: the "·"
            // separator and its two gaps are gone, the gaps went 8 → 6, the stat
            // dropped to caption2, and the stat string itself is compact (see `stat`).
            // The lineLimit/minimumScaleFactor pair is the backstop that guarantees it
            // scales instead of clipping on a narrower phone or at a larger Dynamic
            // Type size.
            HStack(spacing: 6) {
                // Claude  Date 07/13/2026
                // Food's icon is a custom template asset (bowl-food), lifting is an
                // SF Symbol. Frame the custom image to sit alongside the subheadline
                // text at the same visual weight the symbol had; template rendering
                // lets it pick up the accent tint.
                Group {
                    if mode.iconIsCustomAsset {
                        Image(mode.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 17, height: 17)
                    } else {
                        Image(systemName: mode.icon)
                            .font(.subheadline)
                    }
                }
                .foregroundStyle(theme.current.accent)
                Text(mode.label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(stat)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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
        // Claude  Date 07/27/2026
        // Report the pill's real frame for the tour's spotlight. This has to go
        // through the global-frame registry rather than .tourTarget: the notch is a
        // principal toolbar item, so it's hosted in a UIKit navigation bar and a
        // SwiftUI preference can't escape it. The synthesized rect that used to
        // stand in for this assumed a fixed 210×36 dead-centered pill; the real one
        // hugs its content and UIKit shifts it aside for the screen's own trailing
        // button, so the spotlight landed on the "+". Inert unless a tour is running,
        // and only the visible tab's notch reports — every root screen has one, and
        // their pills don't all sit at the same x.
        .tourTargetGlobal(.modeNotch, active: store.tourActive && tab == activeTabTag)
    }

    // Claude  Date 07/13/2026 last changed: 07/21/2026 by: Claude
    // Cross-mode stat, recomputed in body: nutritionDay(for:) is the same O(n)
    // filter the Journal already runs per render, and the streak helper only
    // buckets workout dates into week-starts. Alpha-scale data makes memoization
    // pure overhead. Date() here means a midnight rollover shows the old "today"
    // until the next store publish — accepted for alpha.
    private var stat: String {
        switch mode {
        case .lifting:
            // No thousands separators and no spaces around the slash: at four digits
            // a comma buys nothing and the grouped form is what overflowed the pill.
            let eaten = Int(store.nutritionDay(for: Date()).totals.calories)
            let goal = Int(store.nutritionGoals.calories)
            return "\(eaten)/\(goal) cal"
        case .nutrition:
            let streak = ProfileStats.weekStreak(of: store.workouts.map(\.date))
            return "\(streak)-wk streak"
        }
    }
}

extension View {
    // Claude  Date 07/13/2026 last changed: 07/28/2026 by: Claude
    // Mounts the notch as the nav bar's centered (principal) item. Each root tab
    // view applies this; the screen's own leading/trailing buttons keep their
    // spots on either side. Pushed detail screens have their own toolbars, so the
    // notch naturally disappears there — including the live workout editor.
    // (07/28) Takes the screen's tab tag, so the notch can tell whether it's the
    // visible one — every root screen mounts an instance and they all report to the
    // tour's single .modeNotch slot.
    //
    // IMPORTANT: "centered" is UIKit's centering, which splits the space the bar
    // BUTTONS leave, not the bar. A screen with only a trailing button pushes the
    // pill left; one with a wide leading item pushes it right. Screens that would
    // otherwise be lopsided balance themselves with an invisible counterweight item
    // — see navBarBalancer below.
    func modeNotchToolbar(tab: Int) -> some View {
        toolbar {
            ToolbarItem(placement: .principal) {
                ModeNotch(tab: tab)
            }
        }
    }
}

// Claude  Date 07/28/2026
// An invisible stand-in that reserves exactly as much width as the view it mirrors,
// so a nav bar with buttons on only one side still centers its principal item.
// Callers pass a copy of the real button's LABEL (not the Button), which is what
// makes the widths match by construction rather than by a hand-tuned constant that
// drifts with the font, the Dynamic Type size, or a glyph swap.
func navBarBalancer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
        .opacity(0)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
}

#Preview {
    NavigationStack {
        Text("Content")
            .navigationTitle("Preview")
            .modeNotchToolbar(tab: 1)
    }
    .environmentObject(AppStore())
    .environmentObject(ThemeManager())
}
