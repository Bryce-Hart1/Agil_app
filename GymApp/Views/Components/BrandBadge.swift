import SwiftUI

// Claude  Date 09/01/2026
// Neutral counterpart to EquipmentBadge: same capsule geometry, no color. Used for
// the facts beside a lift's name that aren't the equipment type (brand, unilateral),
// so EquipmentBadge keeps the ONLY tinted chip and color alone still tells a machine
// from a cable. Renders nothing for empty text.
struct NeutralChip: View {
    let text: String?
    var accessibilityText: String? = nil
    // Claude  Date 09/03/2026
    // Sizes borrowed wholesale from EquipmentBadge.Style so a neutral chip standing
    // beside a tinted one is the same capsule, not a smaller sibling. `.row` (the
    // default) keeps the original dense-list size; `.detail` matches the header chip.
    var style: EquipmentBadge.Style = .row

    var body: some View {
        if let text, !text.isEmpty {
            Text(text)
                .tracking(0.3)
                .lineLimit(1)
                .font(style == .detail ? .caption.weight(.semibold) : .caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, style == .detail ? 10 : 6)
                .padding(.vertical, style == .detail ? 5 : 3)
                .background(Color.secondary.opacity(0.12), in: Capsule())
                .overlay(Capsule().stroke(Color.secondary.opacity(0.30), lineWidth: 0.5))
                .accessibilityLabel(accessibilityText ?? text)
        }
    }
}

// Claude  Date 09/01/2026
// The manufacturer chip beside a lift's name ("Hammer Strength"). Driven by
// Exercise.brandLabel, which is nil on a generic lift — so the chip simply doesn't
// appear rather than drawing an empty capsule.
struct BrandBadge: View {
    let brand: String?
    var style: EquipmentBadge.Style = .row

    var body: some View {
        NeutralChip(text: brand, accessibilityText: brand.map { "Brand \($0)" }, style: style)
    }
}
