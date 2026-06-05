import SwiftUI

/// A compact stat tile: icon, big value, caption. Used on the Progress dashboard
/// and the Profile tab.
struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let surface: Color
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(accent)
            Text(value)
                .font(.title2).fontWeight(.bold)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(12)
        .background(surface, in: RoundedRectangle(cornerRadius: 12))
    }
}
