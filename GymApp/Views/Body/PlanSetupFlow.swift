import SwiftUI

// CLAUDE  Date 09/19/2026
// The calorie-plan wizard: consent, then the handful of facts the estimate needs, then a
// preview the user explicitly accepts. Built from OnboardingChrome so it looks like the rest
// of Agil's full-screen asks. Nothing is written until "Use this plan" on the last step —
// which then sets the user's weigh-in, metrics, plan and NutritionGoals in one go.
struct PlanSetupFlow: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var bodyStore: BodyStore
    @AppStorage(BodyUnits.storageKey) private var unitsRaw = BodyUnits.defaultValue.rawValue

    let onClose: () -> Void
    // CLAUDE  Date 09/19/2026
    // Changing phase runs the same wizard from the goal step: the questions are identical,
    // and a cut turning into a maintenance block deserves the same preview a new plan gets.
    var mode: Mode = .newPlan

    enum Mode { case newPlan, changePhase }

    // CLAUDE  Date 09/20/2026
    // One question per page. The goal used to be a phase picker, a cramped text field and the
    // pace cards all stacked on one screen, and the field — the thing the whole plan aims at —
    // read as an afterthought. `target` is now its own page, and maintenance skips it.
    enum Step: Int, CaseIterable {
        case consent, track, about, weight, training, goal, target, pace, macros, review
    }

    @State private var step: Step = .consent
    @State private var isForward = true

    // Consent — all three must be affirmed, and they're re-asked when the wording changes.
    @State private var isAdult = false
    @State private var notPregnant = false
    @State private var understandsEstimates = false

    @State private var track: PlanTrack = .bodybuilding
    @State private var sex: BiologicalSex?
    @State private var birthYear = Calendar.current.component(.year, from: Date()) - 30
    @State private var heightCm: Double = 175
    @State private var feet = 5
    @State private var inches = 9
    @State private var weightField = ""
    @State private var bodyFatField = ""
    @State private var trainingDays = 3
    @State private var phase: PlanPhase = .cut
    @State private var pace = Pace.default(track: .bodybuilding, phase: .cut)
    // CLAUDE  Date 09/20/2026
    // The goal, held as numbers rather than text now that a slider sets it. Optional until the
    // target page has been reached, so "not chosen yet" stays distinguishable from zero.
    @State private var goalWeightLbValue: Double?
    @State private var goalBodyFat: Double?
    @State private var checkInWeekday = Calendar.current.component(.weekday, from: Date())
    @State private var remindersOn = false
    @State private var macroStyle = MacroStyle.recommended
    // CLAUDE  Date 09/20/2026
    // The last 28 days of sessions, read once. The preview recomputes on every keystroke and
    // this is the only part of it that walks the workout history.
    @State private var cachedSessions: [SessionSample] = []

    private var units: BodyUnits { BodyUnits(rawValue: unitsRaw) ?? .defaultValue }
    private var accent: Color { theme.current.accent }
    private var surface: Color { theme.current.surface }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.current.background.ignoresSafeArea()
                AuraBackground(accent: accent, step: step.rawValue)
                // CLAUDE  Date 09/20/2026
                // The horizontal padding sits INSIDE the scroll view, not around it. A
                // selected ChoiceCard grows by 2% and carries an accent glow; with the
                // padding outside, the scroll view's bounds clipped both of those and the
                // card's border came out sliced down each side.
                VStack(spacing: 18) {
                    StepDots(count: visibleSteps.count,
                             index: visibleSteps.firstIndex(of: step) ?? 0, accent: accent)
                        .padding(.top, 8)
                    content
                    controls
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)
            }
            .toolbar {
                // .navigationBarTrailing, not .topBarTrailing — the latter is iOS 17.
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close", action: onClose)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(accent)
        .onAppear(perform: prefill)
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                switch step {
                case .consent:  consentStep
                case .track:    trackStep
                case .about:    aboutStep
                case .weight:   weightStep
                case .training: trainingStep
                case .goal:     goalStep
                case .target:   targetStep
                case .pace:     paceStep
                case .macros:   macrosStep
                case .review:   reviewStep
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .transition(.asymmetric(
            insertion: .move(edge: isForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isForward ? .leading : .trailing).combined(with: .opacity)))
    }

    // CLAUDE  Date 09/19/2026
    // The gate. Three separate affirmations rather than one blanket "I agree", because each
    // one is a different question and a single checkbox would let all three go unread. The
    // full page is one tap away and stays reachable afterwards from the hub and Settings.
    private var consentStep: some View {
        VStack(spacing: 16) {
            StepHeader(icon: "heart.text.square",
                       title: "Before we plan anything",
                       subtitle: "Agil gives you a starting point and adjusts it from your own results. It isn't medical advice.",
                       accent: accent)

            consentRow($isAdult, "I'm 18 or older.")
            consentRow($notPregnant, "I'm not pregnant or breastfeeding.")
            consentRow($understandsEstimates,
                       "I understand these are estimates, not medical or nutrition advice, and I'll check with a doctor or dietitian before big changes — especially with a medical condition or any history of disordered eating.")

            NavigationLink {
                HealthSafetyView()
            } label: {
                Label("Read the full health & safety page", systemImage: "arrow.up.right.square")
                    .font(.subheadline)
            }
            .padding(.top, 4)
        }
    }

    private func consentRow(_ isOn: Binding<Bool>, _ text: String) -> some View {
        Button {
            tapHaptic()
            isOn.wrappedValue.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn.wrappedValue ? accent : Color.secondary.opacity(0.5))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding()
            .background(surface, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var trackStep: some View {
        VStack(spacing: 16) {
            StepHeader(icon: "figure.strengthtraining.traditional",
                       title: "What are you training for?",
                       subtitle: "This changes how much detail you get, not how hard the maths works.",
                       accent: accent)
            ForEach(PlanTrack.allCases) { option in
                ChoiceCard(isSelected: track == option,
                           systemImage: option == .bodybuilding ? "trophy" : "figure.walk",
                           title: option.label, description: option.detail,
                           accent: accent, surface: surface) {
                    track = option
                    pace = Pace.default(track: option, phase: phase)
                }
            }
        }
    }

    private var aboutStep: some View {
        VStack(spacing: 16) {
            StepHeader(icon: "person.text.rectangle",
                       title: "A few facts about you",
                       subtitle: "Used for the metabolism estimate, and kept on this iPhone.",
                       accent: accent)

            ForEach(BiologicalSex.allCases) { option in
                ChoiceCard(isSelected: sex == option,
                           systemImage: option == .undisclosed ? "questionmark.circle" : "person",
                           title: option.label,
                           description: sexDetail(option),
                           accent: accent, surface: surface) { sex = option }
            }

            unitsPicker
            birthYearCard
            heightCard

            if !isOldEnough {
                noticeCard(icon: "exclamationmark.triangle",
                           text: "Calorie plans in Agil are for adults 18 and over. You can still log your weight and see your trend. For eating advice at your age, a doctor, dietitian or coach is the right call.")
            }
        }
    }

    private func sexDetail(_ option: BiologicalSex) -> String {
        switch option {
        case .male, .female:
            return "Used only for the metabolism estimate. It doesn't change your profile or badges."
        case .undisclosed:
            return "That's fine. Your starting numbers will be less precise and the check-ins will correct them. Adding a body-fat estimate helps most — that formula doesn't use sex at all."
        }
    }

    private var weightStep: some View {
        VStack(spacing: 16) {
            StepHeader(icon: "scalemass",
                       title: "Where are you now?",
                       subtitle: "Weigh yourself in the morning, after the bathroom, before eating.",
                       accent: accent)

            fieldCard(title: "Weight (\(units.weightAbbreviation))", text: $weightField)

            fieldCard(title: "Body fat % (optional)", text: $bodyFatField)

            noticeCard(icon: track == .bodybuilding ? "sparkles" : "info.circle",
                       text: track == .bodybuilding
                       ? "A body-fat estimate unlocks lean-mass protein targets and a more accurate resting burn. A smart scale, calipers or a considered guess are all fine — it tracks direction, not truth."
                       : "Body fat is optional. Skip it and Agil uses your height and weight instead.")
        }
    }

    private var trainingStep: some View {
        VStack(spacing: 16) {
            StepHeader(icon: "dumbbell",
                       title: "How often do you train?",
                       subtitle: "Only a starting point — Agil counts the sessions you log from here on.",
                       accent: accent)

            VStack(spacing: 10) {
                Text("\(trainingDays) \(trainingDays == 1 ? "day" : "days") a week")
                    .font(.system(.title2, design: .rounded).bold())
                    .monospacedDigit()
                Stepper("Training days", value: $trainingDays, in: 0...7)
                    .labelsHidden()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(surface, in: RoundedRectangle(cornerRadius: 16))

            noticeCard(icon: "chart.line.uptrend.xyaxis",
                       text: "There's no question here about your job or daily activity. Agil learns that from what your weight actually does — it's more accurate than anyone's guess about themselves.")
        }
    }

    private var goalStep: some View {
        VStack(spacing: 16) {
            StepHeader(icon: "target", title: "What's the goal?",
                       subtitle: nil, accent: accent)

            ForEach(PlanPhase.allCases) { option in
                ChoiceCard(isSelected: phase == option,
                           systemImage: phaseIcon(option),
                           title: option.label(for: track),
                           description: option.detail(for: track),
                           accent: accent, surface: surface) {
                    phase = option
                    pace = Pace.default(track: track, phase: option)
                    resetTargetToDefault()
                }
            }
        }
    }

    // MARK: - Target

    // CLAUDE  Date 09/20/2026
    // The goal, on a page of its own: a big readout, a slider in the user's own unit, and ±
    // buttons for the last fraction. The slider's BOUNDS are the safety rule — a goal below a
    // healthy weight (or below the body-fat floor) can't be dialled in at all, which beats
    // typing a number and being told off for it afterwards.
    private var targetStep: some View {
        VStack(spacing: 16) {
            StepHeader(icon: usesBodyFatGoal ? "percent" : "scalemass",
                       title: usesBodyFatGoal ? "How lean do you want to be?" : "What weight are you aiming for?",
                       subtitle: targetSubtitle,
                       accent: accent)

            VStack(spacing: 14) {
                HStack(spacing: 18) {
                    nudgeButton("minus", by: -targetStepSize)
                    VStack(spacing: 2) {
                        Text(targetReadout)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(accent)
                            .contentTransition(.numericText())
                        Text(usesBodyFatGoal ? "goal body fat" : "goal weight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    nudgeButton("plus", by: targetStepSize)
                }

                Slider(value: targetBinding, in: targetRange, step: targetStepSize)
                    .tint(accent)

                HStack {
                    Text(boundLabel(targetRange.lowerBound))
                    Spacer()
                    Text(boundLabel(targetRange.upperBound))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            .padding()
            .background(surface, in: RoundedRectangle(cornerRadius: 16))

            if let delta = targetDeltaText {
                noticeCard(icon: phase == .cut ? "arrow.down.right" : "arrow.up.right", text: delta)
            }

            // CLAUDE  Date 09/20/2026
            // The one case the slider's bounds can't express: someone already at or below the
            // lowest weight Agil plans toward has no room for a deficit at all. Without this
            // they'd meet a disabled Continue and no reason for it.
            if !isGoalValid {
                noticeCard(icon: "exclamationmark.triangle",
                           text: usesBodyFatGoal
                           ? "You're already leaner than Agil will plan toward. Going lower is contest-prep territory and needs a coach, not an app."
                           : "You're already at the lowest weight Agil will plan toward, so there's no deficit to set here. Maintenance is the honest answer — go back and pick it.")
            }
        }
        .onAppear { if targetIsUnset { resetTargetToDefault() } }
    }

    private func nudgeButton(_ icon: String, by amount: Double) -> some View {
        Button {
            tapHaptic()
            let next = min(max(targetBinding.wrappedValue + amount, targetRange.lowerBound),
                           targetRange.upperBound)
            withAnimation(.easeOut(duration: 0.15)) { targetBinding.wrappedValue = next }
        } label: {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.15), in: Circle())
                .foregroundStyle(accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pace

    private var paceStep: some View {
        VStack(spacing: 16) {
            StepHeader(icon: "speedometer", title: "How fast?",
                       subtitle: "Slower keeps more muscle. Faster is harder to hold on to.",
                       accent: accent)
            paceCards
        }
    }

    // CLAUDE  Date 09/19/2026
    // Pace options come from the model, and one that breaks a safety cap for this bodyweight
    // is shown disabled rather than hidden — a user who wanted it deserves to see that it
    // exists and why it isn't on offer.
    private var paceCards: some View {
        VStack(spacing: 12) {
            ForEach(Pace.options(track: track, phase: phase), id: \.self) { option in
                let allowed = option.isWithinLimits(bodyweightLb: currentWeightLb ?? 170, phase: phase)
                ChoiceCard(isSelected: pace == option,
                           systemImage: "speedometer",
                           title: option.title(units: units),
                           description: allowed
                           ? option.detail(bodyweightLb: currentWeightLb ?? 170, units: units, phase: phase)
                           : "Faster than Agil will plan at your weight.",
                           accent: accent, surface: surface) {
                    if allowed { pace = option }
                }
                .opacity(allowed ? 1 : 0.45)
                .disabled(!allowed)
            }
        }
    }

    private func phaseIcon(_ phase: PlanPhase) -> String {
        switch phase {
        case .cut:      return "arrow.down.right.circle"
        case .maintain: return "equal.circle"
        case .leanBulk: return "arrow.up.right.circle"
        }
    }

    // MARK: - Macros

    // CLAUDE  Date 09/20/2026
    // The macro split, folded into setup — this is the old standalone macro calculator, now
    // part of building the plan rather than a second screen that could disagree with it.
    // Every option previews its real grams at this plan's calorie target.
    private var macrosStep: some View {
        VStack(spacing: 16) {
            StepHeader(icon: "chart.pie",
                       title: "How should that split?",
                       subtitle: baseCalories.map { "Dividing up \(Int($0)) kcal a day." },
                       accent: accent)

            ForEach(MacroChoice.allCases) { choice in
                ChoiceCard(isSelected: macroStyle.choice == choice,
                           systemImage: macroIcon(choice),
                           title: choice.title,
                           description: macroDescription(choice),
                           accent: accent, surface: surface) {
                    macroStyle.choice = choice
                }
            }

            if macroStyle.choice == .custom {
                VStack(spacing: 10) {
                    macroSlider("Protein", .protein)
                    macroSlider("Carbs", .carbs)
                    macroSlider("Fat", .fat)
                }
                .padding()
                .background(surface, in: RoundedRectangle(cornerRadius: 16))
            }

            if macroStyle.choice != .recommended {
                noticeCard(icon: "info.circle",
                           text: "Fat still can't go below what's healthy for hormones, whatever the split says. Carbs take whatever's left over.")
            }
        }
    }

    // CLAUDE  Date 09/20/2026
    // Moving one slider rebalances the other two so the three always sum to 100 — the model
    // owns that arithmetic (MacroStyle.rebalance), lifted from the screen this replaces.
    private func macroSlider(_ label: String, _ macro: MacroStyle.Macro) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Int(macroStyle.value(for: macro).rounded()))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { macroStyle.value(for: macro) },
                set: { macroStyle.rebalance(changing: macro, to: $0) }
            ), in: 0...100, step: 1)
            .tint(accent)
        }
    }

    private func macroIcon(_ choice: MacroChoice) -> String {
        switch choice {
        case .recommended: return "wand.and.stars"
        case .balanced:    return "circle.grid.2x2"
        case .highProtein: return "fish"
        case .lowCarb:     return "leaf"
        case .custom:      return "slider.horizontal.3"
        }
    }

    // Each option's real grams, so the choice is made on numbers rather than labels.
    private func macroDescription(_ choice: MacroChoice) -> String {
        var style = macroStyle
        style.choice = choice
        guard let calories = baseCalories, let weightLb = currentWeightLb else { return choice.detail }
        let grams = MacroPlanner.targets(calories: calories, track: track, phase: phase,
                                         weightLb: weightLb, heightCm: heightCm,
                                         leanMassLb: currentBodyFat.map { weightLb * (1 - $0 / 100) },
                                         style: style, allowCalorieRaise: true).targets
        return "\(Int(grams.protein))g protein · \(Int(grams.carbs))g carbs · \(Int(grams.fat))g fat"
    }

    // MARK: - Review

    @ViewBuilder
    private var reviewStep: some View {
        if let preview = preview {
            VStack(spacing: 16) {
                StepHeader(icon: "checklist", title: "Your plan",
                           subtitle: "You can change any of it later.", accent: accent)

                PlanTargetsCard(targets: preview.targets, accent: accent, surface: surface)

                // CLAUDE  Date 09/20/2026
                // The projection, without the derivation behind it (Bryce, 9/20/26) — where
                // the plan is headed is the user's business; how the estimate is built isn't.
                if let goal = preview.goalWeightLb, let weeks = preview.weeksToGoal {
                    noticeCard(icon: "flag",
                               text: "At this pace, about \(units.weightText(fromPounds: goal)) \(units.weightAbbreviation) in roughly \(Int(weeks.rounded())) weeks.")
                }

                ForEach(preview.flags, id: \.self) { flag in
                    noticeCard(icon: "exclamationmark.triangle", text: flag.message)
                }

                checkInCard

                Text("An estimate, not a prescription. Your first two weeks set the baseline, then the weekly check-in tunes it from your own results.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .supportingTextFont()
                    .multilineTextAlignment(.center)
            }
        } else {
            ProgressView().padding(.top, 40)
        }
    }

    private var checkInCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly check-in")
                .font(.subheadline.weight(.semibold))
            Picker("Check-in day", selection: $checkInWeekday) {
                ForEach(1...7, id: \.self) { weekday in
                    Text(Calendar.current.weekdaySymbols[weekday - 1]).tag(weekday)
                }
            }
            .pickerStyle(.menu)
            .retintOnThemeChange(theme.current, salt: "checkInDay")
            Toggle("Remind me", isOn: $remindersOn)
                .tint(accent)
            Text("The reminder never shows a number — just that the check-in is ready.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .supportingTextFont()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Shared pieces

    private var unitsPicker: some View {
        Picker("Units", selection: $unitsRaw) {
            ForEach(BodyUnits.allCases) { option in
                Text(option == .imperial ? "lb / ft" : "kg / cm").tag(option.rawValue)
            }
        }
        .pickerStyle(.segmented)
    }

    private var birthYearCard: some View {
        HStack {
            Text("Born").font(.subheadline.weight(.semibold))
            Spacer()
            Picker("Birth year", selection: $birthYear) {
                ForEach(yearRange, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.menu)
            .retintOnThemeChange(theme.current, salt: "birthYear")
        }
        .padding()
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var heightCard: some View {
        if units == .imperial {
            HStack {
                Text("Height").font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Feet", selection: $feet) {
                    ForEach(3...7, id: \.self) { Text("\($0)′").tag($0) }
                }
                .pickerStyle(.menu)
                .retintOnThemeChange(theme.current, salt: "feet")
                Picker("Inches", selection: $inches) {
                    ForEach(0...11, id: \.self) { Text("\($0)″").tag($0) }
                }
                .pickerStyle(.menu)
                .retintOnThemeChange(theme.current, salt: "inches")
            }
            .padding()
            .background(surface, in: RoundedRectangle(cornerRadius: 16))
            .onChange(of: feet) { _ in syncHeightFromImperial() }
            .onChange(of: inches) { _ in syncHeightFromImperial() }
        } else {
            HStack {
                Text("Height (cm)").font(.subheadline.weight(.semibold))
                Spacer()
                TextField("175", value: $heightCm, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
            }
            .padding()
            .background(surface, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func fieldCard(title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            TextField("", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
        .padding()
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func noticeCard(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(accent)
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

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 12) {
            if step != firstStep {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 48, height: 48)
                        .background(surface, in: Circle())
                }
                .buttonStyle(.plain)
            }
            PrimaryCTAButton(title: step == .review ? "Use this plan" : "Continue",
                             systemImage: step == .review ? "checkmark" : "chevron.right",
                             accent: accent, isDisabled: !canContinue) {
                step == .review ? finish() : goNext()
            }
        }
    }

    // MARK: - Flow

    // CLAUDE  Date 09/20/2026
    // Which pages this run actually shows: changing phase skips the questions whose answers
    // haven't changed, and maintenance skips the target and pace pages entirely — there's no
    // weight to aim at and no speed to pick. The dots and both arrows read from this, so a
    // skipped page can never be stepped into.
    private var visibleSteps: [Step] {
        Step.allCases.filter { isVisible($0) }
    }

    private func isVisible(_ step: Step) -> Bool {
        switch step {
        case .consent:
            return mode == .newPlan && !bodyStore.hasConsented
        case .track, .about, .weight, .training:
            return mode == .newPlan
        case .target, .pace:
            return phase != .maintain
        case .goal, .macros, .review:
            return true
        }
    }

    private var firstStep: Step { visibleSteps.first ?? .review }

    private func prefill() {
        step = firstStep
        if let plan = bodyStore.plan, mode == .changePhase {
            track = plan.track
            phase = plan.phase
            pace = plan.pace
            goalBodyFat = plan.targetBodyFatPct
            goalWeightLbValue = plan.targetWeightLb
            checkInWeekday = plan.checkInWeekday
            remindersOn = plan.remindersOn
        }
        if let fat = bodyStore.latestBodyFat?.bodyFatPct, bodyFatField.isEmpty {
            bodyFatField = String(format: "%.1f", fat)
        }
        if let metrics = bodyStore.data.metrics {
            sex = metrics.sex
            birthYear = metrics.birthYear
            heightCm = metrics.heightCm
            let parts = BodyUnits.feetAndInches(fromCentimeters: metrics.heightCm)
            feet = parts.feet
            inches = parts.inches
        }
        if let latest = bodyStore.latestWeightLb ?? store.profile.bodyweightLb, weightField.isEmpty {
            weightField = units.weightText(fromPounds: latest)
        }
        trainingDays = bodyStore.recentTrainingDaysPerWeek(store: store)
        cachedSessions = bodyStore.sessionSamples(
            store: store, days: Set(DayKey.window(endingOn: DayKey.key(), length: 28)))
        if let style = bodyStore.plan?.macroStyle { macroStyle = style }
    }

    private func syncHeightFromImperial() {
        heightCm = BodyUnits.centimeters(feet: feet, inches: inches)
    }

    private func goNext() {
        let steps = visibleSteps
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return }
        isForward = true
        withAnimation(.easeInOut(duration: 0.25)) { step = steps[index + 1] }
    }

    private func goBack() {
        let steps = visibleSteps
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        isForward = false
        withAnimation(.easeInOut(duration: 0.25)) { step = steps[index - 1] }
    }

    private var canContinue: Bool {
        switch step {
        case .consent:  return isAdult && notPregnant && understandsEstimates
        case .track:    return true
        case .about:    return sex != nil && heightCm > 0 && isOldEnough
        case .weight:   return (currentWeightLb ?? 0) > 0
        case .training: return true
        case .goal:     return true
        case .target:   return isGoalValid
        case .pace:     return true
        case .macros:   return true
        case .review:   return preview != nil
        }
    }

    private var isOldEnough: Bool {
        BodySafety.meetsMinimumAge(birthYear: birthYear)
    }

    private var isGoalValid: Bool {
        guard phase != .maintain else { return true }
        if usesBodyFatGoal {
            guard let goal = goalBodyFat, let sex else { return false }
            return BodyPlanBuilder.isTargetBodyFatAllowed(goal, sex: sex)
        }
        guard let goal = goalWeightLb else { return false }
        return BodyPlanBuilder.isTargetWeightAllowed(goal, heightCm: heightCm)
    }

    private var usesBodyFatGoal: Bool {
        track == .bodybuilding && phase == .cut && currentBodyFat != nil
    }

    // MARK: - The target slider

    /// The slider reads and writes whichever goal this phase is aiming at.
    private var targetBinding: Binding<Double> {
        Binding(
            get: {
                if usesBodyFatGoal { return goalBodyFat ?? defaultTarget }
                // Held in pounds, shown in whichever unit is set — so going back and flipping
                // lb/kg moves the slider, not the goal.
                if let lb = goalWeightLbValue { return units.fromPounds(lb) }
                return defaultTarget
            },
            set: { newValue in
                if usesBodyFatGoal {
                    goalBodyFat = newValue
                } else {
                    goalWeightLbValue = units.toPounds(newValue)
                }
            })
    }

    // CLAUDE  Date 09/20/2026
    // The bounds ARE the safety check: BodySafety's body-fat floor and the BMI-18.5 weight
    // floor become the bottom of the slider, so an unsafe goal simply can't be dialled in.
    private var targetRange: ClosedRange<Double> {
        let current = currentWeightLb ?? 170
        if usesBodyFatGoal {
            let floor = BodySafety.targetBodyFatFloor(sex ?? .undisclosed)
            let top = max(floor + 1, (currentBodyFat ?? 25))
            return floor...top
        }
        let currentDisplay = units.fromPounds(current)
        if phase.direction > 0 {
            return currentDisplay...(currentDisplay * 1.3)
        }
        let healthyFloor = units.fromPounds(BodySafety.minimumHealthyWeightLb(heightCm: heightCm))
        return min(healthyFloor, currentDisplay - 1)...currentDisplay
    }

    /// Half a pound, half a kilo, half a percent — fine enough to land on a round number.
    private var targetStepSize: Double { 0.5 }

    // CLAUDE  Date 09/20/2026
    // Where the slider starts: a cut defaults to 10% down (or 5 points of body fat), a bulk to
    // 5% up. Clamped into the range, so a user already near the floor doesn't start outside it.
    private var defaultTarget: Double {
        let range = targetRange
        let raw: Double
        if usesBodyFatGoal {
            raw = (currentBodyFat ?? 25) - 5
        } else {
            let currentDisplay = units.fromPounds(currentWeightLb ?? 170)
            raw = phase.direction > 0 ? currentDisplay * 1.05 : currentDisplay * 0.9
        }
        return min(max(raw, range.lowerBound), range.upperBound)
    }

    private func resetTargetToDefault() {
        if usesBodyFatGoal {
            goalBodyFat = defaultTarget
        } else {
            goalWeightLbValue = units.toPounds(defaultTarget)
        }
    }

    /// Nothing chosen yet, so the target page can seed itself the first time it appears.
    private var targetIsUnset: Bool {
        usesBodyFatGoal ? goalBodyFat == nil : goalWeightLbValue == nil
    }

    private var targetReadout: String {
        let value = targetBinding.wrappedValue
        return usesBodyFatGoal
            ? String(format: "%.1f%%", value)
            : "\(String(format: "%.1f", value)) \(units.weightAbbreviation)"
    }

    private func boundLabel(_ value: Double) -> String {
        usesBodyFatGoal ? String(format: "%.0f%%", value) : String(format: "%.0f", value)
    }

    private var targetSubtitle: String? {
        if usesBodyFatGoal {
            return "Agil won't plan below \(Int(BodySafety.targetBodyFatFloor(sex ?? .undisclosed)))% — that's contest prep, and it needs a coach."
        }
        return phase.direction > 0
            ? "Slide to where you'd like to end up."
            : "Slide to where you'd like to end up. The bottom of the slider is as low as Agil will plan."
    }

    // CLAUDE  Date 09/20/2026
    // The goal restated as the distance from here, which is the number people actually feel.
    // For a body-fat goal it also shows the weight that implies, since that's what the scale
    // will read on the day.
    private var targetDeltaText: String? {
        guard let current = currentWeightLb else { return nil }
        if usesBodyFatGoal {
            guard let goal = goalBodyFat, let fat = currentBodyFat else { return nil }
            let lean = current * (1 - fat / 100)
            guard let weight = EnergyMath.targetWeight(leanMassLb: lean, targetBodyFatPct: goal)
            else { return nil }
            return String(format: "From %.1f%% to %.1f%% — about %@ %@ on the scale, if you hold your muscle.",
                          fat, goal, units.weightText(fromPounds: weight), units.weightAbbreviation)
        }
        guard let goalLb = goalWeightLb else { return nil }
        let difference = abs(current - goalLb)
        guard difference > 0.05 else { return "That's where you are now." }
        let direction = goalLb < current ? "to lose" : "to gain"
        return "\(units.weightText(fromPounds: difference)) \(units.weightAbbreviation) \(direction) from where you are today."
    }

    // MARK: - Values

    private var yearRange: [Int] {
        let thisYear = Calendar.current.component(.year, from: Date())
        return Array(((thisYear - 90)...(thisYear - BodySafety.minimumAge)).reversed())
    }

    private var currentWeightLb: Double? {
        guard let value = Double(weightField.replacingOccurrences(of: ",", with: ".")),
              value > 0 else { return nil }
        return units.toPounds(value)
    }

    private var currentBodyFat: Double? {
        guard let value = Double(bodyFatField.replacingOccurrences(of: ",", with: ".")),
              value > 0, value < 70 else { return nil }
        return value
    }

    private var goalWeightLb: Double? {
        guard phase != .maintain, let value = goalWeightLbValue, value > 0 else { return nil }
        return value
    }

    private var metrics: BodyMetrics {
        BodyMetrics(sex: sex ?? .undisclosed, birthYear: birthYear, heightCm: heightCm,
                    trainingDaysPerWeek: trainingDays)
    }

    // CLAUDE  Date 09/19/2026
    // The live preview. Recomputed on demand rather than cached: it's pure arithmetic over a
    // month of sessions, and a stale plan on the confirm screen would be the worst kind of bug.
    private var preview: BodyPlanBuilder.Preview? {
        previewUsing(style: macroStyle)
    }

    /// The calorie target the macro step is dividing up. Independent of the split, so the
    /// options can all be priced against the same number.
    private var baseCalories: Double? {
        previewUsing(style: .recommended)?.targets.calories
    }

    private func previewUsing(style: MacroStyle) -> BodyPlanBuilder.Preview? {
        guard let weightLb = currentWeightLb else { return nil }
        let windowKeys = DayKey.window(endingOn: DayKey.key(), length: 28)
        return BodyPlanBuilder.preview(track: track, phase: phase, pace: pace, metrics: metrics,
                                       weightLb: weightLb, bodyFatPct: currentBodyFat,
                                       targetBodyFatPct: usesBodyFatGoal ? goalBodyFat : nil,
                                       targetWeightLb: goalWeightLb,
                                       style: style,
                                       sessions: cachedSessions, windowKeys: windowKeys)
    }

    // CLAUDE  Date 09/19/2026
    // The single write. Order matters: consent and metrics first, then today's weigh-in (so
    // the plan has a weight to stand on), then the plan itself — which also writes the user's
    // calorie and macro goals and ticks the Journal's setup checklist.
    private func finish() {
        guard let preview = preview, let weightLb = currentWeightLb else { return }

        if mode == .changePhase {
            bodyStore.changePhase(to: phase, pace: pace,
                                  targetBodyFatPct: usesBodyFatGoal ? goalBodyFat : nil,
                                  targetWeightLb: preview.goalWeightLb,
                                  macroStyle: macroStyle,
                                  targets: preview.targets, applyingTo: store)
            onClose()
            return
        }

        bodyStore.recordConsent()
        bodyStore.updateMetrics(metrics)
        bodyStore.logWeighIn(weightLb: weightLb, bodyFatPct: currentBodyFat)

        let plan = BodyPlan(track: track, phase: phase, pace: pace,
                            targetBodyFatPct: usesBodyFatGoal ? goalBodyFat : nil,
                            targetWeightLb: preview.goalWeightLb,
                            checkInWeekday: checkInWeekday, remindersOn: remindersOn,
                            energy: preview.model, macroStyle: macroStyle)
        bodyStore.startPlan(plan, targets: preview.targets, applyingTo: store)
        onClose()
    }
}

// CLAUDE  Date 09/19/2026
// The four numbers, big enough to be the point of the screen. Used by the wizard's review
// step and the plan hub so they can't drift apart.
struct PlanTargetsCard: View {
    let targets: PlanTargets
    let accent: Color
    let surface: Color

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                Text("\(Int(targets.calories))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                Text("kcal a day").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                macro("Protein", targets.protein, MacroPalette.protein)
                macro("Carbs", targets.carbs, MacroPalette.carbs)
                macro("Fat", targets.fat, MacroPalette.fat)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func macro(_ title: String, _ grams: Double, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(grams))g")
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
