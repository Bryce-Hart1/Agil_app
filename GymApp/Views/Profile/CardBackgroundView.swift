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

    var body: some View {
        switch background {
        case .color(let hex):
            let color = Color(hex: hex)
            LinearGradient(colors: [color, color.opacity(0.78)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

        case .image(let asset):
            Image(asset)
                .resizable()
                .scaledToFill()
                .overlay(
                    LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.45)],
                                   startPoint: .top, endPoint: .bottom)
                )
        }
    }
}
