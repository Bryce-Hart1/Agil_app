import SwiftUI

// Claude  Date 08/18/2026
// The equipment "nameplate" for a lift — the small tinted capsule beside its name
// saying how it's loaded (Machine, Cable, Free Weight…). Two jobs:
//
//   • tells you at a glance what you're looking at in a long library section, and
//   • marks the lifts that can carry a brand (machines/cables/smith machines), since
//     that's exactly where two entries can share a name.
//
// Renders NOTHING when `type` is nil. That's the normal state for a custom lift the
// user never classified, and for anything the equipment backfill couldn't match by
// name — an "Unknown" chip on those would be noise, not information.
//
// Two sizes, mirroring FoodSourceBadge: `.row` is an icon-only pill for dense list
// rows, `.detail` carries the text for headers with room for it.
struct EquipmentBadge: View {
    let type: EquipmentType?
    var style: Style = .row

    enum Style { case row, detail }

    var body: some View {
        if let type {
            HStack(spacing: 4) {
                Image(systemName: type.systemImage).imageScale(.small)
                if style == .detail {
                    Text(type.title).tracking(0.3)
                }
            }
            .font(style == .detail ? .caption.weight(.semibold) : .caption2.weight(.semibold))
            .foregroundStyle(type.tint)
            .padding(.horizontal, style == .detail ? 10 : 6)
            .padding(.vertical, style == .detail ? 5 : 3)
            .background(type.tint.opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(type.tint.opacity(0.35), lineWidth: 0.5))
            // The icon-only style loses its meaning to anyone not reading color, so
            // the label always survives for VoiceOver even when it isn't drawn.
            .accessibilityLabel(type.title)
        }
    }
}

// Claude  Date 08/18/2026
// Presentation for the equipment axis. Kept next to the badge rather than on the model
// so EquipmentType itself stays a plain Foundation-only wire type (same split as
// FoodVerification's tint/systemImage living in FoodSourceBadge).
extension EquipmentType {
    var systemImage: String {
        switch self {
        case .machine:      return "gearshape.fill"
        case .freeWeight:   return "dumbbell.fill"
        case .cable:        return "arrow.up.and.down"
        case .smithMachine: return "rectangle.split.3x1"
        case .bodyweight:   return "figure.strengthtraining.functional"
        }
    }

    var tint: Color {
        switch self {
        case .machine:      return EquipmentPalette.machine
        case .freeWeight:   return EquipmentPalette.freeWeight
        case .cable:        return EquipmentPalette.cable
        case .smithMachine: return EquipmentPalette.smithMachine
        case .bodyweight:   return EquipmentPalette.bodyweight
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 14) {
        ForEach(EquipmentType.allCases, id: \.self) { type in
            HStack(spacing: 10) {
                EquipmentBadge(type: type, style: .detail)
                EquipmentBadge(type: type, style: .row)
            }
        }
    }
    .padding()
}
