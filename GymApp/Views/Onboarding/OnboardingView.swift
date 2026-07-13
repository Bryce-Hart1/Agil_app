import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 06/12/2026 last changed: 07/12/2026 by: Claude
// First-run welcome shown over everything until onboarding is completed. A
// short multi-step flow: (1) name, (2) where your data lives (offline vs
// friends), (3) how coins work — then into the app. (Redesigned this pass:
// added a drifting accent-glow background, directional slide transitions
// between steps, an animated logo entrance, richer choice cards, an animated
// coin-ladder chart, and gradient controls. Persistence behavior unchanged.)
struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    // Claude  Date 06/13/2026
    // The ordered onboarding steps.
    private enum Step: Int, CaseIterable { case welcome, data, coins }

    @State private var step: Step = .welcome
    @State private var name = ""
    @State private var dataMode: DataMode = .offline

    // Claude  Date 07/12/2026
    // Tracks which way we're moving through the wizard so the step transition
    // slides in from the correct edge (forward = from the right, back = left).
    @State private var goingForward = true

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var accent: Color { theme.current.accent }
    private var surface: Color { theme.current.surface }

    var body: some View {
        ZStack {
            theme.current.background.ignoresSafeArea()
            AuraBackground(accent: accent, step: step.rawValue)

            VStack(spacing: 24) {
                progressDots

                // The current step's content.
                Group {
                    switch step {
                    case .welcome:
                        WelcomeStep(name: $name, accent: accent, surface: surface,
                                    canAdvance: !trimmedName.isEmpty, onSubmit: advance)
                    case .data: dataStep
                    case .coins: coinsStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(stepTransition)

                controls
            }
            .padding(24)
        }
        .interactiveDismissDisabled()
    }

    // Claude  Date 07/12/2026
    // Slide + fade between steps, direction-aware so Back feels like backing up.
    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: - Steps

    private var dataStep: some View {
        VStack(spacing: 18) {
            Spacer()

            stepHeader(
                icon: "externaldrive.badge.icloud",
                title: "Nice to meet you, \(trimmedName)!",
                subtitle: "Where should your data live? You can change this anytime in Settings."
            )

            choiceCard(
                .offline,
                systemImage: "iphone",
                title: "Offline",
                description: "Everything stays on this device. Private, fast, and yours alone."
            )
            choiceCard(
                .friends,
                systemImage: "person.2.fill",
                title: "Friends only",
                description: "Add people with a friend code to see their profile card and stats. (Coming soon.)"
            )
            Spacer()
        }
    }

    private var coinsStep: some View {
        VStack(spacing: 18) {
            Spacer()

            stepHeader(
                icon: "circle.hexagongrid.fill",
                title: "Show up. Stack coins.",
                subtitle: "Consistency is the whole game — here's how it pays."
            )

            // Claude  Date 07/12/2026
            // Animated ladder showing the weekly coin payouts (10 → 100) so the
            // reward curve is visible at a glance instead of buried in a sentence.
            CoinLadder(accent: accent, surface: surface)

            VStack(alignment: .leading, spacing: 12) {
                coinBullet("calendar", "Every day you train in a week climbs the ladder — hit more days, earn bigger coins.")
                coinBullet("arrow.clockwise", "The ladder resets Sunday night, so streaks of consistent weeks pay off most.")
                coinBullet("bag.fill", "Spend your coins in the Shop on new themes and profile-card styles.")
            }
            .padding(.horizontal, 4)
            Spacer()
        }
    }

    // MARK: - Building blocks

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(
                        s.rawValue <= step.rawValue
                            ? AnyShapeStyle(LinearGradient(colors: [accent, accent.opacity(0.7)],
                                                           startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.secondary.opacity(0.25))
                    )
                    .frame(width: s == step ? 26 : 8, height: 8)
                    .shadow(color: s == step ? accent.opacity(0.5) : .clear, radius: 4)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
    }

    private func stepHeader(icon: String, title: String, subtitle: String?) -> some View {
        VStack(spacing: 12) {
            // Claude  Date 07/12/2026
            // Icon now sits in a soft accent-tinted circle instead of floating bare,
            // giving each step a visual anchor that matches the glow background.
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 84, height: 84)
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(accent)
            }
            Text(title)
                .font(.system(.title2, design: .rounded).bold())
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func choiceCard(_ mode: DataMode, systemImage: String,
                            title: String, description: String) -> some View {
        let isSelected = dataMode == mode
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { dataMode = mode }
            tapHaptic()
        } label: {
            HStack(spacing: 14) {
                // Claude  Date 07/12/2026
                // Icon in a tinted rounded tile so the selected card reads instantly.
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? accent.opacity(0.18) : Color.secondary.opacity(0.1))
                        .frame(width: 46, height: 46)
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(isSelected ? accent : .secondary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(description)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? accent : Color.secondary.opacity(0.5))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? accent : Color.secondary.opacity(0.15),
                            lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? accent.opacity(0.25) : .clear, radius: 10, y: 4)
            .scaleEffect(isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func coinBullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(accent)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 12) {
            if step != .welcome {
                // Claude  Date 07/12/2026
                // Back is now a compact circular chevron so the primary button owns the row.
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 52, height: 52)
                        .background(surface, in: Circle())
                        .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }

            // Claude  Date 07/12/2026
            // Primary CTA: gradient capsule with a trailing icon and an accent glow.
            // .borderedProminent grays itself out when disabled; a plain-style button
            // doesn't, so the disabled look is applied manually via opacity.
            Button(action: advance) {
                HStack(spacing: 8) {
                    Text(step == .coins ? "Start Lifting" : "Continue")
                        .fontWeight(.semibold)
                    Image(systemName: step == .coins
                          ? "figure.strengthtraining.traditional" : "arrow.right")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [accent, accent.opacity(0.75)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Capsule()
                )
                .foregroundStyle(.white)
                .shadow(color: accent.opacity(continueDisabled ? 0 : 0.4), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(continueDisabled)
            .opacity(continueDisabled ? 0.45 : 1)
            .animation(.easeInOut(duration: 0.2), value: continueDisabled)
        }
    }

    private var continueDisabled: Bool { step == .welcome && trimmedName.isEmpty }

    // MARK: - Navigation

    private func advance() {
        goingForward = true
        tapHaptic()
        switch step {
        case .welcome:
            guard !trimmedName.isEmpty else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step = .data }
        case .data:
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step = .coins }
        case .coins:
            finish()
        }
    }

    private func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        goingForward = false
        tapHaptic()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step = previous }
    }

    private func finish() {
        store.profile.displayName = trimmedName
        store.profile.dataMode = dataMode
        store.profile.hasOnboarded = true
    }
}

