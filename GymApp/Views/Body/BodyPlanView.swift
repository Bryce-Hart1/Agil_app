import SwiftUI

// CLAUDE  Date 09/19/2026
// The plan hub: the trend chart, the daily targets, the check-in history, and the weigh-in
// log. Pushed from the Journal card.
//
// CLAUDE  Date 09/20/2026 — the "what the plan is using" rows moved to the check-in sheet
// (Bryce, 9/20/26). They only matter in the moment an adjustment is made, and they only
// matter when the answer is "not your food log" — so they show there, and only then.
// Read-mostly — the only writes are logging a weigh-in and the explicit plan actions at the
// bottom.
struct BodyPlanView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var bodyStore: BodyStore
    @AppStorage(BodyUnits.storageKey) private var unitsRaw = BodyUnits.defaultValue.rawValue
    // CLAUDE  Date 09/20/2026
    // Water moved here with the rest of the daily targets when the separate Goals screen was
    // retired. Still stored canonically in ml; these only change how it's typed and shown.
    @AppStorage(WaterUnit.storageKey) private var waterUnitRaw = WaterUnit.milliliters.rawValue
    @AppStorage(WaterTracking.storageKey) private var trackWater = WaterTracking.defaultValue

    @State private var isLoggingWeight = false
    @State private var logDate = Date()
    @State private var isChangingPhase = false
    @State private var showEndPlanConfirm = false
    @State private var showStartFreshConfirm = false

    private var units: BodyUnits { BodyUnits(rawValue: unitsRaw) ?? .defaultValue }
    private var accent: Color { theme.current.accent }
    private var plan: BodyPlan? { bodyStore.plan }

    var body: some View {
        List {
            if bodyStore.state == .unreadable {
                unreadableSection
            } else {
                chartSection
                dailyTargetsSection
                if let plan { planSections(plan) }
                else { noPlanSection }
                weighInsSection
                aboutSection
            }
        }
        .navigationTitle("Body & plan")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .sheet(isPresented: $isLoggingWeight) { LogWeightSheet(date: logDate) }
        .fullScreenCover(isPresented: $isChangingPhase) {
            PlanSetupFlow(onClose: { isChangingPhase = false }, mode: .changePhase)
        }
        .onAppear { bodyStore.retryIfUnavailable() }
    }

    // MARK: - Chart

    private var chartSection: some View {
        Section {
            WeightTrendChart(weighIns: bodyStore.data.weighIns,
                             goalWeightLb: plan?.targetWeightLb,
                             units: units, accent: accent)
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            Button {
                logDate = Date()
                isLoggingWeight = true
            } label: {
                Label("Log weight", systemImage: "scalemass")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(accent)
        } header: {
            HStack {
                Text("Trend")
                Spacer()
                if let trend = bodyStore.trendWeightLb {
                    Text("\(units.weightText(fromPounds: trend)) \(units.weightAbbreviation)")
                        .monospacedDigit()
                }
            }
        } footer: {
            Text("The line is your 7-day average — the number the plan reads. The dots are individual mornings.")
        }
    }

    // MARK: - Plan

    @ViewBuilder
    private func planSections(_ plan: BodyPlan) -> some View {
        planSummarySection(plan)
        checkInSection(plan)
        actionsSection(plan)
    }

    // CLAUDE  Date 09/20/2026
    // The daily targets, editable in place. This is what the separate Goals screen used to be:
    // one destination for the numbers rather than two that could disagree about who owns them.
    // Shown with or without a plan, so someone who never builds one can still set their goals.
    private var dailyTargetsSection: some View {
        Section {
            goalField("Calories (kcal)", value: calorieGoalBinding)
            goalField("Protein (g)", value: $store.nutritionGoals.protein)
            goalField("Carbs (g)", value: $store.nutritionGoals.carbs)
            goalField("Fat (g)", value: $store.nutritionGoals.fat)
            if trackWater {
                goalField("Water (\(waterUnit.abbreviation))", value: waterGoalBinding)
            }
        } header: {
            Text("Daily targets")
        } footer: {
            Text(plan == nil
                 ? "What the Journal's Summary fills toward. A plan can work these out for you and keep them current."
                 : "Set by your plan. Edit any of them here — the next check-in adjusts from whatever they are then, it never overwrites you silently.")
        }
    }

    private func goalField(_ label: String, value: Binding<Double>) -> some View {
        LabeledContent(label) {
            TextField(label, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    // CLAUDE  Date 09/19/2026 last changed: 09/20/2026 by: CLAUDE
    // Calories, wrapped so committing an edit also ticks the Journal's setup checklist (and,
    // through it, the First Plan badge). Marking on any write — rather than on a change of
    // value — is the forgiving choice. markNutritionSetup is guarded, so per-keystroke calls
    // are free. (09/20) Moved here from the retired NutritionGoalsView.
    private var calorieGoalBinding: Binding<Double> {
        Binding(
            get: { store.nutritionGoals.calories },
            set: {
                store.nutritionGoals.calories = $0
                store.markNutritionSetup(\.calorieGoalSet)
            })
    }

    private var waterUnit: WaterUnit { WaterUnit(rawValue: waterUnitRaw) ?? .milliliters }

    /// The water goal seen through the display unit: reads convert ml → unit (rounded to a
    /// tenth for a sane field value), writes convert back to canonical ml.
    private var waterGoalBinding: Binding<Double> {
        Binding(
            get: { (waterUnit.fromMilliliters(store.nutritionGoals.water) * 10).rounded() / 10 },
            set: {
                store.nutritionGoals.water = waterUnit.toMilliliters($0)
                store.markNutritionSetup(\.waterGoalSet)
            })
    }

    private func planSummarySection(_ plan: BodyPlan) -> some View {
        Section {
            LabeledContent("Phase", value: plan.phase.label(for: plan.track))
            LabeledContent("Pace", value: plan.pace.title(units: units))
            LabeledContent("Macros", value: plan.effectiveMacroStyle.choice.title)
            if let goal = plan.targetWeightLb {
                LabeledContent("Goal", value: "\(units.weightText(fromPounds: goal)) \(units.weightAbbreviation)")
            }
            if let fat = plan.targetBodyFatPct {
                LabeledContent("Goal body fat", value: String(format: "%g%%", fat))
            }
            // CLAUDE  Date 09/20/2026
            // Body composition stays — it's the user's own measurement. The calorie
            // derivation that used to sit below it doesn't (Bryce, 9/20/26).
            if plan.track == .bodybuilding, let lean = leanMassLb {
                LabeledContent("Lean mass",
                               value: "\(units.weightText(fromPounds: lean)) \(units.weightAbbreviation)")
            }
            if plan.track == .bodybuilding, let fat = bodyStore.latestBodyFat,
               let date = DayKey.date(from: fat.dayKey), let pct = fat.bodyFatPct {
                LabeledContent("Body fat",
                               value: String(format: "%.1f%% · %@", pct,
                                             date.formatted(.dateTime.month().day())))
            }
        } header: {
            Text("Week \(plan.weeksInPhase() + 1)")
        }
    }

    // MARK: - Check-in

    @ViewBuilder
    private func checkInSection(_ plan: BodyPlan) -> some View {
        Section {
            if bodyStore.isCheckInDue {
                Button {
                    bodyStore.requestedFlow = .checkIn
                } label: {
                    Label("Run this week's check-in", systemImage: "checkmark.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(accent)
            } else if let next = BodyCheckInEngine.nextDueDayKey(plan: plan),
                      let date = DayKey.date(from: next) {
                LabeledContent("Next check-in",
                               value: date.formatted(.dateTime.weekday(.wide).month().day()))
            }

            ForEach(bodyStore.data.checkIns.suffix(6).reversed(), id: \.id) { record in
                checkInRow(record)
            }
        } header: {
            Text("Check-ins")
        } footer: {
            if plan.lastCheckInDayKey == nil {
                Text("The first check-in waits two weeks. A new phase's first days are water weight, and adjusting on that would send the plan the wrong way.")
            }
        }
    }

    private func checkInRow(_ record: BodyCheckInRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(DayKey.date(from: record.dayKey)?.formatted(.dateTime.month().day()) ?? record.dayKey)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(record.accepted
                     ? "\(Int(record.previousCalories)) → \(Int(record.proposedCalories)) kcal"
                     : "Kept \(Int(record.previousCalories)) kcal")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(String(format: "%@%.2f%% a week", record.ratePctPerWeek > 0 ? "+" : "",
                        record.ratePctPerWeek))
                .font(.caption)
                .foregroundStyle(.secondary)
                .supportingTextFont()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func actionsSection(_ plan: BodyPlan) -> some View {
        Section {
            Button {
                isChangingPhase = true
            } label: {
                Label("Change phase or pace", systemImage: "arrow.triangle.2.circlepath")
            }
            .tint(accent)

            Picker("Check-in day", selection: checkInWeekdayBinding) {
                ForEach(1...7, id: \.self) { weekday in
                    Text(Calendar.current.weekdaySymbols[weekday - 1]).tag(weekday)
                }
            }
            .retintOnThemeChange(theme.current, salt: "hubCheckInDay")

            Toggle("Check-in reminder", isOn: remindersBinding)
                .tint(accent)

            Button(role: .destructive) {
                showEndPlanConfirm = true
            } label: {
                Label("End plan", systemImage: "stop.circle")
            }
        } header: {
            Text("Plan")
        } footer: {
            Text("Ending a plan leaves your calorie and macro goals exactly where they are — they're yours now.")
        }
        .confirmationDialog("End this plan?", isPresented: $showEndPlanConfirm, titleVisibility: .visible) {
            Button("End plan", role: .destructive) { bodyStore.endPlan() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your weigh-ins and goals stay. Only the plan and its check-ins stop.")
        }
    }

    private var checkInWeekdayBinding: Binding<Int> {
        Binding(
            get: { bodyStore.plan?.checkInWeekday ?? 2 },
            set: { bodyStore.updateCheckInSchedule(weekday: $0,
                                                   remindersOn: bodyStore.plan?.remindersOn ?? false) })
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { bodyStore.plan?.remindersOn ?? false },
            set: { bodyStore.updateCheckInSchedule(weekday: bodyStore.plan?.checkInWeekday ?? 2,
                                                   remindersOn: $0) })
    }

    // MARK: - No plan yet

    private var noPlanSection: some View {
        Section {
            Button {
                bodyStore.requestedFlow = .setup
            } label: {
                Label("Build a calorie plan", systemImage: "target")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(accent)
        } footer: {
            Text("You can log your weight without a plan. A plan adds calorie and macro targets, and a weekly check-in that adjusts them.")
        }
    }

    // MARK: - Weigh-ins

    private var weighInsSection: some View {
        Section {
            ForEach(recentWeighIns) { weighIn in
                HStack {
                    Text(DayKey.date(from: weighIn.dayKey)?
                        .formatted(.dateTime.weekday(.abbreviated).month().day()) ?? weighIn.dayKey)
                        .font(.subheadline)
                    Spacer()
                    if let fat = weighIn.bodyFatPct {
                        Text(String(format: "%.1f%%", fat))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text("\(units.weightText(fromPounds: weighIn.weightLb)) \(units.weightAbbreviation)")
                        .font(.subheadline.monospacedDigit())
                }
            }
            .onDelete(perform: deleteWeighIns)

            Button {
                logDate = Date()
                isLoggingWeight = true
            } label: {
                Label("Add a weigh-in", systemImage: "plus")
                    .font(.subheadline)
            }
            .tint(accent)
        } header: {
            Text("Recent weigh-ins")
        }
    }

    private var recentWeighIns: [WeighIn] {
        bodyStore.data.weighIns.sorted { $0.dayKey > $1.dayKey }.prefix(14).map { $0 }
    }

    private func deleteWeighIns(at offsets: IndexSet) {
        for index in offsets { bodyStore.deleteWeighIn(recentWeighIns[index].id) }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            NavigationLink {
                HealthSafetyView()
            } label: {
                Label("Health & safety", systemImage: "heart.text.square")
            }
        } footer: {
            Text("Estimates, not medical advice. Your weight and body details stay on this iPhone, encrypted.")
        }
    }

    // MARK: - Unreadable

    // CLAUDE  Date 09/19/2026
    // The recovery path. The old file is kept, not deleted, and starting fresh is a deliberate
    // two-tap choice — this state is reached by restoring from an unencrypted backup, and a
    // user in that position should not be one tap from erasing anything.
    private var unreadableSection: some View {
        Section {
            Text("Your body data is on this iPhone, but the key that opens it isn't.")
                .font(.subheadline)
            Text("That happens when a phone is set up from a backup that wasn't encrypted — the key is deliberately left out of those. If you have an encrypted backup, restoring from it brings the key back.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .supportingTextFont()
            Button(role: .destructive) {
                showStartFreshConfirm = true
            } label: {
                Label("Start fresh", systemImage: "arrow.counterclockwise")
            }
        } header: {
            Text("Couldn't be opened")
        }
        .confirmationDialog("Start fresh?", isPresented: $showStartFreshConfirm,
                            titleVisibility: .visible) {
            Button("Start fresh", role: .destructive) { bodyStore.startFresh() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Begins a new, empty body history. The unreadable file is kept in case the key comes back.")
        }
    }

    // MARK: - Derived

    private var leanMassLb: Double? {
        guard let weight = bodyStore.trendWeightLb,
              let fat = bodyStore.latestBodyFat?.bodyFatPct else { return nil }
        return weight * (1 - fat / 100)
    }
}

#Preview {
    NavigationStack { BodyPlanView() }
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
        .environmentObject(BodyStore())
}
