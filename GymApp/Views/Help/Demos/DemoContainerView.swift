import SwiftUI

// CLAUDE  Date 09/26/2026 last changed: 09/27/2026 by: CLAUDE
// The demos Help & Demos can launch. Each case maps to one script + shell in `DemoLauncher`;
// a new demo gets a case here and a `.demo(...)` guide in HelpGuideCatalog.
enum DemoKind: String, Identifiable {
    case newWorkout, presetWorkout, buildPreset, customExercise, logMeal, customFood, recipe

    var id: String { rawValue }
}

// CLAUDE  Date 09/26/2026
// What a full-screen demo cover shows for each kind. Re-applies the root's tint, face and
// color scheme, since a presented cover doesn't reliably inherit them.
struct DemoLauncher: View {
    let kind: DemoKind
    let title: String

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        Group {
            switch kind {
            case .newWorkout:
                DemoContainerView(title: title, script: WorkoutDemoScript(.blank)) { runner in
                    WorkoutDemoShell(runner: runner)
                }
            case .presetWorkout:
                DemoContainerView(title: title, script: WorkoutDemoScript(.preset)) { runner in
                    WorkoutDemoShell(runner: runner)
                }
            case .buildPreset:
                DemoContainerView(title: title, script: PresetDemoScript()) { runner in
                    PresetDemoShell(runner: runner)
                }
            case .customExercise:
                DemoContainerView(title: title, script: ExerciseDemoScript()) { runner in
                    ExerciseDemoShell(runner: runner)
                }
            case .logMeal:
                DemoContainerView(title: title, script: MealDemoScript()) { runner in
                    MealDemoShell(runner: runner)
                }
            case .customFood:
                DemoContainerView(title: title, script: FoodDemoScript()) { runner in
                    FoodDemoShell(runner: runner)
                }
            case .recipe:
                DemoContainerView(title: title, script: RecipeDemoScript()) { runner in
                    RecipeDemoShell(runner: runner)
                }
            }
        }
        .tint(theme.current.accent)
        .fontDesign(theme.fontDesign.design)
        .preferredColorScheme(theme.current.preferredColorScheme)
    }
}

// CLAUDE  Date 09/26/2026
// One running demo: a close button and title, the fake app in a rounded lit frame (inset,
// not scaled, so everything is real size), and the guide panel with the step text and the
// back/forward arrows. Owns the runner; the shell only reads and taps through it.
struct DemoContainerView<Script: DemoScript, Shell: View>: View {
    let title: String
    @StateObject private var runner: DemoRunner<Script>
    private let shell: (DemoRunner<Script>) -> Shell

    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private static var frameShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
    }

    init(title: String, script: Script,
         @ViewBuilder shell: @escaping (DemoRunner<Script>) -> Shell) {
        self.title = title
        _runner = StateObject(wrappedValue: DemoRunner(script: script))
        self.shell = shell
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            shell(runner)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(Self.frameShape)
                .overlay(AccentRim(shape: Self.frameShape, accent: theme.current.accent))
                .padding(.horizontal, 14)

            guidePanel
        }
        .padding(.bottom, 8)
        .background(theme.current.background.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 52)
            HStack {
                Button {
                    hideKeyboard()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(theme.current.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close demo")
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    // MARK: - Guide panel

    // CLAUDE  Date 09/26/2026
    // The step text over the arrows and progress dots. The text keeps a 3-line floor so the
    // frame above doesn't jump as steps change length. The last step's forward is Done.
    private var guidePanel: some View {
        VStack(spacing: 14) {
            Text(runner.step.text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 58)
                .id(runner.index)
                .transition(.opacity)

            HStack(spacing: 12) {
                arrowButton("chevron.left", label: "Previous step", disabled: runner.isFirst) {
                    hideKeyboard()
                    runner.back()
                }
                Spacer(minLength: 0)
                progressDots
                Spacer(minLength: 0)
                if runner.isLast {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 18)
                            .frame(height: 44)
                            .background(theme.current.accent.opacity(0.18), in: Capsule())
                            .overlay(Capsule().stroke(theme.current.accent.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                } else {
                    arrowButton("chevron.right", label: "Next step", disabled: false) {
                        hideKeyboard()
                        runner.forward()
                    }
                }
            }
        }
        .padding(16)
        .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(AccentRim(shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
                           accent: theme.current.accent))
        .padding(.horizontal, 14)
        .animation(.easeInOut(duration: 0.2), value: runner.index)
    }

    private func arrowButton(_ symbol: String, label: String, disabled: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 44, height: 44)
                .background(theme.current.accent.opacity(0.15), in: Circle())
                .overlay(Circle().stroke(theme.current.accent.opacity(0.4), lineWidth: 1))
                .foregroundStyle(theme.current.accent)
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.3 : 1)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    // Same capsule dots as TourOverlay: done and current filled, the current one stretched.
    private var progressDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<runner.stepCount, id: \.self) { i in
                Capsule()
                    .fill(i <= runner.index ? theme.current.accent : Color.secondary.opacity(0.3))
                    .frame(width: i == runner.index ? 16 : 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(runner.index + 1) of \(runner.stepCount)")
    }
}
