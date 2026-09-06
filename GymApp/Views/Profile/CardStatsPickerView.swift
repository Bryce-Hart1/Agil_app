import SwiftUI

// CLAUDE  Date 09/05/2026
// Chooses what goes on the card's back: one highlighted "hero" stat plus up to
// CardStat.maxTiles smaller tiles. Structure follows FeaturedBadgesView (a picked
// section that reorders and deletes, over a pool), presentation follows the Progress
// widget gallery — but each row also shows the user's REAL current value, which the
// gallery couldn't afford and which makes the list explain itself.
struct CardStatsPickerView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    // Built once on appear: two ProfileStats passes plus a ledger scan is too much to
    // repeat per row, and nothing here changes the numbers.
    @State private var inputs: CardStatInputs?

    private var hero: CardStat? { store.cardBackHeroStat }
    private var tiles: [CardStat] { store.cardBackTileStats }
    private var isFull: Bool { tiles.count >= CardStat.maxTiles }

    private var available: [CardStat] {
        CardStat.allCases.filter { $0 != hero && !tiles.contains($0) }
    }

    var body: some View {
        List {
            Section {
                if let hero {
                    row(hero, role: .hero)
                } else {
                    Text("Pick a stat to feature in large type at the top of the back.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Highlighted")
            }

            Section {
                if tiles.isEmpty {
                    Text("No stat tiles yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tiles) { row($0, role: .tile) }
                        .onMove(perform: store.moveBackStat)
                        .onDelete(perform: deleteTiles)
                }
            } header: {
                Text("On the back (\(tiles.count)/\(CardStat.maxTiles))")
            } footer: {
                if isFull {
                    Text("Your card's back is full. Remove one to add another.")
                }
            }

            Section {
                ForEach(available) { row($0, role: .available) }
            } header: {
                Text("Available stats")
            } footer: {
                // CLAUDE  Date 09/05/2026 — the honest note about free text. These tiles
                // embed a name the user typed, so they can't be shared until the backend
                // screens them; see docs/card_contract.md.
                Text("Stats built from your own exercise names stay on this device for now.")
            }
        }
        .navigationTitle("Back of Card")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .onAppear { if inputs == nil { inputs = store.cardBackStatInputs } }
        .toolbar {
            if tiles.count > 1 {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private enum RowRole { case hero, tile, available }

    // MARK: - Rows

    private func row(_ stat: CardStat, role: RowRole) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: stat.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.current.accent)
                .frame(width: 28, height: 28)
                .background(theme.current.accent.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(stat.title)
                    .font(.subheadline.weight(.semibold))
                Text(stat.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let resolved = resolvedValue(stat) {
                    Text(resolved)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.current.accent)
                }
                if stat.carriesUserText {
                    Label("Stays on your device", systemImage: "iphone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 6)

            trailingControls(stat, role: role)
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func trailingControls(_ stat: CardStat, role: RowRole) -> some View {
        HStack(spacing: 12) {
            // The star is the hero toggle and is available from every row, so promoting
            // a stat never means removing it first.
            Button {
                store.setCardBackHeroStat(stat)
            } label: {
                Image(systemName: role == .hero ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(role == .hero ? theme.current.accent : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(role == .hero ? "Remove highlight from \(stat.title)"
                                              : "Highlight \(stat.title)")

            if role != .hero {
                Button {
                    store.toggleBackStat(stat)
                } label: {
                    Image(systemName: role == .tile ? "minus.circle.fill" : "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(role == .tile ? Color.red : theme.current.accent)
                }
                .buttonStyle(.plain)
                .disabled(role == .available && isFull)
                .opacity(role == .available && isFull ? 0.35 : 1)
                .accessibilityLabel(role == .tile ? "Remove \(stat.title)"
                                                  : "Add \(stat.title)")
            }
        }
    }

    // The live number, or an honest "No data yet" rather than a dash that reads as zero.
    private func resolvedValue(_ stat: CardStat) -> String? {
        guard let inputs else { return nil }
        let value = CardStatResolver.value(for: stat, inputs: inputs)
        guard value.hasData else { return "No data yet" }
        return [value.value, value.caption].compactMap { $0 }.joined(separator: " · ")
    }

    private func deleteTiles(at offsets: IndexSet) {
        for stat in offsets.map({ tiles[$0] }) { store.toggleBackStat(stat) }
    }
}
