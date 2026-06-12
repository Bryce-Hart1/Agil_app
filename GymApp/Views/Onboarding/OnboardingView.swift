import SwiftUI

// Claude  Date 06/12/2026
// First-run welcome shown over everything until the user enters a name. This is
// the first of an eventual series of onboarding prompts — for now, just the name
// (first name). Completing it sets profile.hasOnboarded, which dismisses it.
struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @State private var name = ""

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(radius: 8, y: 4)

            VStack(spacing: 6) {
                Text("Welcome to Agil")
                    .font(.largeTitle.bold())
                Text("Your Tracking & Marking App")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What's your first name?")
                    .font(.headline)
                TextField("First name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit(finish)
            }
            .padding(.top, 8)

            Spacer()

            Button(action: finish) {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.current.accent)
            .controlSize(.large)
            .disabled(trimmedName.isEmpty)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.current.background.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    private func finish() {
        guard !trimmedName.isEmpty else { return }
        store.profile.displayName = trimmedName
        store.profile.hasOnboarded = true
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
