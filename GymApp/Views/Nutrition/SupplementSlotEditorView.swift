import SwiftUI

// Claude  Date 08/29/2026
// One slot's schedule: what it's called, whether it reminds, at what time, and on which
// days. Those weekdays do double duty and the footer says so out loud — they decide when
// the reminder fires AND which days the slot's supplements appear on the journal card, so
// a "Weekdays" slot simply isn't part of Saturday's stack.
//
// Edits are written straight through to the store rather than staged behind a Save button:
// every control here is a single, obviously-reversible choice, and the store's didSet is
// what reschedules the notifications — batching them behind Save would just mean the
// reminders lag the UI.
struct SupplementSlotEditorView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let slotId: UUID

    // Local mirror of the name so typing doesn't fight the store's trimming/clipping.
    @State private var name = ""
    @State private var showNotificationAsk = false

    private var slot: SupplementSlot? { store.supplementSlots.first { $0.id == slotId } }

    var body: some View {
        List {
            Section("Name") {
                TextField("Name", text: $name)
                    .onChange(of: name) { newValue in
                        let clipped = String(newValue.prefix(SupplementSlot.maxNameLength))
                        if clipped != newValue { name = clipped }
                        commit { $0.name = clipped }
                    }
            }

            Section {
                Toggle("Remind me", isOn: remindersOn)
                if slot?.remindersOn == true {
                    DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Reminder")
            } footer: {
                Text(slot?.remindersOn == true
                     ? "A notification at this time on the days below."
                     : "No notification for this group. You can still check it off in the Journal.")
            }

            Section {
                WeekdayPicker(selection: weekdays)
                    .padding(.vertical, 4)
            } header: {
                Text("Days")
            } footer: {
                // The one non-obvious rule in the whole feature, so it gets said plainly
                // rather than left to be discovered on a Saturday.
                Text("These days do two jobs: they're when the reminder fires, and they're the days this group shows up in your Journal.")
            }

            if store.supplementSlots.count > 1 {
                Section {
                    Button("Delete \(slot?.name ?? "group")", role: .destructive) {
                        store.deleteSupplementSlot(id: slotId)
                        dismiss()
                    }
                } footer: {
                    Text("The supplements in this group move to \(fallbackName) — nothing is deleted.")
                }
            }
        }
        .navigationTitle(slot?.name ?? "Time of Day")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .notificationAsk(isPresented: $showNotificationAsk)
        // Claude  Date 08/29/2026
        // The resync that actually makes a new reminder fire. The store's didSet already
        // resynced when the toggle flipped, but at that moment we weren't authorized yet,
        // so resync removed everything and scheduled nothing. Without this pass on the way
        // back out of the permission screen, a slot set up before the very first prompt
        // would stay silent forever — the likeliest way this feature quietly fails.
        .onChange(of: showNotificationAsk) { shown in
            if !shown { store.resyncSupplementReminders() }
        }
        .onAppear { name = slot?.name ?? "" }
    }

    private var fallbackName: String {
        store.supplementSlots.first { $0.id != slotId }?.name ?? "another group"
    }

    // MARK: - Write-through bindings

    private var remindersOn: Binding<Bool> {
        Binding(get: { slot?.remindersOn ?? false },
                set: { newValue in
                    commit { $0.remindersOn = newValue }
                    if newValue { askIfNeeded() }
                })
    }

    private var weekdays: Binding<Set<Int>> {
        Binding(get: { slot?.weekdays ?? SupplementSlot.allWeekdays },
                set: { newValue in commit { $0.weekdays = newValue } })
    }

    // The DatePicker wants a Date; the slot stores hour+minute, because a wall-clock time
    // is all a repeating trigger needs and all that survives the user changing timezone.
    private var time: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.year = 2000
                components.month = 1
                components.day = 1
                components.hour = slot?.hour ?? 8
                components.minute = slot?.minute ?? 0
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                commit {
                    $0.hour = parts.hour ?? 8
                    $0.minute = parts.minute ?? 0
                }
            })
    }

    private func commit(_ change: (inout SupplementSlot) -> Void) {
        guard var updated = slot else { return }
        change(&updated)
        store.updateSupplementSlot(updated)
    }

    // Claude  Date 08/29/2026
    // Pre-permission screen, presented on the two statuses where the reminder the user
    // just asked for cannot actually fire. .denied is included on purpose: iOS won't
    // re-prompt, so the screen's "Open Settings" route is the only honest answer — better
    // than a toggle that looks on and silently does nothing.
    private func askIfNeeded() {
        Task {
            switch await WorkoutNotifications.authorizationStatus() {
            case .notDetermined, .denied: showNotificationAsk = true
            default: break
            }
        }
    }
}

#Preview {
    let store = AppStore()
    return NavigationStack {
        SupplementSlotEditorView(slotId: store.supplementSlots[0].id)
    }
    .environmentObject(store)
    .environmentObject(ThemeManager())
}
