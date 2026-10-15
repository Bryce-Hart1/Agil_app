import SwiftUI

// CLAUDE  Date 10/02/2026
// Quick add as a fullscreen flow, one number per screen: calories, protein, fat, carbs, then a
// review with label, meal and time. Opened by the Log's bolt. The first open shows three intro
// cards (the ? replays them). Macros past the calories are scaled to fit unless the user keeps them.
struct QuickAddFlow: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    // CLAUDE  Date 10/02/2026
    // Plain UserDefaults, not a NutritionSetup field: a new field there fails to decode on
    // older saves, and a failed decode resets the whole profile (see Supplement.swift).
    static let introSeenKey = "hasSeenQuickAddIntro"
    @AppStorage(QuickAddFlow.introSeenKey) private var hasSeenIntro = false

    enum Step: Int, CaseIterable {
        case calories, protein, fat, carbs, review
    }

    let date: Date
    @State private var meal: MealType
    @State private var time = Date()
    @State private var timeTouched = false
    @State private var draft = QuickNutrientDraft()
    @State private var label = ""
    // "Keep my numbers": log the macros as typed even though they're past the calories.
    @State private var keepTyped = false
    @State private var step: Step = .calories
    @State private var isForward = true
    @State private var showingIntro: Bool
    @State private var introPage = 0
    @State private var presentationSettled = false
    @FocusState private var focusedField: Step?

    init(meal: MealType, date: Date) {
        self.date = date
        _meal = State(initialValue: meal)
        // Read up front so a first open starts on the intro rather than flashing calories.
        _showingIntro = State(initialValue: !UserDefaults.standard.bool(forKey: Self.introSeenKey))
    }

    private var accent: Color { theme.current.accent }
    private var surface: Color { theme.current.surface }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.current.background.ignoresSafeArea()
                AuraBackground(accent: accent, step: showingIntro ? introPage : step.rawValue)
                if showingIntro {
                    intro
                        .transition(.opacity)
                } else {
                    VStack(spacing: 18) {
                        StepDots(count: Step.allCases.count, index: step.rawValue, accent: accent)
                            .padding(.top, 8)
                        content
                        controls
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 20)
                    .transition(.opacity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !showingIntro {
                        Button(action: replayIntro) {
                            Image(systemName: "questionmark.circle")
                        }
                        .accessibilityLabel("How quick add works")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(accent)
        .task(id: showingIntro ? -1 : step.rawValue) { await refocus() }
        // New numbers get a fresh over-check, so an earlier "Keep my numbers" doesn't stick.
        .onChange(of: draft) { _ in keepTyped = false }
    }

    // MARK: - Intro

    private struct IntroCard {
        let icon: String
        let title: String
        let text: String
    }

    private static let introCards = [
        IntroCard(icon: "bolt.fill", title: "Quick add",
                  text: "For when you know the numbers but not the food. Eating out, a friend's cooking, or a good guess."),
        IntroCard(icon: "list.number", title: "Calories first, then macros",
                  text: "Start with the total. Protein, fat and carbs come next, and you can skip any you don't know."),
        IntroCard(icon: "checkmark.shield", title: "We keep the math honest",
                  text: "If your macros add up to more than your calories, we scale them down to fit. If your numbers came off a label, you can keep them.")
    ]

    private var isLastIntroPage: Bool { introPage == Self.introCards.count - 1 }

    // CLAUDE  Date 10/02/2026
    // The walkthrough: swipeable cards with Next / Got it, and Skip on all but the last.
    // Finishing either way marks it seen and drops into the calories step.
    private var intro: some View {
        VStack(spacing: 18) {
            StepDots(count: Self.introCards.count, index: introPage, accent: accent)
                .padding(.top, 8)
            TabView(selection: $introPage) {
                ForEach(Array(Self.introCards.enumerated()), id: \.offset) { index, card in
                    VStack {
                        Spacer()
                        StepHeader(icon: card.icon, title: card.title, subtitle: card.text,
                                   accent: accent)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            VStack(spacing: 4) {
                PrimaryCTAButton(title: isLastIntroPage ? "Got it" : "Next",
                                 systemImage: isLastIntroPage ? "checkmark" : "chevron.right",
                                 accent: accent) {
                    if isLastIntroPage {
                        finishIntro()
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) { introPage += 1 }
                    }
                }
                // Hidden rather than removed on the last card so the CTA doesn't jump.
                SecondaryTextButton("Skip", action: finishIntro)
                    .opacity(isLastIntroPage ? 0 : 1)
                    .disabled(isLastIntroPage)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 20)
    }

    private func finishIntro() {
        hasSeenIntro = true
        withAnimation(.easeInOut(duration: 0.25)) { showingIntro = false }
    }

    private func replayIntro() {
        focusedField = nil
        introPage = 0
        withAnimation(.easeInOut(duration: 0.25)) { showingIntro = true }
    }

    // MARK: - Steps

    // CLAUDE  Date 10/02/2026
    // Each step is its own scroll view (keyed by step) inside a ZStack, so the outgoing and
    // incoming pages overlap while they slide instead of stacking for a frame.
    private var content: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    switch step {
                    case .calories: caloriesStep
                    case .protein, .fat, .carbs: macroStep(step)
                    case .review: reviewStep
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: isForward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: isForward ? .leading : .trailing).combined(with: .opacity)))
        }
        .frame(maxHeight: .infinity)
    }

    private var caloriesStep: some View {
        VStack(spacing: 16) {
            StepHeader(icon: "flame.fill", title: "About how many calories?",
                       subtitle: "A good guess is fine.", accent: accent)
            numberCard(text: $draft.calories, unit: "kcal", tint: accent, field: .calories)
        }
    }

    // CLAUDE  Date 10/02/2026
    // Protein, fat or carbs: the macro's own color, the number, and how the calories are
    // holding up so far. Carbs also offers to fill whatever calories are left.
    private func macroStep(_ macro: Step) -> some View {
        let info = macroInfo(macro)
        return VStack(spacing: 16) {
            StepHeader(icon: info.icon, title: info.title,
                       subtitle: "In grams. Skip it if you don't know.", accent: info.color)
            numberCard(text: info.text, unit: "g", tint: info.color, field: macro)
            if macro == .carbs { fillRestButton }
            budgetLine
        }
    }

    private func macroInfo(_ macro: Step) -> (icon: String, title: String, color: Color, text: Binding<String>) {
        switch macro {
        case .fat:   return ("drop.fill", "How much fat?", MacroPalette.fat, $draft.fat)
        case .carbs: return ("leaf.fill", "And carbs?", MacroPalette.carbs, $draft.carbs)
        default:     return ("fish.fill", "How much protein?", MacroPalette.protein, $draft.protein)
        }
    }

    // CLAUDE  Date 10/02/2026
    // One big centered number. Tapping anywhere on the card puts the cursor back in it, since
    // a decimal pad has no return key and scrolling can dismiss it.
    private func numberCard(text: Binding<String>, unit: String, tint: Color, field: Step) -> some View {
        VStack(spacing: 2) {
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
                .focused($focusedField, equals: field)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { focusedField = field }
    }

    // CLAUDE  Date 10/02/2026
    // Calories left after the macros typed so far, or a heads-up once they're past the
    // calories by more than rounding (the review step then shows them scaled to fit).
    @ViewBuilder
    private var budgetLine: some View {
        let calories = draft.nutrients.calories
        let used = draft.macroCalories
        if QuickAddMath.isOver(macroCalories: used, calories: calories) {
            noticeCard(icon: "arrow.down.right.circle",
                       text: "That's \(kcal(used - calories)) kcal over \(kcal(calories)). We'll scale your macros down to fit.")
        } else {
            Text(used <= calories
                 ? "\(kcal(calories - used)) kcal left of \(kcal(calories))"
                 : "Right about \(kcal(calories)) kcal")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var fillRestButton: some View {
        let n = draft.nutrients
        if let rest = QuickAddMath.fillRestCarbs(calories: n.calories, protein: n.protein, fat: n.fat),
           n.carbs != rest {
            Button {
                tapHaptic()
                draft.carbs = String(Int(rest))
            } label: {
                Label("Fill the rest · \(Int(rest)) g", systemImage: "wand.and.stars")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(MacroPalette.carbs.opacity(0.15), in: Capsule())
                    .foregroundStyle(MacroPalette.carbs)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Review

    private var fit: QuickAddMath.Fit { QuickAddMath.fit(draft.nutrients) }

    // What Add writes: the scaled macros, unless the user chose to keep theirs.
    private var loggedNutrients: Nutrients {
        keepTyped ? draft.nutrients : fit.nutrients
    }

    private var reviewStep: some View {
        let fit = self.fit
        return VStack(spacing: 16) {
            StepHeader(icon: "checkmark.circle", title: "Look right?",
                       subtitle: "Add a label if you like, and check the meal and time.",
                       accent: accent)
            summaryCard(loggedNutrients)
            if fit.wasScaled { scaledNotice(fit) }
            HStack {
                Text("Label").font(.subheadline.weight(.semibold))
                Spacer()
                TextField("Optional", text: $label)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
            }
            .padding()
            .background(surface, in: RoundedRectangle(cornerRadius: 16))
            MealTimePicker(meal: $meal, time: $time, accent: accent, touched: $timeTouched) { meal in
                store.suggestedLogTime(for: meal, on: date)
            }
            .padding()
            .background(surface, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // CLAUDE  Date 10/02/2026
    // The four numbers that will be logged, in PlanTargetsCard's shape: calories big, then
    // protein, carbs and fat in their macro colors (the order the rest of the Log uses).
    private func summaryCard(_ n: Nutrients) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(kcal(n.calories))
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())
                Text("kcal").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                macroColumn("Protein", n.protein, MacroPalette.protein)
                macroColumn("Carbs", n.carbs, MacroPalette.carbs)
                macroColumn("Fat", n.fat, MacroPalette.fat)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func macroColumn(_ title: String, _ grams: Double, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(FoodMeasurement.number(grams, decimals: 1))g")
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // CLAUDE  Date 10/02/2026
    // Says the macros were scaled and offers to keep them as typed, for label numbers where
    // fiber or sugar alcohols make 4/4/9 overshoot. The button flips back to scaling.
    private func scaledNotice(_ fit: QuickAddMath.Fit) -> some View {
        let typed = kcal(fit.typedMacroCalories)
        let calories = kcal(fit.nutrients.calories)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: keepTyped ? "pencil.circle" : "arrow.down.right.circle")
                    .foregroundStyle(accent)
                Text(keepTyped
                     ? "Keeping your macros as typed. They come to \(typed) kcal, more than the \(calories) you entered."
                     : "Your macros came to \(typed) kcal, more than the \(calories) you entered, so we scaled them to fit. If they came off a label, keep them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .supportingTextFont()
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            Button {
                tapHaptic()
                withAnimation(.easeInOut(duration: 0.2)) { keepTyped.toggle() }
            } label: {
                Text(keepTyped ? "Scale to fit" : "Keep my numbers")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            .padding(.leading, 30)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
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
            if step != .calories {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 48, height: 48)
                        .background(surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }
            PrimaryCTAButton(title: ctaTitle,
                             systemImage: step == .review ? "checkmark" : "chevron.right",
                             accent: accent, isDisabled: !canContinue) {
                step == .review ? add() : goNext()
            }
        }
    }

    // A macro step left blank reads "Skip", so moving on without a number is obviously fine.
    private var ctaTitle: String {
        switch step {
        case .calories: return "Next"
        case .protein:  return isBlank(draft.protein) ? "Skip" : "Next"
        case .fat:      return isBlank(draft.fat) ? "Skip" : "Next"
        case .carbs:    return isBlank(draft.carbs) ? "Skip" : "Next"
        case .review:   return "Add to \(meal.title)"
        }
    }

    // Calories are required here. The draft would count blank calories from the macros
    // (the Edit Entry form relies on that), so check the typed text, not resolvedCalories.
    private var hasCalories: Bool {
        !isBlank(draft.calories) && draft.nutrients.calories > 0
    }

    private var canContinue: Bool {
        switch step {
        case .calories, .review: return hasCalories
        case .protein, .fat, .carbs: return true
        }
    }

    // MARK: - Flow

    private func goNext() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        isForward = true
        withAnimation(.easeInOut(duration: 0.25)) { step = next }
    }

    private func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        isForward = false
        withAnimation(.easeInOut(duration: 0.25)) { step = previous }
    }

    // CLAUDE  Date 10/02/2026
    // Puts the cursor in the current step's number. A fullscreen cover ignores focus until it
    // has settled, so the first time waits longer; review and the intro drop the keyboard.
    private func refocus() async {
        guard !showingIntro, step != .review else {
            focusedField = nil
            return
        }
        try? await Task.sleep(for: .milliseconds(presentationSettled ? 80 : 450))
        guard !Task.isCancelled else { return }
        presentationSettled = true
        focusedField = step
    }

    private func add() {
        let name = label.trimmingCharacters(in: .whitespaces)
        store.logQuickAdd(name: name.isEmpty ? "quick add" : name, nutrients: loggedNutrients,
                          meal: meal, on: date, at: time)
        Haptics.success()
        dismiss()
    }

    // MARK: - Helpers

    private func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func kcal(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }
}

#Preview {
    QuickAddFlow(meal: .lunch, date: Date())
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