// Claude  Date 07/12/2026
// Light haptic tick for onboarding taps. UIKit-only, no-op elsewhere (previews
// on mac, etc.), and safe on iOS 16 — .sensoryFeedback would need iOS 17.
private func tapHaptic() {
    #if canImport(UIKit)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    #endif
}

// Claude  Date 07/12/2026
// Two big blurred accent circles behind the content. Their positions are keyed
// to the current step index, so advancing through the wizard gently drifts the
// glow around the screen — cheap "alive" feeling with no timers.
private struct AuraBackground: View {
    let accent: Color
    let step: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Circle()
                    .fill(accent.opacity(0.22))
                    .frame(width: w * 0.95)
                    .blur(radius: 60)
                    .offset(x: [-w * 0.35, w * 0.4, -w * 0.25][step % 3],
                            y: [-h * 0.3, -h * 0.38, -h * 0.15][step % 3])
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: w * 0.8)
                    .blur(radius: 70)
                    .offset(x: [w * 0.4, -w * 0.35, w * 0.3][step % 3],
                            y: [h * 0.35, h * 0.3, h * 0.42][step % 3])
            }
            .animation(.easeInOut(duration: 0.9), value: step)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// Claude  Date 07/12/2026
// Step 1 as its own view so it can own its entrance animation state: the logo
// springs in with a glow, then the title/field fade up. Re-runs if the user
// comes back to this step, which reads as intentional polish rather than a bug.
private struct WelcomeStep: View {
    @Binding var name: String
    let accent: Color
    let surface: Color
    let canAdvance: Bool
    let onSubmit: () -> Void

    @State private var logoShown = false
    @State private var contentShown = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(accent.opacity(0.25))
                    .frame(width: 140, height: 140)
                    .blur(radius: 24)
                Image("AppLogo")
                    .resizable().scaledToFit()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
            }
            .scaleEffect(logoShown ? 1 : 0.5)
            .opacity(logoShown ? 1 : 0)

            VStack(spacing: 8) {
                Text("Welcome to Agil")
                    .font(.system(.largeTitle, design: .rounded).bold())
                Text("Track your lifts. Build your streak. Level up.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(contentShown ? 1 : 0)
            .offset(y: contentShown ? 0 : 16)

            VStack(alignment: .leading, spacing: 10) {
                Text("What should we call you?").font(.headline)
                HStack(spacing: 10) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(accent)
                    TextField("First name", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .onSubmit { if canAdvance { onSubmit() } }
                }
                .padding(14)
                .background(surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(canAdvance ? accent.opacity(0.6) : Color.secondary.opacity(0.2),
                                lineWidth: 1.5)
                )
                .animation(.easeInOut(duration: 0.2), value: canAdvance)
            }
            .padding(.top, 8)
            .opacity(contentShown ? 1 : 0)
            .offset(y: contentShown ? 0 : 16)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) { logoShown = true }
            withAnimation(.easeOut(duration: 0.45).delay(0.25)) { contentShown = true }
        }
    }
}

// Claude  Date 07/12/2026
// Mini bar chart of the weekly coin payouts (1..5+ training days → 10..100
// coins). Bars grow in with a staggered spring when the step appears, which is
// the "wow" beat of the coins page. Values mirror the copy in coinsStep — if
// the reward curve changes, update both.
private struct CoinLadder: View {
    let accent: Color
    let surface: Color

    @State private var shown = false
    private let payouts = [10, 20, 40, 80, 100]

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(Array(payouts.enumerated()), id: \.offset) { index, coins in
                VStack(spacing: 6) {
                    Text("\(coins)")
                        .font(.caption.bold())
                        .foregroundStyle(index == payouts.count - 1 ? accent : .secondary)
                        .opacity(shown ? 1 : 0)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [accent, accent.opacity(0.5)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: shown ? CGFloat(coins) * 0.75 + 14 : 8)
                    Text(index == payouts.count - 1 ? "5+" : "\(index + 1)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.7)
                    .delay(Double(index) * 0.08), value: shown)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            Text("days per week")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(8)
        }
        .onAppear { shown = true }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
