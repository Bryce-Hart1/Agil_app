import SwiftUI

// Claude  Date 07/22/2026
// Re-proportioned for a 4-up row instead of a 2×2 grid: centered content, smaller
// type, no 84pt floor. At ~83pt per tile on a 6.1" screen the value is the only
// thing that needs to hold its size, so it keeps a bold subheadline while the
// caption drops to .caption2 — both stay one line and scale down rather than wrap.
/// A compact stat tile: icon, value, caption. Used on the Progress dashboard.
struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let surface: Color
    let accent: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(accent)
            Text(value)
                .font(.subheadline).fontWeight(.bold)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(title)
                .font(.caption2).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(surface, in: RoundedRectangle(cornerRadius: 10))
    }
}
