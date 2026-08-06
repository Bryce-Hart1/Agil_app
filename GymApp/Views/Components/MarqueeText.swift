import SwiftUI

// Claude  Date 08/04/2026 last changed: 08/04/2026 by: Claude
// A single line of text that scrolls slowly, and only when it has to.
//
// Written for the workout editor's nav-bar title, which shows the source preset's
// name — user-typed, so it can be any length, while a `.principal` toolbar item
// gets only the width the back button and the ellipsis menu leave behind.
// Truncating hides the end of a name the user chose; scrolling shows all of it
// without stealing attention.
//
// The scroll is a single offset animation rather than a TimelineView redraw loop:
// this sits in a navigation bar that's on screen for an entire workout, so
// per-frame work would be paid for the whole session. Two copies of the text
// separated by `gap` make the wrap seamless — the offset animates exactly one
// copy-plus-gap and repeats, so the second copy is always sitting where the first
// one started.
//
// (08/04, same day) The available width is a PARAMETER, not read from an outer
// GeometryReader. A GeometryReader has no intrinsic size, and a navigation bar
// sizes its principal item to intrinsic content — so the first cut of this
// collapsed to roughly zero width and rendered a single sliver of one glyph.
// Anything hosting this has to say how much room it's giving it.
struct MarqueeText: View {
    let text: String
    var font: Font = .body
    /// How much room the host has. Text wider than this scrolls; narrower is static.
    var maxWidth: CGFloat
    /// Points per second. Deliberately slow — this is chrome, not the content.
    var speed: CGFloat = 25
    /// Space between the two copies, so the text doesn't wrap into itself.
    var gap: CGFloat = 40
    /// Beat before the first scroll, so a glance at the start of the name works.
    var startDelay: Double = 1.5

    @State private var textWidth: CGFloat = 0
    @State private var animating = false

    // Unlabelled first argument so call sites read like Text(_:).
    init(_ text: String, font: Font = .body, maxWidth: CGFloat, speed: CGFloat = 25,
         gap: CGFloat = 40, startDelay: Double = 1.5) {
        self.text = text
        self.font = font
        self.maxWidth = maxWidth
        self.speed = speed
        self.gap = gap
        self.startDelay = startDelay
    }

    // textWidth is 0 until the measurer reports, so this reads false on the first
    // pass and the static branch renders — clamped by maxWidth, so the worst case
    // is one frame of truncation before the scroller takes over.
    private var overflows: Bool { textWidth > maxWidth }

    var body: some View {
        Group {
            if overflows {
                HStack(spacing: gap) {
                    label
                    label
                }
                .offset(x: animating ? -(textWidth + gap) : 0)
                .animation(
                    .linear(duration: Double((textWidth + gap) / speed))
                        .delay(startDelay)
                        .repeatForever(autoreverses: false),
                    value: animating
                )
                .onAppear { animating = true }
                .frame(width: maxWidth, alignment: .leading)
                .clipped()
                // Fade only the edges the text runs past. A static title gets no
                // mask at all — a fade on a fully visible name reads as a rendering
                // bug rather than an effect.
                .mask(edgeFade)
            } else {
                label.frame(maxWidth: maxWidth)
            }
        }
        // Measure off to the side: a hidden overlay keeps its natural width without
        // contributing to layout, so the visible branch above is free to be clamped.
        .overlay(measurer)
        // Restart cleanly when the title changes (a renamed preset): a new identity
        // remeasures and replays from zero instead of resuming a stale offset.
        .id(text)
        .accessibilityLabel(Text(text))
    }

    private var label: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize()
    }

    private var measurer: some View {
        label
            .hidden()
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { textWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { textWidth = $0 }
                }
            )
    }

    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.06),
                .init(color: .black, location: 0.94),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }
}

#Preview {
    VStack(spacing: 24) {
        MarqueeText("Push Day", font: .system(size: 17, weight: .semibold), maxWidth: 200)
        MarqueeText("Upper Body Hypertrophy — Heavy Bench Focus",
                    font: .system(size: 17, weight: .semibold), maxWidth: 200)
    }
    .padding()
}
