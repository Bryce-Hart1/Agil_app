import SwiftUI

// Claude  Date 09/01/2026
// Neutral counterpart to EquipmentBadge: same capsule geometry, no color. Used for
// the facts beside a lift's name that aren't the equipment type (brand, unilateral),
// so EquipmentBadge keeps the ONLY tinted chip and color alone still tells a machine
// from a cable. Renders nothing for empty text.
struct NeutralChip: View {
    let text: String?
    var accessibilityText: String? = nil

    var body: some View {
        if let text, !text.isEmpty {
            Text(text)
                .tracking(0.3)
                .lineLimit(1)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
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

    var body: some View {
        NeutralChip(text: brand, accessibilityText: brand.map { "Brand \($0)" })
    }
}
