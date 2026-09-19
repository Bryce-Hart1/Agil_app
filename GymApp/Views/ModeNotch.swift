import SwiftUI

// Claude  Date 07/13/2026 last changed: 08/29/2026 by: Claude
// The top "notch" pill: shows the CURRENT world (icon; the text label came out
// 08/23 to make room for the coin balance) plus a stat from the OTHER world — today's calories vs goal while lifting, the lifting week
// streak while in food — and tapping it switches worlds. Replaces the old tag-0
// switcher tab in the bottom bar.
// (Rework: it now lives INSIDE each root screen's navigation bar as the centered
// principal toolbar item — see modeNotchToolbar() below — instead of a top
// safe-area strip, which turned out to cover the nav bars' own buttons. It owns
// the mode flip directly via @AppStorage; RootTabView reacts to the change.)
//
// Claude  Date 08/29/2026
// The pill is now ALIVE. Three additions, one state machine:
//   1. A tracing light runs the capsule's rim (RimTrace below) — a one-time
//      intro per launch, paused on non-visible tabs. (09/17/26)
//   2. Transient MESSAGES briefly replace the pill's standard content: a
//      once-per-launch "Tap to flip" hint, and after every flip a banner naming
//      the side you landed on with its headline stat in bold ("243 cal
//      remaining" / "4 this wk").
//   3. The daily check-in award moved IN here from the floating
//      DailyCheckInToast overlay (now deleted): +coins and the week dots play as
//      a message inside the pill, so the reward reads as part of the app's
//      chrome instead of a banner floating over it. The politeness gate
//      (yield to full-screen celebrations) came along — see presentableCheckIn.
// It's also a touch larger all around. Growth is padding + one font step, which
// UIKit's principal-item sizing absorbs without touching the bar buttons: the
// principal item is only ever GIVEN the space the buttons leave, so a bigger
// pill compresses (lineLimit + minimumScaleFactor backstop) rather than
// crowding them.
//
// Claude  Date 08/31/2026
// THE CAPSULE IS A FIXED SIZE — it holds the largest face's geometry at all
// times and never grows or shrinks as messages come and go. Anything added to
// the message set must be measured too, or it will start the pumping this was
// written to stop: see sizingScaffold.
//
// The structure that falls out of that: the pill is a cross-fading FACE (resting
// content or one message) plus a STANDING coin chip that outlives every face and
// is never dropped or squeezed — see pillBody and coinChip. Adding a message is a
// three-line change and cannot break either property; pillBody says why.
struct ModeNotch: View {
    // Claude  Date 07/28/2026
    // The tag of the tab this notch belongs to. Only used to decide whether this
    // instance is the visible one when reporting its frame to the tour — see
    // activeTabTag in TourFrames.swift for why that matters.
    let tab: Int

    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.activeTabTag) private var activeTabTag
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Claude  Date 07/13/2026 last changed: 09/05/2026 by: Bryce Hart
    // Same persisted key RootTabView reads. Flipping it swaps the tab set while
    // RootTabView's shared selection keeps the user in the matching tab position.
    @AppStorage("appMode") private var modeRaw = AppMode.lifting.rawValue
    private var mode: AppMode { AppMode(rawValue: modeRaw) ?? .lifting }

    // Claude  Date 08/29/2026
    // What the pill is saying right now instead of its standard content. One slot,
    // last writer wins: a flip banner interrupts the hint, a check-in interrupts
    // either. `messageTask` is the sleeper that will clear the current message —
    // cancelled by whoever takes the slot over (see show(_:for:)).
    private enum NotchMessage: Equatable {
        case flipHint
        case sideBanner(AppMode)
        case checkIn(DailyCheckIn.Award)
    }
    @State private var message: NotchMessage?
    @State private var messageTask: Task<Void, Never>?

    // Once per LAUNCH, not per instance: every root screen mounts a notch, and
    // each showing its own hint as you toured the tabs would nag.
    private static var didShowFlipHint = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                modeRaw = mode.toggled.rawValue
            }
        } label: {
            // Claude  Date 08/31/2026
            // The balance is ALWAYS here. It is not negotiable against the faces,
            // and there is no fit test deciding whether it earns its place.
            //
            // A ViewThatFits ladder (offer face+chip, fall back to face alone) lived
            // here for exactly one iteration and dropped the chip on every screen.
            // The reason is worth keeping written down, because it is not obvious:
            // ViewThatFits measures each candidate at its IDEAL size, and
            // minimumScaleFactor does not reduce a Text's ideal width — it only lets
            // the glyphs shrink at draw time. So the candidates were measured with
            // the flip banner at full unscaled width, the widest face decided for
            // every face, both rungs overflowed the bar, and ViewThatFits kept its
            // last child — the one without coins. The balance disappeared even on
            // screens with room to spare.
            //
            // What replaces it is the arrangement that worked before any of this:
            // the chip is fixedSize + layoutPriority(1), so the HStack satisfies it
            // FIRST and the face region takes what's left. Squeeze now lands on the
            // faces' own scale factors, which is the right place for it — a stat is
            // a glanceable extra, the balance is a number you read.
            pillBody
            // Claude  Date 08/29/2026
            // "A touch larger": 12/6 → 14/9 padding, stat fonts caption2 → caption.
            // The nav bar's principal slot absorbs the height (44pt available) and
            // the scale-factor backstops absorb any width squeeze.
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(theme.current.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(theme.current.accent.opacity(0.25), lineWidth: 1)
            )
            // Claude  Date 08/29/2026 last changed: 09/17/2026 by: CLAUDE
            // The living rim. Sits ABOVE the static ring so the streak traces over it, and
            // paused on tabs that aren't on screen so seven live notches don't each burn a
            // 40fps timeline. Reduce Motion gets `settled`: the lit rim the intro ends on,
            // drawn with no motion at all (it used to get the faint ring alone).
            .overlay {
                RimTrace(color: theme.current.accent,
                         paused: tab != activeTabTag,
                         settled: reduceMotion)
            }
        }
        .buttonStyle(.plain)
        // Claude  Date 08/23/2026 last changed: 08/29/2026 by: Claude
        // Spelled out because none of this is readable from the visuals any more.
        // While the check-in message plays, VoiceOver gets the award instead of
        // the standard readout — same sentence the old toast spoke.
        .accessibilityLabel(accessibilityText)
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
        // Claude  Date 08/29/2026
        // Every live instance sees the flip; each plays the banner on its own pill.
        // Only the visible one is seen, and the hidden ones clearing themselves a
        // couple of seconds later is free.
        .onChange(of: modeRaw) { newRaw in
            play(.sideBanner(AppMode(rawValue: newRaw) ?? .lifting),
                 for: .seconds(2.2))
        }
        // Claude  Date 08/29/2026
        // The once-per-launch "Tap to flip" hint, a beat after the pill settles.
        // Gated to the visible instance so the flag isn't burned by a hidden tab.
        .task {
            guard !Self.didShowFlipHint, tab == activeTabTag else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, message == nil, !store.tourActive else { return }
            Self.didShowFlipHint = true
            play(.flipHint, for: .seconds(2))
        }
        // Claude  Date 08/29/2026
        // The daily check-in award, formerly DailyCheckInToast. Keyed by the
        // award's id THROUGH the politeness gate: while a celebration owns the
        // screen presentableCheckIn is nil, and the moment the gate clears the id
        // appears and this task fires — the same "waits rather than drops" behaviour
        // the toast had. Only the visible instance consumes it; dismissing at the
        // end is what lets recordDailyCheckIn's next award through tomorrow.
        .task(id: presentableCheckIn?.id) {
            guard let award = presentableCheckIn, tab == activeTabTag else { return }
            // The LIGHT tap, deliberately not the .success notification haptic —
            // that heavier one is the app's signature for badges and PRs, and a
            // daily login must not land in the hand like one of those.
            tapHaptic()
            play(.checkIn(award), for: .milliseconds(3200))
            try? await Task.sleep(for: .milliseconds(3400))
            store.dismissCheckIn()
        }
    }

    // Claude  Date 08/31/2026
    // The pill = one cross-fading FACE plus the standing coin chip. Splitting them
    // is what lets the balance hold still while the face changes underneath it: the
    // chip is outside the ZStack, so it takes no part in the transitions and never
    // moves — the scaffold fixes the face region's width, so the chip's x is
    // constant too.
    //
    // ADDING A MESSAGE LATER: write the case, render it in messageView, list it in
    // sizingMessages, done. It cannot break either of the two properties this file
    // protects. It cannot evict the balance — the chip is satisfied before the face
    // region gets a single point. And it cannot make the pill pump — the scaffold
    // already holds the union. A long one only costs ITSELF legibility, scaling down
    // inside a face region whose width it shares with the others, which is why the
    // stats here are written short.
    private var pillBody: some View {
        HStack(spacing: 8) {
            ZStack {
                sizingScaffold

                if let message {
                    messageView(for: message)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    standardContent
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }

            coinChip
        }
    }

    // Claude  Date 08/23/2026 last changed: 08/31/2026 by: Claude
    // The spendable balance. Same glyph as the Shop's own chip so it reads as the
    // same number wherever you meet it. It is NOT its own tap target: the whole pill
    // is one mode-switch Button, and nesting a second control inside a principal
    // toolbar item to save one tap to the Shop isn't worth the ambiguity of a pill
    // where half the surface does something different. Sits after the swap arrow so
    // the mode-switch group stays visually intact.
    //
    // Coins.compact caps this at FOUR characters ("20", "300", "3.7k"), which is what
    // makes the chip's width independent of the balance — the whole reason the
    // previous full-number version was a layout risk. .fixedSize plus the layout
    // priority makes the balance the LAST thing to give inside the pill: if anything
    // has to shrink it should be a face's text, which is glanceable extra, not the
    // number. Four characters is small enough that in practice nothing has to.
    //
    // (08/31) Lifted OUT of the resting face so it belongs to the pill rather than to
    // one face — it now stands through the flip banner, the hint and the check-in
    // instead of blinking out for three seconds whenever one plays.
    private var coinChip: some View {
        coinAmount(Coins.compact(theme.balance), weight: .semibold)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
    }

    // Claude  Date 08/31/2026
    // The coin glyph beside a number — the balance on the chip, "+20" on the
    // check-in face.
    //
    // DELIBERATELY NOT A `Label`. Both of these were Labels, and on device the glyph
    // drew while the number did not: this pill is a principal toolbar item hosted in
    // a UIKit navigation bar, and that bar imposes a bar-button label style that
    // renders icon-only, silently dropping every Label's title. Nothing about the
    // call site hints at it — the text is right there in the source — and the pill
    // had been shipping a coin glyph with no balance next to it since the chip
    // landed on 08/23. (Two other screens hit the same wall and answered it with an
    // explicit .labelStyle(.titleAndIcon): PresetsListView and MonthlyRecapCard.)
    //
    // An HStack is the version that cannot be restyled out from under us by ANY
    // ancestor, here or in whatever this pill gets embedded in next, so it's what
    // both coin readouts use.
    private func coinAmount(_ text: String, weight: Font.Weight) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.hexagongrid.fill")
            Text(text)
                .monospacedDigit()
        }
        .font(.caption.weight(weight))
        .foregroundStyle(theme.current.accent)
    }

    // Claude  Date 07/13/2026 last changed: 08/31/2026 by: Claude
    // The pill's resting face: which world you're in, the OTHER world's stat, and the
    // swap affordance. The coin balance used to live at the end of this row — it's
    // the pill-level coinChip now, so this is purely the mode-switch group.
    private var standardContent: some View {
        HStack(spacing: 6) {
            modeIcon(for: mode)
            Text(stat)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Image(systemName: "arrow.left.arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // Claude  Date 08/31/2026
    // THE PILL DOES NOT RESIZE. Every face it can ever show is laid out here at
    // once and hidden, so the ZStack above reports the UNION of their sizes and the
    // capsule takes the widest/tallest — no jump when a message arrives or leaves,
    // and no jump between one message and the next. The real face is centered
    // inside that constant frame.
    //
    // Measured from the LIVE faces rather than a hand-tuned width constant, which is
    // what keeps it honest as the strings change (a four-digit calorie count, a
    // two-digit workout count). A future NotchMessage case only has to be added to
    // `sizingMessages` to be accounted for.
    //
    // (08/31) Scopes the FACE region only — the coin chip is a sibling of this stack,
    // not a member of it, so the chip's own width is added once, after.
    //
    // This cannot crowd the nav bar's own buttons: the principal item is only ever
    // GIVEN the width the leading/trailing buttons leave, so a scaffold wider than
    // that is compressed into it — and only the oversized face (the flip banner)
    // scales, since the narrower faces still fit the same proposal at full size.
    private var sizingScaffold: some View {
        ZStack {
            standardContent
            ForEach(Self.sizingMessages.indices, id: \.self) { index in
                messageView(for: Self.sizingMessages[index])
            }
        }
        .opacity(0)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    // Claude  Date 08/31/2026
    // Every message face, at its worst-case content: both sides' banners (the pill
    // must not change width when you flip), and a check-in on the last paying day
    // so the full dot row is counted. `static` so the sample Award's UUID is minted
    // once rather than on every render.
    private static let sizingMessages: [NotchMessage] = [
        .flipHint,
        .sideBanner(.lifting),
        .sideBanner(.nutrition),
        .checkIn(.init(coins: DailyCheckIn.coinsPerDay, dayInWeek: DailyCheckIn.daysPerWeek))
    ]

    // Claude  Date 08/29/2026
    // The three transient faces. Each keeps the pill's single-line shape (the nav
    // bar caps height, not width) with the same scale-factor backstop as the
    // standard face.
    @ViewBuilder
    private func messageView(for message: NotchMessage) -> some View {
        switch message {
        case .flipHint:
            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                    .font(.caption)
                    .foregroundStyle(theme.current.accent)
                Text("Tap to flip")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)

        case .sideBanner(let side):
            // The side you just landed on + its OWN headline stat in bold (the
            // resting face shows the other world's stat; this moment is about
            // where you arrived).
            HStack(spacing: 6) {
                modeIcon(for: side)
                Text(side.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(bannerStat(for: side))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

        case .checkIn(let award):
            // The old DailyCheckInToast's content, verbatim vocabulary: the coin
            // glyph everything else uses, and the same week track as the Shop's
            // "This week" strip so the two read as one feature.
            HStack(spacing: 10) {
                coinAmount("+\(award.coins)", weight: .bold)
                HStack(spacing: 5) {
                    ForEach(1...DailyCheckIn.daysPerWeek, id: \.self) { day in
                        Circle()
                            .fill(day <= award.dayInWeek
                                  ? theme.current.accent
                                  : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
    }

    // Claude  Date 07/13/2026 last changed: 08/29/2026 by: Claude
    // Food's icon is a custom template asset (bowl-food), lifting is an SF Symbol.
    // Factored out because the flip banner draws the icon too. The custom image is
    // framed to sit alongside the text at the same visual weight the symbol has;
    // template rendering lets it pick up the accent tint.
    @ViewBuilder
    private func modeIcon(for mode: AppMode) -> some View {
        Group {
            if mode.iconIsCustomAsset {
                Image(mode.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: mode.icon)
                    .font(.subheadline)
            }
        }
        .foregroundStyle(theme.current.accent)
    }

    // Claude  Date 08/29/2026
    // Take over the message slot: cancel whatever sleeper was going to clear the
    // previous message, show the new one, and clear it after `duration` — but only
    // if it's still ours (a later message may have taken the slot meanwhile).
    private func play(_ msg: NotchMessage, for duration: Duration) {
        messageTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            message = msg
        }
        messageTask = Task { @MainActor in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, message == msg else { return }
            withAnimation(.easeInOut(duration: 0.25)) { message = nil }
        }
    }

    // Claude  Date 08/29/2026
    // When it's polite to surface the daily-bonus award — RootTabView's old
    // checkInToast gate, moved here with the view that renders it. Every layer
    // listed owns the whole screen; the award yields to all of them and shows on
    // the next render once they're gone, because AppStore.pendingCheckIn holds it
    // until explicitly dismissed.
    private var presentableCheckIn: DailyCheckIn.Award? {
        guard store.profile.hasOnboarded,
              !store.tourActive,
              store.pendingWorkoutSummary == nil,
              store.pendingCelebrations.isEmpty,
              store.pendingPromotions.isEmpty,
              store.pendingCardUnlock.isEmpty,
              store.pendingFoundersUnlock.isEmpty
        else { return nil }
        return store.pendingCheckIn
    }

    private var accessibilityText: String {
        if case .checkIn(let award) = message {
            return "Daily bonus. \(award.coins) coins. Day \(award.dayInWeek) of \(DailyCheckIn.daysPerWeek) this week."
        }
        return "\(mode.label) mode. \(stat). \(theme.balance) coins. Switch to \(mode.toggled.label)."
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

    // Claude  Date 08/29/2026 last changed: 08/31/2026 by: Claude
    // The flip banner's headline: the arrived-at side's own key number. Kept in
    // the pill's compact vocabulary ("cal", not "calories") — bold carries the
    // emphasis, width stays honest on narrow phones.
    //
    // (08/31) Shortened again: "remaining" → "left", "this week" → "this wk". These
    // two strings set the face region's width for every face, so each character
    // here is one the resting stat and the check-in row pay for too. "wk" is not a
    // new abbreviation — the resting stat has read "3-wk streak" since July.
    //
    // (09/06) The side label already says Lifting, so repeating "workouts" made the
    // smallest toolbar slot truncate without adding meaning. "3 this wk" preserves
    // the number and timeframe and now fits beside the standing coin balance.
    private func bannerStat(for mode: AppMode) -> String {
        switch mode {
        case .nutrition:
            let eaten = Int(store.nutritionDay(for: Date()).totals.calories)
            let goal = Int(store.nutritionGoals.calories)
            let remaining = goal - eaten
            return remaining >= 0
                ? "\(remaining) cal left"
                : "\(-remaining) cal over"
        case .lifting:
            let calendar = Calendar.current
            let count: Int
            if let week = calendar.dateInterval(of: .weekOfYear, for: Date()) {
                count = store.workouts.filter {
                    $0.date >= week.start && $0.date < week.end
                }.count
            } else {
                count = 0
            }
            return "\(count) this wk"
        }
    }
}

// Claude  Date 08/29/2026
// The light that laps the pill's rim. A single dashed capsule stroke whose dash
// is one bright segment (~30% of the perimeter) and one gap (the rest); driving
// dashPhase through exactly one perimeter per lap moves the segment around the
// edge with a clean wraparound — the trick .trim can't do without stitching two
// arcs at the seam. A blurred copy underneath gives the segment a soft glow.
// TimelineView recomputes the phase from the clock each frame, so there's no
// repeatForever animation for other state changes to hijack; `paused` freezes
// the timeline entirely for off-screen instances.
//
// CLAUDE  Date 09/17/2026 last changed: 09/18/2026 by: CLAUDE
// A ONE-TIME intro (Bryce, 9/17/26), not a loop: ~6.5s forward, back, forward — easing to
// a stop and away at each turn — then it fills the whole rim and stays lit for the session.
// (09/18) Every timing cut to a third, ~59s → ~20s: same laps and turns at 3x the speed.
private struct RimTrace: View {
    let color: Color
    let paused: Bool
    // CLAUDE  Date 09/17/2026
    // Skip the intro and draw the lit rim it ends on. Reduce Motion takes this, so it gets
    // the settled look with no motion at all rather than a bare pill.
    var settled: Bool = false

    // CLAUDE  Date 09/17/2026 last changed: 09/18/2026 by: CLAUDE
    // The intro's legs: laps travelled (sign = direction) and seconds taken. They net +6
    // laps, so the streak finishes where it started — top-centre — and the fill can spread
    // from there symmetrically. Leg 2's quarter-lap puts the two turns at different places.
    private struct Leg { let laps, duration: Double }
    private static let legs: [Leg] = [Leg(laps:  5.50, duration: 6.5),
                                      Leg(laps: -5.25, duration: 6.2),
                                      Leg(laps:  5.75, duration: 6.7)]

    /// Ramp at each end of every leg: the brake into a turn, the pull away out of it.
    private static let ease: TimeInterval = 0.37
    /// Seconds for the streak to grow from its resting length to the whole rim.
    private static let fill: TimeInterval = 0.47
    /// The moving streak's length, as a fraction of the rim.
    private static let streak: CGFloat = 0.3
    private static let runtime: TimeInterval = legs.reduce(0) { $0 + $1.duration }

    // CLAUDE  Date 09/17/2026
    // The intro's clock starts when the first notch draws — so, a fresh launch, since this
    // is a static. Shared by every notch, so all tabs stay in step, and once it has run
    // nothing here moves again until the app is launched again.
    private static let epoch = Date()

    var body: some View {
        Group {
            if settled {
                ring(rim: (center: 0, length: 1), perimeter: 1)
            } else {
                TimelineView(RimSchedule(paused: paused)) { context in
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        // Capsule perimeter: two straight runs + the two end caps' circle.
                        let perimeter = max(2 * (w - h) + .pi * h, 1)
                        ring(rim: Self.rim(at: context.date), perimeter: perimeter)
                    }
                }
            }
        }
        // A custom schedule is only read when the TimelineView is built, so pausing
        // (tab switch) rebuilds it rather than trusting it to notice the new flag.
        .id(paused)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // The lit streak, plus a blurred copy under it for the glow.
    private func ring(rim: (center: CGFloat, length: CGFloat), perimeter: CGFloat) -> some View {
        ZStack {
            RimPath()
                .stroke(color.opacity(0.35),
                        style: Self.stroke(3, perimeter: perimeter, rim: rim))
                .blur(radius: 2)
            RimPath()
                .stroke(color.opacity(0.9),
                        style: Self.stroke(1.5, perimeter: perimeter, rim: rim))
        }
    }

    // CLAUDE  Date 09/17/2026
    // The lit streak at a moment: center and length as fractions of the rim, clockwise from
    // top-centre. Walks the legs while the intro runs, then grows to the full rim and stays
    // there — `smooth` is already 1 past the fill, so no separate settled branch is needed.
    private static func rim(at date: Date) -> (center: CGFloat, length: CGFloat) {
        let clock = max(0, date.timeIntervalSince(epoch))
        guard clock < runtime else {
            return (0, streak + (1 - streak) * smooth(min(1, (clock - runtime) / fill)))
        }
        var travel = 0.0
        var elapsed = clock
        for leg in legs {
            guard elapsed < leg.duration else {
                travel += leg.laps
                elapsed -= leg.duration
                continue
            }
            travel += leg.laps * cruise(elapsed / leg.duration, ramp: ease / leg.duration)
            break
        }
        return (CGFloat(travel - travel.rounded(.down)), streak)
    }

    /// 0→1 across a leg with a linear speed ramp at each end: pull away, cruise, brake.
    private static func cruise(_ u: Double, ramp a: Double) -> Double {
        if u < a { return u * u / (2 * a * (1 - a)) }
        if u > 1 - a { return 1 - (1 - u) * (1 - u) / (2 * a * (1 - a)) }
        return (u - a / 2) / (1 - a)
    }

    private static func smooth(_ u: Double) -> CGFloat { CGFloat(u * u * (3 - 2 * u)) }

    // The streak as a dash. A full rim is a plain stroke — a zero-length gap in the
    // dash array isn't something to hand Core Graphics.
    private static func stroke(_ width: CGFloat, perimeter: CGFloat,
                               rim: (center: CGFloat, length: CGFloat)) -> StrokeStyle {
        guard rim.length < 0.999 else { return StrokeStyle(lineWidth: width, lineCap: .round) }
        let dash = perimeter * rim.length
        return StrokeStyle(lineWidth: width, lineCap: .round,
                           dash: [dash, perimeter - dash],
                           dashPhase: -(rim.center - rim.length / 2) * perimeter)
    }

    // CLAUDE  Date 09/17/2026
    // 40fps through the intro and then nothing at all: the schedule ENDS once the rim is
    // lit, so a settled notch costs no frames for the rest of the session. Paused
    // (off-screen) notches get their first frame only.
    private struct RimSchedule: TimelineSchedule {
        let paused: Bool

        func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
            var next: Date? = startDate
            return AnyIterator {
                guard let current = next else { return nil }
                next = paused ? nil : RimTrace.frame(after: current,
                                                     lowFrequency: mode == .lowFrequency)
                return current
            }
        }
    }

    /// The next frame after `date`, or nil once the rim is lit and nothing moves again.
    private static func frame(after date: Date, lowFrequency: Bool) -> Date? {
        let settledAt = epoch.addingTimeInterval(runtime + fill)
        guard date < settledAt else { return nil }
        // Land exactly on the settled frame rather than a hair short of it.
        return min(date.addingTimeInterval(lowFrequency ? 1 : 1.0 / 40.0), settledAt)
    }

    // CLAUDE  Date 09/17/2026
    // The capsule, drawn by hand so its path STARTS at top-center and runs clockwise —
    // SwiftUI's Capsule doesn't document where its path begins, and the turns and the fill
    // need to know exactly where on the rim the dash offset is measured from.
    private struct RimPath: Shape {
        func path(in rect: CGRect) -> Path {
            let r = min(rect.width, rect.height) / 2
            var p = Path()
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.midY), radius: r,
                     startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            p.addArc(center: CGPoint(x: rect.minX + r, y: rect.midY), radius: r,
                     startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            p.closeSubpath()
            return p
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
