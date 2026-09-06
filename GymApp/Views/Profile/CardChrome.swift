import SwiftUI

// CLAUDE  Date 09/05/2026
// The profile card's shared shell, extracted so the front and the new back face are the
// same physical object rather than two views that merely resemble each other. Lifted
// verbatim from ProfileShowcaseCard.body — outline cards paint their own border, so the
// generic white hairline is suppressed for them (it read as a double edge).
struct CardFaceChrome: ViewModifier {
    let style: CardStyle
    var cornerRadius: CGFloat = 28
    var shadowRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CardBackgroundView(background: style.background,
                                           cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(.white.opacity(style.isOutlined ? 0 : 0.18), lineWidth: 1))
            .shadow(color: style.shadowColor.opacity(0.4), radius: shadowRadius, y: 6)
    }
}

extension View {
    func cardFaceChrome(style: CardStyle, cornerRadius: CGFloat = 28,
                        shadowRadius: CGFloat = 12) -> some View {
        modifier(CardFaceChrome(style: style, cornerRadius: cornerRadius,
                                shadowRadius: shadowRadius))
    }
}

// CLAUDE  Date 09/05/2026
// The AGIL mark + wordmark that tops every card face, with an optional trailing slot.
// In edit mode that slot carries the palette chip: the background has no single element
// to tap, and a whole-card tap would fight the inner elements' gestures.
struct CardBrandHeader<Trailing: View>: View {
    var logoAsset: String = ThemeIcon.classicLogoAsset
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            AgilLogoMark(assetName: logoAsset, size: 28, cornerRadius: 7)
            Text("AGIL")
                .font(.caption.bold()).tracking(3)
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            trailing()
        }
    }
}

extension CardBrandHeader where Trailing == EmptyView {
    init(logoAsset: String = ThemeIcon.classicLogoAsset) {
        self.init(logoAsset: logoAsset) { EmptyView() }
    }
}

// CLAUDE  Date 09/05/2026
// The palette chip both faces use to open their own background picker.
struct CardPaletteChip: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .padding(12)
                .background(.white.opacity(0.22), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change card style")
    }
}

// CLAUDE  Date 09/05/2026
// The small pencil bubble marking an element as tappable in edit mode. Was private on
// ProfileShowcaseCard; shared now so the back's chips match the front's exactly.
struct CardEditChip: View {
    var body: some View {
        Image(systemName: "pencil")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(5)
            .background(.black.opacity(0.35), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1))
    }
}
