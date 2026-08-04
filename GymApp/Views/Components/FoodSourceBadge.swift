import SwiftUI

// Claude  Date 08/04/2026
// The provenance badge(s) for a food, in one place so every surface agrees on the
// stacking rules. Provenance has two independent axes:
//
//   • ORIGIN (FoodTrust, from FoodItem.source) — where the record came from.
//   • VERIFICATION (FoodVerification) — whether a human vouched for its numbers.
//
// Stacking rules, encoded here rather than at each call site:
//   • .verified (Agil's curated vault) renders the brand-pink Agil-mark badge alone.
//     Vault membership already means verified; a second "Verified" capsule would be
//     redundant.
//   • .generic and .restaurant always stack their verification state — these are the
//     two sources where "has someone checked this?" is the user's real question.
//   • .openFoodFacts stacks ONLY when verified. Unverified is the OFF default, so
//     tagging every OFF row with a gray "Unverified" would be noise on most results.
//   • .userSubmitted never stacks — it's the user's own food; they know its origin.
//
// Two sizes: `.row` is an icon-only pill for dense list rows, `.detail` is the full
// icon+text badge for the detail-page header.
struct FoodSourceBadge: View {
    let source: FoodTrust
    var verification: FoodVerification? = nil
    var style: Style = .detail

    enum Style { case row, detail }

    var body: some View {
        HStack(spacing: 4) {
            sourceBadge
            if let stacked = stackedVerification {
                verificationBadge(stacked)
            }
        }
    }

    // Claude  Date 08/04/2026
    // Which verification badge (if any) rides alongside the source badge — the
    // stacking rules above, in one place. nil = source badge stands alone.
    private var stackedVerification: FoodVerification? {
        guard let verification else { return nil }
        switch source {
        case .verified, .userSubmitted:
            return nil
        case .generic, .restaurant:
            return verification
        case .openFoodFacts:
            return verification == .verified ? .verified : nil
        }
    }

    // Claude  Date 08/04/2026 (moved from FoodDetailView.sourceBadge)
    // The curated-vault badge swaps the SF Symbol for the Agil kettlebell mark,
    // template-tinted to brand pink; every other source keeps a tinted-symbol capsule.
    @ViewBuilder private var sourceBadge: some View {
        if source == .verified {
            capsule(tint: FoodSourcePalette.verified) {
                Image("AgilMark")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: glyphSize, height: glyphSize)
            }
        } else {
            capsule(tint: source.tint) {
                Image(systemName: source.systemImage)
                    .imageScale(.small)
            }
        }
    }

    @ViewBuilder private func verificationBadge(_ v: FoodVerification) -> some View {
        capsule(tint: v.tint, label: v.label) {
            Image(systemName: v.systemImage).imageScale(.small)
        }
    }

    // Claude  Date 08/04/2026
    // The shared capsule shell (visual recipe matches ShopView's RarityBadge: bold
    // caption, tinted fill, hairline stroke so it still reads on a tinted surface).
    // In `.row` style the text is dropped and only the glyph shows — a full-text
    // badge would crowd out the food name at list width.
    @ViewBuilder private func capsule<Glyph: View>(
        tint: Color,
        label: String? = nil,
        @ViewBuilder glyph: () -> Glyph
    ) -> some View {
        let text = label ?? source.label
        HStack(spacing: 4) {
            glyph()
            if style == .detail {
                Text(text).tracking(0.3)
            }
        }
        .font(style == .detail ? .caption.weight(.semibold) : .caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, style == .detail ? 10 : 6)
        .padding(.vertical, style == .detail ? 5 : 3)
        .background(tint.opacity(0.15), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 0.5))
        // Icon-only badges lose their meaning to anyone not reading color, so the
        // label always survives for VoiceOver even when it isn't drawn.
        .accessibilityLabel(text)
    }

    private var glyphSize: CGFloat { style == .detail ? 14 : 11 }
}

// Claude  Date 08/04/2026
// Presentation for the verification axis. Kept next to the badge (not on the model)
// so the enum itself stays a plain wire type.
extension FoodVerification {
    var label: String {
        switch self {
        case .verified:   return "Verified"
        case .pending:    return "In review"
        case .unverified: return "Unverified"
        }
    }

    var systemImage: String {
        switch self {
        case .verified:   return "checkmark.seal.fill"
        case .pending:    return "clock.fill"
        case .unverified: return "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .verified:   return FoodSourcePalette.verifiedStack
        case .pending:    return FoodSourcePalette.pendingStack
        case .unverified: return FoodSourcePalette.unverifiedStack
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 14) {
        ForEach([FoodTrust.verified, .openFoodFacts, .generic, .restaurant, .userSubmitted],
                id: \.self) { trust in
            HStack(spacing: 10) {
                FoodSourceBadge(source: trust, verification: .verified, style: .detail)
                FoodSourceBadge(source: trust, verification: .pending, style: .detail)
                FoodSourceBadge(source: trust, verification: .unverified, style: .row)
            }
        }
    }
    .padding()
}
