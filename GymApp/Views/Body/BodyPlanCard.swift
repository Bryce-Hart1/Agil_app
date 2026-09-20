import SwiftUI

// CLAUDE  Date 09/19/2026
// The body feature's home in the Journal, sitting under the supplement checklist and above
// Summary — the plan is what the Summary's targets came from, so it reads in that order.
// Four states: an invitation, an active plan, a check-in that's ready, and the rare case
// where the vault can't be read. Draws nothing once the invitation is dismissed.
struct BodyPlanCard: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var bodyStore: BodyStore
    @AppStorage(BodyUnits.storageKey) private var unitsRaw = BodyUnits.defaultValue.rawValue
    @AppStorage(BodyPlanCard.showWeightKey) private var showWeight = true

    /// Settings → Body & Plan can hide the number here without hiding the card.
    static let showWeightKey = "showWeightOnJournal"

    @State private var isLoggingWeight = false

    private var units: BodyUnits { BodyUnits(rawValue: unitsRaw) ?? .defaultValue }
    private var accent: Color { theme.current.accent }

    var body: some View {
        Group {
            switch bodyStore.state {
            case .unreadable:
                Section { unreadableRow }
            case .loading, .temporarilyUnavailable:
                EmptyView()
            case .ready:
                if bodyStore.plan != nil {
                    Section { planRows } header: { header }
                } else if !bodyStore.data.promoDismissed {
                    Section { promoRow } header: { promoHeader }
                }
            }
        }
        .sheet(isPresented: $isLoggingWeight) { LogWeightSheet() }
        .onAppear { bodyStore.retryIfUnavailable() }
    }

    // MARK: - Active plan

    private var header: some View {
        HStack {
            Text("Body & plan")
            Spacer()
            if let plan = bodyStore.plan {
                Text("Week \(plan.weeksInPhase() + 1)")
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var planRows: some View {
        if let plan = bodyStore.plan {
            NavigationLink {
                BodyPlanView()
            } label: {
                HStack(spacing: 14) {
                    iconTile(phaseIcon(plan.phase))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.phase.label(for: plan.track))
                            .font(.subheadline.weight(.semibold))
                        Text(trendLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .supportingTextFont()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
            }

            if bodyStore.isCheckInDue {
                checkInRow
            }

            Button {
                isLoggingWeight = true
            } label: {
                Label(loggedToday ? "Update today's weight" : "Log today's weight",
                      systemImage: "scalemass")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(accent)
        }
    }

    // CLAUDE  Date 09/19/2026
    // The check-in prompt. It asks rather than announces: the sheet does the maths when it's
    // opened, so nothing about the user's targets changes until they've seen why.
    private var checkInRow: some View {
        Button {
            bodyStore.requestedFlow = .checkIn
        } label: {
            HStack(spacing: 14) {
                iconTile("checkmark.circle")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly check-in is ready")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("See how the week went and adjust your targets.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .supportingTextFont()
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // CLAUDE  Date 09/19/2026
    // The trend line, which is the 7-day average rather than the last weigh-in — a single
    // morning is mostly water. Respects the "show weight" setting: some people want the plan
    // without the number in front of them every time they open the Journal.
    private var trendLine: String {
        guard let plan = bodyStore.plan else { return "" }
        guard showWeight, let trend = bodyStore.trendWeightLb else {
            return bodyStore.isCheckInDue ? "Check-in ready" : nextCheckInText(plan)
        }
        let weight = "\(units.weightText(fromPounds: trend)) \(units.weightAbbreviation)"
        return "\(weight) · \(nextCheckInText(plan))"
    }

    private func nextCheckInText(_ plan: BodyPlan) -> String {
        guard let next = BodyCheckInEngine.nextDueDayKey(plan: plan),
              let date = DayKey.date(from: next) else { return "Weekly check-ins" }
        if date <= Date() { return "Check-in ready" }
        return "Next check-in \(date.formatted(.dateTime.weekday(.abbreviated)))"
    }

    private var loggedToday: Bool {
        bodyStore.data.weighIns.contains { $0.dayKey == DayKey.key() }
    }

    // MARK: - Invitation

    private var promoHeader: some View {
        HStack {
            Text("Body & plan")
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { bodyStore.dismissPromo() }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss")
        }
    }

    private var promoRow: some View {
        Button {
            bodyStore.requestedFlow = .setup
        } label: {
            HStack(spacing: 14) {
                iconTile("target")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Build a calorie plan")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Set your targets from your weight and goal, then let weekly check-ins tune them. Stays on this iPhone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .supportingTextFont()
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Unreadable

    // CLAUDE  Date 09/19/2026
    // The vault exists but its key doesn't — which happens when a phone is restored from an
    // UNENCRYPTED backup, since that kind of backup deliberately can't carry the key. Says so
    // plainly, and sends the user to the hub where starting fresh is an explicit choice.
    private var unreadableRow: some View {
        NavigationLink {
            BodyPlanView()
        } label: {
            HStack(spacing: 14) {
                iconTile("lock.slash")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Body data couldn't be opened")
                        .font(.subheadline.weight(.semibold))
                    Text("Its key isn't on this iPhone. Only an encrypted backup can carry it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .supportingTextFont()
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
        }
    }

    private func iconTile(_ systemName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(accent.opacity(0.15))
                .frame(width: 36, height: 36)
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
        }
    }

    private func phaseIcon(_ phase: PlanPhase) -> String {
        switch phase {
        case .cut:      return "arrow.down.right.circle"
        case .maintain: return "equal.circle"
        case .leanBulk: return "arrow.up.right.circle"
        }
    }
}
