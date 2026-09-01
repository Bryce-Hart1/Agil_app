import SwiftUI

// Claude  Date 08/29/2026
// The supplement checklist, sitting in the Journal between the setup card and Summary.
// A View whose body is a Section, mounted directly in the diary's List — the same shape as
// NutritionSetupCard, and for the same reason (a List child has to produce a Section).
//
// It's placed ABOVE Summary deliberately: it's the one thing in the journal that's a
// prompt rather than a record, and it's only worth prompting about before the day is over.
// Once the stack is cleared it collapses to a single confirming line instead of vanishing,
// so the top of the screen doesn't jump the moment you finish and there's still somewhere
// to un-check a mis-tap.
//
// Five states, in the order they're checked:
//   tracker off ................ nothing
//   no supplements yet ......... a dismissible invite (today only)
//   a past day ................. one greyed line explaining check-offs are same-day
//   nothing due today .......... nothing
//   otherwise .................. the checklist, or the collapsed "all taken" line
//
// NOTE: no .onAppear/.task anywhere in here. NutritionSetupCard documents why — lifecycle
// modifiers on a Section aren't reliably run, and they re-fire when you pop back from a
// pushed screen, which this card does every time the user visits the manage screen.
struct SupplementCard: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    /// The day the Journal is showing. Check-offs only ever apply to today.
    let selectedDate: Date

    @AppStorage(SupplementTracking.storageKey) private var trackSupplements = SupplementTracking.defaultValue
    @AppStorage(SupplementTracking.inviteDismissedKey) private var inviteDismissed = false
    // Claude  Date 08/29/2026
    // Whether the collapsed "all taken" row is expanded back into the checklist. The only
    // route to un-checking something once the day is complete, so the collapse never
    // becomes a one-way door. Not persisted — a fresh visit should read as "done".
    @State private var showTakenDetail = false

    private var accent: Color { theme.current.accent }
    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    private var due: [Supplement] { store.dueSupplements(on: selectedDate) }
    private var taken: Set<UUID> { store.takenSupplementIDs(on: selectedDate) }
    private var remaining: Int { due.filter { !taken.contains($0.id) }.count }

    var body: some View {
        if trackSupplements {
            if store.supplements.isEmpty {
                if isToday && !inviteDismissed { inviteSection }
            } else if !isToday {
                pastDaySection
            } else if !due.isEmpty {
                checklistSection
            }
        }
    }

    // MARK: - Invite

    // Claude  Date 08/29/2026
    // The whole discovery path for the feature. Without it the tracker is a Settings row
    // nobody has a reason to look for. Dismissible and gone for good — an invite that
    // can't be turned off is just an ad.
    private var inviteSection: some View {
        Section {
            NavigationLink {
                SupplementsView()
            } label: {
                HStack(spacing: 12) {
                    iconChip("pills.fill", tint: accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Track your supplements")
                            .font(.subheadline.weight(.semibold))
                        Text("Check off your vitamins each day, with a reminder if you want one.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .supportingTextFont()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
            }
        } header: {
            HStack {
                Text("Supplements")
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.35)) { inviteDismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Dismiss supplements invite")
            }
        }
    }

    // MARK: - Past days

    // Claude  Date 08/29/2026
    // Back-filling isn't allowed (AppStore.setSupplement refuses any date but today), which
    // is what keeps the badge ledger honest. Saying so in one quiet line beats the section
    // silently disappearing out of the most prominent slot on the screen.
    private var pastDaySection: some View {
        Section("Supplements") {
            Label("Checked off on the day", systemImage: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        Section {
            if remaining == 0 {
                allTakenRow
                if showTakenDetail {
                    groupedRows
                    Button(action: untakeAll) {
                        Label("Uncheck all", systemImage: "arrow.uturn.backward")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            } else {
                groupedRows
                if remaining > 1 {
                    Button(action: takeAll) {
                        Label("Take all", systemImage: "checkmark.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(accent)
                }
            }
        } header: {
            HStack {
                Text("Supplements")
                Spacer()
                if remaining > 0 {
                    Text("\(due.count - remaining) of \(due.count)")
                        .monospacedDigit()
                }
                NavigationLink {
                    SupplementsView()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Manage supplements")
            }
        }
    }

    // Claude  Date 08/29/2026
    // The collapsed done state, and the way back out of it. A plain Button rather than a
    // NavigationLink for two reasons: a NavigationLink in a List row draws the List's OWN
    // disclosure chevron on top of anything the label already contains (that's where the
    // duplicate arrow came from), and more importantly, collapsing must not be a one-way
    // door — tapping here re-opens the checklist so a mis-tap can be undone with exactly
    // the gesture that made it. The manage screen is still one tap away in the header.
    // Shared by both states, so the expanded "all taken" view keeps the slot labels the
    // checklist has rather than quietly becoming a different list.
    @ViewBuilder
    private var groupedRows: some View {
        ForEach(groups, id: \.slotId) { group in
            // The slot name only earns a row once the stack is actually split; a
            // single-group user never sees the grouping concept at all.
            if groups.count > 1 {
                Text(group.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            ForEach(group.items) { supplement in
                row(supplement)
            }
        }
    }

    private var allTakenRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { showTakenDetail.toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(accent)
                Text("All taken today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showTakenDetail ? 180 : 0))
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(showTakenDetail ? "Hides the checklist" : "Shows the checklist so you can uncheck one")
    }

    private func row(_ supplement: Supplement) -> some View {
        let isTaken = taken.contains(supplement.id)
        return Button {
            toggle(supplement, to: !isTaken)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isTaken
                                     ? AnyShapeStyle(accent)
                                     : AnyShapeStyle(Color.secondary.opacity(0.5)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(supplement.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isTaken ? .secondary : .primary)
                        .strikethrough(isTaken, color: .secondary)
                    if let dose = supplement.dose {
                        Text(dose)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .supportingTextFont()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    // Claude  Date 08/29/2026
    // One `Date` captured at the moment of the tap, handed to the store, and used there for
    // both the log entry and the cleared-day key. This is the midnight guard: selectedDate
    // was fixed when the view was built and the app may have sat open past midnight, so the
    // store re-checks that this instant is really today and refuses otherwise.
    private func toggle(_ supplement: Supplement, to taken: Bool) {
        withAnimation(.easeInOut(duration: 0.25)) {
            store.setSupplement(supplement.id, taken: taken, at: Date())
        }
    }

    private func takeAll() {
        withAnimation(.easeInOut(duration: 0.3)) {
            store.takeAllSupplements(at: Date())
        }
    }

    private func untakeAll() {
        withAnimation(.easeInOut(duration: 0.3)) {
            store.untakeAllSupplements(at: Date())
            showTakenDetail = false
        }
    }

    // MARK: - Grouping

    private struct SlotGroup {
        let slotId: UUID
        let name: String
        let items: [Supplement]
    }

    private var groups: [SlotGroup] {
        let bySlot = Dictionary(grouping: due, by: \.slotId)
        return store.supplementSlots.compactMap { slot in
            guard let items = bySlot[slot.id], !items.isEmpty else { return nil }
            return SlotGroup(slotId: slot.id, name: slot.name,
                             items: items.sorted { $0.sortIndex < $1.sortIndex })
        }
    }
}

#Preview {
    NavigationStack {
        List {
            SupplementCard(selectedDate: Date())
        }
    }
    .environmentObject(AppStore())
    .environmentObject(ThemeManager())
}
