import SwiftUI

// CLAUDE  Date 09/19/2026
// The weekly check-in. Shows what the scale did, what the plan was able to believe, and the
// change it proposes — then waits. Nothing about the user's targets moves without a tap, and
// declining still records the week so the model keeps learning from it.
struct BodyCheckInView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var bodyStore: BodyStore
    @AppStorage(BodyUnits.storageKey) private var unitsRaw = BodyUnits.defaultValue.rawValue

    let onClose: () -> Void

    @State private var status: BodyCheckInStatus?
    @State private var adherence: BodyCheckInInput.Adherence?

    private var units: BodyUnits { BodyUnits(rawValue: unitsRaw) ?? .defaultValue }
    private var accent: Color { theme.current.accent }
    private var surface: Color { theme.current.surface }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    switch status {
                    case .ready(let proposal):      readyContent(proposal)
                    case .needsAdherence:           adherenceContent
                    case .needsWeighIns(let r, let p): weighInsContent(recent: r, prior: p)
                    case .notDue(let next):         notDueContent(next)
                    case .none:                     ProgressView().padding(.top, 60)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(theme.current.background.ignoresSafeArea())
            .navigationTitle("Weekly check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close", action: onClose)
                }
            }
        }
        .tint(accent)
        .onAppear(perform: evaluate)
    }

    // MARK: - Ready

    @ViewBuilder
    private func readyContent(_ proposal: BodyCheckInProposal) -> some View {
        weekCard(proposal)
        evidenceCard(proposal)
        proposalCard(proposal)

        ForEach(proposal.flags, id: \.self) { flag in
            flagCard(flag)
        }

        if proposal.goalReached {
            noticeCard(icon: "flag.checkered",
                       text: "You've reached what this phase was aiming at. Worth switching phase from the plan screen.")
        }

        VStack(spacing: 8) {
            PrimaryCTAButton(title: proposal.isOnTrack ? "Keep going" : "Use new targets",
                             systemImage: "checkmark", accent: accent) {
                bodyStore.record(proposal, accepted: !proposal.isOnTrack, store: store)
                Haptics.tap()
                onClose()
            }
            if !proposal.isOnTrack {
                SecondaryTextButton("Keep my current targets") {
                    bodyStore.record(proposal, accepted: false, store: store)
                    onClose()
                }
            }
        }
        .padding(.top, 4)

        Text("An estimate from two weeks of data, not a prescription. Your targets only change when you tap.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .supportingTextFont()
            .multilineTextAlignment(.center)
    }

    // CLAUDE  Date 09/19/2026
    // The week itself: both averages and the rate. Rate is shown as a percentage of bodyweight
    // as well as in weight, because a pound a week means something very different at 130 lb
    // than at 230 — which is exactly why the plan's paces are percentages.
    private func weekCard(_ proposal: BodyCheckInProposal) -> some View {
        VStack(spacing: 12) {
            HStack {
                averageColumn("Last week", proposal.priorAverageLb)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                averageColumn("This week", proposal.recentAverageLb)
            }
            Divider()
            HStack {
                Text("Change")
                    .font(.subheadline)
                Spacer()
                Text(rateText(proposal))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(accent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func averageColumn(_ title: String, _ weightLb: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(units.weightText(fromPounds: weightLb))")
                .font(.system(.title3, design: .rounded).bold())
                .monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func rateText(_ proposal: BodyCheckInProposal) -> String {
        let sign = proposal.rateLbPerWeek > 0 ? "+" : "−"
        let amount = units.weightText(fromPounds: abs(proposal.rateLbPerWeek))
        return String(format: "%@%@ %@ · %@%.2f%% a week", sign, amount,
                      units.weightAbbreviation, sign, abs(proposal.ratePctPerWeek))
    }

    // CLAUDE  Date 09/19/2026 last changed: 09/20/2026 by: CLAUDE
    // What the user themselves put in this week, so an adjustment doesn't arrive out of
    // nowhere. (09/20) The resting/training/everyday split that used to sit under it is gone
    // (Bryce, 9/20/26) — that's how the estimate is built, which isn't the user's concern.
    private func evidenceCard(_ proposal: BodyCheckInProposal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What this is based on")
                .font(.subheadline.weight(.semibold))
            row("Weigh-ins", "\(proposal.recentCount) this week")
            if let reported = proposal.reportedIntake {
                row("Food logged", "\(Int(reported.rounded())) kcal a day")
            }
            if let believed = proposal.believedIntake, proposal.channel == .diary,
               let reported = proposal.reportedIntake, believed - reported > 40 {
                Text("Your results suggest a little more than that went in — normal, and the plan accounts for it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .supportingTextFont()
            }
            // CLAUDE  Date 09/20/2026
            // Said only when something the user logged was NOT used — otherwise this is three
            // rows telling them everything is fine, which is what made the hub feel bloated.
            // It reports, it never accuses: under-logging is ordinary, and a user who reads
            // "your log is wrong" stops logging, which costs the plan far more.
            ForEach(ignoredInputs(proposal), id: \.self) { note in
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .supportingTextFont()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }

    /// What the plan had to set aside this week, in plain words. Empty when it used everything.
    private func ignoredInputs(_ proposal: BodyCheckInProposal) -> [String] {
        var notes: [String] = []
        if proposal.channel != .diary {
            notes.append(DataTrust.diaryCopy(trust: proposal.updatedModel.diaryTrust,
                                             ratio: proposal.updatedModel.intakeRatio,
                                             usable: false))
        }
        if proposal.updatedModel.activityTrust < BodySafety.trustFloor {
            notes.append(DataTrust.activityCopy(trust: proposal.updatedModel.activityTrust,
                                                hasSessions: true))
        }
        return notes
    }

    private func proposalCard(_ proposal: BodyCheckInProposal) -> some View {
        VStack(spacing: 12) {
            if proposal.isOnTrack {
                Label("On track — no change needed", systemImage: "checkmark.seal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
            } else {
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text("\(Int(proposal.currentCalories))")
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("now").font(.caption2).foregroundStyle(.secondary)
                    }
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    VStack(spacing: 2) {
                        Text("\(Int(proposal.proposedCalories))")
                            .font(.system(.title, design: .rounded).bold())
                            .monospacedDigit()
                            .foregroundStyle(accent)
                        Text("kcal").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 0) {
                    macro("Protein", proposal.targets.protein, MacroPalette.protein)
                    macro("Carbs", proposal.targets.carbs, MacroPalette.carbs)
                    macro("Fat", proposal.targets.fat, MacroPalette.fat)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func macro(_ title: String, _ grams: Double, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(grams))g")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Asks

    // CLAUDE  Date 09/19/2026
    // Asked only when the food log can't carry the estimate. "Not really" is a first-class
    // answer that holds the targets steady — guessing from a week the user has already told
    // us wasn't representative is how a plan ends up chasing noise.
    private var adherenceContent: some View {
        VStack(spacing: 16) {
            StepHeader(icon: "questionmark.circle",
                       title: "How closely did you follow your targets?",
                       subtitle: "Your food log didn't have enough to go on this time, so this is the next best thing.",
                       accent: accent)

            ForEach(BodyCheckInInput.Adherence.allCases) { option in
                ChoiceCard(isSelected: adherence == option,
                           systemImage: adherenceIcon(option),
                           title: option.label,
                           description: adherenceDetail(option),
                           accent: accent, surface: surface) {
                    adherence = option
                    evaluate()
                }
            }
        }
    }

    private func adherenceIcon(_ option: BodyCheckInInput.Adherence) -> String {
        switch option {
        case .onTarget:  return "target"
        case .mostly:    return "circle.lefthalf.filled"
        case .notReally: return "xmark.circle"
        }
    }

    private func adherenceDetail(_ option: BodyCheckInInput.Adherence) -> String {
        switch option {
        case .onTarget:  return "Most days landed close to the number."
        case .mostly:    return "Roughly there, with a few days off."
        case .notReally: return "This week wasn't representative. Nothing will change."
        }
    }

    private func weighInsContent(recent: Int, prior: Int) -> some View {
        VStack(spacing: 16) {
            StepHeader(icon: "scalemass",
                       title: "Not enough weigh-ins yet",
                       subtitle: "The check-in compares two weekly averages, and needs at least \(BodySafety.minimumWeighInsPerWindow) days in each.",
                       accent: accent)
            VStack(spacing: 8) {
                row("This week", "\(recent) logged")
                row("Last week", "\(prior) logged")
            }
            .padding()
            .background(surface, in: RoundedRectangle(cornerRadius: 16))
            noticeCard(icon: "info.circle",
                       text: "Daily weigh-ins are best — one morning is mostly water, and the average cancels that out.")
            PrimaryCTAButton(title: "Log today's weight", systemImage: "plus", accent: accent) {
                onClose()
                bodyStore.requestedFlow = nil
            }
        }
    }

    private func notDueContent(_ next: String?) -> some View {
        VStack(spacing: 16) {
            StepHeader(icon: "calendar",
                       title: "Not due yet",
                       subtitle: nextText(next),
                       accent: accent)
            SecondaryTextButton("Close", action: onClose)
        }
    }

    private func nextText(_ next: String?) -> String {
        guard let next, let date = DayKey.date(from: next) else {
            return "Check-ins run once a week."
        }
        return "The next one is ready \(date.formatted(.dateTime.weekday(.wide).month().day()))."
    }

    // MARK: - Pieces

    private func flagCard(_ flag: SafetyFlag) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(flag.title, systemImage: "exclamationmark.triangle")
                .font(.subheadline.weight(.semibold))
            Text(flag.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .supportingTextFont()
                .fixedSize(horizontal: false, vertical: true)
            if flag.needsSupportLink {
                NavigationLink {
                    HealthSafetyView()
                } label: {
                    Text("Health & safety").font(.caption.weight(.semibold))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private func noticeCard(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(accent)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .supportingTextFont()
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding()
        .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // CLAUDE  Date 09/19/2026
    // Evaluated once on appear and again when the adherence question is answered — never in
    // the view body, which would walk the food log and workout history on every redraw.
    private func evaluate() {
        status = bodyStore.evaluateCheckIn(store: store, adherence: adherence)
    }
}
