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

// CLAUDE  Date 09/05/2026 last changed: 09/24/2026 by: CLAUDE
// The AGIL mark + wordmark that tops every card face, with an optional trailing slot.
// In edit mode that slot carries the palette chip: the background has no single element
// to tap, and a whole-card tap would fight the inner elements' gestures.
// (09/24) `mode` shows the logo, the wordmark or both; `onEdit` makes the mark tappable.
struct CardBrandHeader<Trailing: View>: View {
    var logoAsset: String = ThemeIcon.classicLogoAsset
    var mode: CardHeaderMode = .logoAndName
    var onEdit: (() -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.cardInk) private var ink

    var body: some View {
        HStack(spacing: 8) {
            if let onEdit {
                Button(action: onEdit) { mark }
                    .buttonStyle(.plain)
                    .overlay(alignment: .topTrailing) { CardEditChip().offset(x: 22, y: -10) }
                    .accessibilityLabel("Change card header")
            } else {
                mark
            }
            Spacer()
            trailing()
        }
    }

    private var mark: some View {
        HStack(spacing: 8) {
            if mode.showsLogo {
                AgilLogoMark(assetName: logoAsset, size: 28, cornerRadius: 7)
            }
            if mode.showsName {
                Text("AGIL")
                    .font(.caption.bold()).tracking(3)
                    .foregroundStyle((ink ?? .white).color.opacity(0.85))
            }
        }
        // Keeps the row the logo's height even when only the wordmark shows.
        .frame(minHeight: 28)
    }
}

extension CardBrandHeader where Trailing == EmptyView {
    init(logoAsset: String = ThemeIcon.classicLogoAsset, mode: CardHeaderMode = .logoAndName) {
        self.init(logoAsset: logoAsset, mode: mode) { EmptyView() }
    }
}

// CLAUDE  Date 09/05/2026 last changed: 09/24/2026 by: CLAUDE
// The palette chip both faces use to open their own background picker.
// (09/24) Drawn in the card's ink so it stays visible on a light card with black text.
struct CardPaletteChip: View {
    let action: () -> Void

    @Environment(\.cardInk) private var ink

    var body: some View {
        let color = (ink ?? .white).color
        Button(action: action) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .padding(12)
                .background(color.opacity(0.22), in: Circle())
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

// CLAUDE  Date 09/24/2026
// The card's chosen text colour, set once at the root of each face so every label, chip
// and faint fill inside it reads the same value. nil outside a card, which lets shared
// pieces (RankRing, RankRingInitials) keep their normal colours everywhere else.
private struct CardInkKey: EnvironmentKey {
    static let defaultValue: CardInk? = nil
}

extension EnvironmentValues {
    var cardInk: CardInk? {
        get { self[CardInkKey.self] }
        set { self[CardInkKey.self] = newValue }
    }
}
