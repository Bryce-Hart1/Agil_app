import SwiftUI

// Claude  Date 06/12/2026 last changed: 06/13/2026 by: Claude
// First-run welcome shown over everything until onboarding is completed. Now a
// short multi-step flow: (1) name, (2) where your data lives (offline vs friends),
// (3) how coins work — then into the app. This is an early pass; the data-mode
// and coins steps will get fleshed out later (friend codes, richer rewards).
struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    // Claude  Date 06/13/2026
    // The ordered onboarding steps.
    private enum Step: Int, CaseIterable { case welcome, data, coins }

    @State private var step: Step = .welcome
    @State private var name = ""
    @State private var dataMode: DataMode = .offline

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var accent: Color { theme.current.accent }

    var body: some View {
        VStack(spacing: 24) {
            progressDots

            // The current step's content.
            Group {
                switch step {
                case .welcome: welcomeStep
                case .data: dataStep
                case .coins: coinsStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)

            controls
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.current.background.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("AppLogo")
                .resizable().scaledToFit()
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(radius: 8, y: 4)

            VStack(spacing: 6) {
                Text("Welcome to Agil").font(.largeTitle.bold())
                Text("Your Tracking & Marking App")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What's your first name?").font(.headline)
                TextField("First name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .onSubmit { if !trimmedName.isEmpty { advance() } }
            }
            .padding(.top, 8)
            Spacer()
        }
    }

    private var dataStep: some View {
        VStack(spacing: 18) {
            Spacer()
            stepHeader(
                icon: "externaldrive.badge.icloud",
                title: "Where should your data live?",
                subtitle: "You can change this later."
            )

            choiceCard(
                .offline,
                systemImage: "iphone",
                title: "Offline",
                description: "Everything stays on this device. Private and fast — but you can't add other people."
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
                title: "Earn coins as you train",
                subtitle: nil
            )

            VStack(alignment: .leading, spacing: 14) {
                coinBullet("calendar", "Train each week to earn coins. The more days you hit in a week, the more you earn — 10, then 20, 40, 80, up to 100.")
                coinBullet("arrow.clockwise", "The weekly bonus resets every Sunday night, so showing up consistently pays off most.")
                coinBullet("bag.fill", "Spend coins in the Shop on new themes and profile-card styles.")
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
                    .fill(s == step ? accent : Color.secondary.opacity(0.3))
                    .frame(width: s == step ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut, value: step)
    }

    private func stepHeader(icon: String, title: String, subtitle: String?) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(accent)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func choiceCard(_ mode: DataMode, systemImage: String,
                            title: String, description: String) -> some View {
        Button {
            withAnimation(.easeInOut) { dataMode = mode }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2).frame(width: 34)
                    .foregroundStyle(dataMode == mode ? accent : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(description)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: dataMode == mode ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(dataMode == mode ? accent : .secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(dataMode == mode ? accent : .clear, lineWidth: 2)
            )
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
                Button("Back") { goBack() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            Button(action: advance) {
                Text(step == .coins ? "Start Lifting" : "Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .controlSize(.large)
            .disabled(step == .welcome && trimmedName.isEmpty)
        }
    }

    // MARK: - Navigation

    private func advance() {
        switch step {
        case .welcome:
            guard !trimmedName.isEmpty else { return }
            withAnimation { step = .data }
        case .data:
            withAnimation { step = .coins }
        case .coins:
            finish()
        }
    }

    private func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation { step = previous }
    }

    private func finish() {
        store.profile.displayName = trimmedName
        store.profile.dataMode = dataMode
        store.profile.hasOnboarded = true
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
