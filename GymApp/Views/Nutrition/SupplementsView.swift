import SwiftUI

// Claude  Date 08/29/2026
// The supplement tracker's manage screen: build the stack, split it across times of day,
// and jump into a slot's reminder schedule. Pushed from the journal card and from
// Settings → Supplements, so it has no NavigationStack of its own.
//
// Laid out one Section per slot rather than one flat list, because the slot is what carries
// the schedule — seeing "Post-workout · 6:30 PM · Mon, Wed, Fri" directly above the three
// things it covers is the whole mental model of the feature in one glance.
struct SupplementsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    // Which slot the add-sheet is adding into (nil = closed).
    @State private var addingToSlot: SupplementSlot?
    // The supplement being renamed (nil = closed).
    @State private var editing: Supplement?
    @State private var showingNewSlot = false
    // CLAUDE  Date 09/24/2026 — the optional follow-up reminder (see SupplementFollowUp).
    @AppStorage(SupplementFollowUp.enabledKey) private var followUpOn = false
    @AppStorage(SupplementFollowUp.timeKey) private var followUpMinutes = SupplementFollowUp.defaultMinutes
    @State private var showNotificationAsk = false

    var body: some View {
        List {
            ForEach(store.supplementSlots) { slot in
                slotSection(slot)
            }
            newSlotSection
            followUpSection
        }
        .navigationTitle("Supplements")
        .themed(theme.current)
        // CLAUDE  Date 09/24/2026
        // Follow-up changes reschedule right away. The resync after the permission screen
        // closes is what makes a follow-up turned on before the first prompt actually fire.
        .onChange(of: followUpOn) { on in
            store.resyncSupplementReminders()
            if on { askIfNeeded() }
        }
        .onChange(of: followUpMinutes) { _ in store.resyncSupplementReminders() }
        .notificationAsk(isPresented: $showNotificationAsk)
        .onChange(of: showNotificationAsk) { shown in
            if !shown { store.resyncSupplementReminders() }
        }
        .sheet(item: $addingToSlot) { slot in
            SupplementEditorSheet(slot: slot, existing: nil)
        }
        .sheet(item: $editing) { supplement in
            SupplementEditorSheet(
                slot: store.supplementSlots.first { $0.id == supplement.slotId },
                existing: supplement)
        }
        .sheet(isPresented: $showingNewSlot) { NewSlotSheet() }
    }

    private func slotSection(_ slot: SupplementSlot) -> some View {
        Section {
            ForEach(store.supplementsInSlot(slot.id)) { supplement in
                Button {
                    editing = supplement
                } label: {
                    HStack {
                        Text(supplement.name)
                            .foregroundStyle(.primary)
                        if let dose = supplement.dose {
                            Text(dose)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        store.deleteSupplement(id: supplement.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            if store.canAddSupplement {
                Button {
                    addingToSlot = slot
                } label: {
                    Label("Add supplement", systemImage: "plus")
                        .font(.subheadline)
                }
            }
        } header: {
            // The header doubles as the way into the schedule — the slot's time and days
            // are shown here, so tapping the thing you just read is the obvious gesture.
            NavigationLink {
                SupplementSlotEditorView(slotId: slot.id)
            } label: {
                HStack(spacing: 6) {
                    Text(slot.name)
                    Spacer()
                    Text(scheduleLabel(slot))
                        .font(.caption)
                        .textCase(nil)
                        .foregroundStyle(slot.remindersOn ? theme.current.accent : .secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } footer: {
            if store.supplementsInSlot(slot.id).isEmpty {
                Text("Nothing here yet. A slot with no supplements never sends a reminder.")
            } else if !store.canAddSupplement {
                Text("You've reached the limit of \(Supplement.maxCount) supplements.")
            }
        }
    }

    private var newSlotSection: some View {
        Section {
            if store.canAddSupplementSlot {
                Button {
                    showingNewSlot = true
                } label: {
                    Label("Add a time of day", systemImage: "clock.badge.checkmark")
                }
            }
        } footer: {
            Text(store.canAddSupplementSlot
                 ? "Split your stack across the day — a morning group and a bedtime group can be reminded separately."
                 : "You've reached the limit of \(SupplementSlot.maxCount) times of day.")
        }
    }

    private func scheduleLabel(_ slot: SupplementSlot) -> String {
        slot.remindersOn ? "\(slot.timeLabel) · \(slot.daysLabel)" : "No reminder"
    }

    // MARK: - Follow-up

    // CLAUDE  Date 09/24/2026
    // One switch and one time for the whole stack, not per slot: the question it answers is
    // "did I finish today?", which spans every group. Written straight through like the slot
    // editor — the onChange handlers above do the rescheduling.
    private var followUpSection: some View {
        Section {
            Toggle("Remind me again", isOn: $followUpOn)
            if followUpOn {
                DatePicker("If anything's left at", selection: followUpTime,
                           displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Follow-up")
        } footer: {
            Text(followUpOn
                 ? "One more reminder at this time if anything due today is still unchecked. Groups with their own reminder at or after this time aren't counted."
                 : "Get a second reminder later in the day if you haven't checked everything off.")
        }
    }

    // The picker wants a Date; the setting is minutes after midnight (see SupplementFollowUp).
    private var followUpTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.year = 2000
                components.month = 1
                components.day = 1
                components.hour = followUpMinutes / 60
                components.minute = followUpMinutes % 60
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                followUpMinutes = (parts.hour ?? 20) * 60 + (parts.minute ?? 0)
            })
    }

    // CLAUDE  Date 09/24/2026
    // Same pre-permission rule as SupplementSlotEditorView: ask on .notDetermined, and on
    // .denied show the screen's "Open Settings" route rather than a toggle that silently fails.
    private func askIfNeeded() {
        Task {
            switch await WorkoutNotifications.authorizationStatus() {
            case .notDetermined, .denied: showNotificationAsk = true
            default: break
            }
        }
    }
}

// Claude  Date 08/29/2026
// Add or rename one supplement. A sheet rather than a pushed screen because it's two
// fields and a Save — the same treatment ChangeNameView gets in Settings.
private struct SupplementEditorSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let slot: SupplementSlot?
    let existing: Supplement?

    @State private var name = ""
    @State private var dose = ""
    @State private var slotId: UUID?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .onChange(of: name) { newValue in
                            name = String(newValue.prefix(Supplement.maxNameLength))
                        }
                    TextField("Dose (optional)", text: $dose)
                        .onChange(of: dose) { newValue in
                            dose = String(newValue.prefix(Supplement.maxDoseLength))
                        }
                } footer: {
                    Text("Dose is just a note to yourself — \"5 g\", \"2 caps\", \"1000 IU\".")
                }

                // Only worth showing once there's more than one place to put it.
                if store.supplementSlots.count > 1 {
                    Section("Time of day") {
                        Picker("Time of day", selection: $slotId) {
                            ForEach(store.supplementSlots) { slot in
                                Text(slot.name).tag(Optional(slot.id))
                            }
                        }
                        .retintOnThemeChange(theme.current, salt: "supplementSlot")
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Supplement" : "Edit Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear {
                guard let existing else {
                    slotId = slot?.id ?? store.supplementSlots.first?.id
                    return
                }
                name = existing.name
                dose = existing.dose ?? ""
                slotId = existing.slotId
            }
        }
    }

    private func save() {
        let trimmedDose = dose.trimmingCharacters(in: .whitespaces)
        if var existing {
            existing.name = name
            existing.dose = trimmedDose.isEmpty ? nil : trimmedDose
            if let slotId { existing.slotId = slotId }
            store.updateSupplement(existing)
        } else {
            store.addSupplement(name: name,
                                dose: trimmedDose.isEmpty ? nil : trimmedDose,
                                slotId: slotId)
        }
        dismiss()
    }
}

// Claude  Date 08/29/2026
// Naming a new time of day. Just the name — the schedule is set in the slot editor
// immediately afterwards, so this stays a one-field prompt rather than a second big form.
private struct NewSlotSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .onChange(of: name) { newValue in
                            name = String(newValue.prefix(SupplementSlot.maxNameLength))
                        }
                } footer: {
                    Text("Something you'd recognise on a lock screen — \"Morning\", \"Post-workout\", \"Bedtime\".")
                }
            }
            .navigationTitle("New Time of Day")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addSupplementSlot(name: name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SupplementsView()
    }
    .environmentObject(AppStore())
    .environmentObject(ThemeManager())
}
