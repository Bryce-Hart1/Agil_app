import SwiftUI

// CLAUDE  Date 09/17/2026
// The app's lit outline, in one place (Bryce, 9/17/26). It is ModeNotch's rim light in its
// settled state — a 1.5pt accent ring over a blurred 3pt glow — reused by the keyboard bar,
// the workout mini bar and the tab bar's top edge so all four read as the same family.
//
// RimTrace keeps its own strokes: it dashes the ring to draw a moving streak, which needs a
// StrokeStyle these can't give it. Change a number here and change it there too.
enum AccentRimStyle {
    static let lineWidth: CGFloat = 1.5
    static let lineOpacity: Double = 0.9
    static let glowWidth: CGFloat = 3
    static let glowOpacity: Double = 0.35
    static let glowBlur: CGFloat = 2
}

// CLAUDE  Date 09/17/2026
// The outline around a shape (Capsule for the pill-shaped chrome). Never hit-testable — it
// is decoration over something that is usually a button.
struct AccentRim<S: Shape>: View {
    let shape: S
    let accent: Color

    var body: some View {
        ZStack {
            shape
                .stroke(accent.opacity(AccentRimStyle.glowOpacity),
                        lineWidth: AccentRimStyle.glowWidth)
                .blur(radius: AccentRimStyle.glowBlur)
            shape
                .stroke(accent.opacity(AccentRimStyle.lineOpacity),
                        lineWidth: AccentRimStyle.lineWidth)
        }
        .allowsHitTesting(false)
    }
}

// CLAUDE  Date 09/17/2026
// The same outline as a single straight line, for an edge rather than a closed shape (the
// tab bar's top). Its glow spreads both ways, so it lifts off the page above it the way the
// ring lifts off the pill.
struct AccentRimLine: View {
    let accent: Color

    var body: some View {
        ZStack {
            Rectangle()
                .fill(accent.opacity(AccentRimStyle.glowOpacity))
                .frame(height: AccentRimStyle.glowWidth)
                .blur(radius: AccentRimStyle.glowBlur)
            Rectangle()
                .fill(accent.opacity(AccentRimStyle.lineOpacity))
                .frame(height: AccentRimStyle.lineWidth)
        }
        .frame(height: AccentRimStyle.lineWidth)
        .allowsHitTesting(false)
    }
}

// CLAUDE  Date 09/17/2026
// The rim's glow applied to a glyph rather than an outline: one blurred copy of the view
// sitting behind the sharp one — the same construction AccentRim uses, so a selected tab
// icon lights up in the same family. The copy inherits the view's own tint, so it follows
// the theme accent without being told the colour.
//
// Cheap on purpose: nothing animates, the copy is drawn only while `active`, and the bar it
// lives in redraws only when the selection, theme or a badge changes.
struct AccentGlyphGlow: ViewModifier {
    var active: Bool = true
    var radius: CGFloat = 3
    var opacity: Double = 0.4

    func body(content: Content) -> some View {
        content.background {
            if active {
                content
                    .blur(radius: radius)
                    .opacity(opacity)
                    .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func accentGlyphGlow(active: Bool = true, radius: CGFloat = 3,
                         opacity: Double = 0.4) -> some View {
        modifier(AccentGlyphGlow(active: active, radius: radius, opacity: opacity))
    }
}
