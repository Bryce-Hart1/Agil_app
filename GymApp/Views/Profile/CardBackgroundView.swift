import SwiftUI

// Claude  Date 06/13/2026
// Renders a CardBackground. This is the single place that knows how each kind of
// background is drawn, so the profile card stays agnostic and adding a new look
// (e.g. an animated card) means adding one case here — nowhere else changes.
//
// Image cards carry a built-in dark scrim so the card's white text stays legible
// over arbitrary art; color cards render as the existing soft diagonal gradient.
struct CardBackgroundView: View {
    let background: CardBackground
    // Claude  Date 09/02/2026
    // Corner radius of the shape the caller clips this view to. Only .outlined
    // needs it (its border has to follow the same curve); nil falls back to a
    // radius scaled off the frame, which is close enough for small previews.
    var cornerRadius: CGFloat? = nil

    var body: some View {
        switch background {
        case .color(let hex):
            let color = Color(hex: hex)
            LinearGradient(colors: [color, color.opacity(0.78)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

        // Claude  Date 06/16/2026
        // Two-color diagonal gradient (Epic cards with no PNG art).
        case .gradient(let from, let to):
            LinearGradient(colors: [Color(hex: from), Color(hex: to)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

        case .image(let asset):
            Image(asset)
                .resizable()
                .scaledToFill()
                .overlay(
                    LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.45)],
                                   startPoint: .top, endPoint: .bottom)
                )

        // Claude  Date 06/16/2026
        // Live, code-drawn animation (carries its own scrim).
        case .animated(let kind):
            AnimatedCardBackground(kind: kind)

        // Claude  Date 09/02/2026
        // Flat fill with a hairline border traced just inside the card's edge
        // (strokeBorder, so the line can't be clipped away). No scrim needed —
        // the fill is already dark enough for the card's white text.
        case .outlined(let fill, let stroke):
            Color(hex: fill).overlay {
                GeometryReader { geo in
                    let radius = cornerRadius ?? min(geo.size.width, geo.size.height) * 0.12
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color(hex: stroke), lineWidth: 1.5)
                }
            }
        }
    }
}
