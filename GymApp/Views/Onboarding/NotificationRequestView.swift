import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 08/13/2026
// The notification pre-permission screen, in the onboarding chrome
// (OnboardingChrome.swift).
//
// Why this exists: iOS shows the system notification dialog exactly once per
// install, ever. A "Deny" is effectively permanent — the only way back is a trip
// through Settings that almost nobody makes. So the system prompt is a one-shot
// resource, and firing it cold (which is what WorkoutNotifications
// .requestAuthorizationIfNeeded does today, on first workout start) spends it on a
// user who has no idea what we'd send. This page makes the case first, and only
// taps on "Turn on notifications" reach the real dialog.
//
// The bullets deliberately name only the two alerts that actually exist
// (Services/WorkoutNotifications.swift: rest-timer complete, and the
// still-running nudge). If that list grows, update this copy — promising
// notifications we don't send is how you get a deny.
//
// Nothing presents this yet — see .notificationAsk(isPresented:) in
// OnboardingChrome for the one-liner.
struct NotificationRequestView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.scenePhase) private var scenePhase

    /// Called for every outcome — the caller dismisses; this view never does.
    var onDismiss: () -> Void

    // Claude  Date 08/13/2026
    // Drives which CTA we show. Starts at .notDetermined only as a placeholder;
    // the real value is read in .task before the button matters, and re-read on
    // foreground so coming back from Settings updates the screen in place.
    @State private var status: UNAuthorizationStatus = .notDetermined

    private var accent: Color { theme.current.accent }

    var body: some View {
        ZStack {
            theme.current.background.ignoresSafeArea()
            // Fixed index — no wizard to advance, so the glow sits still. A
            // different index than the review page so the two don't look identical.
            AuraBackground(accent: accent, step: 2)

            VStack(spacing: 24) {
                Spacer()

                StepHeader(
                    icon: "bell.badge.fill",
                    title: "Don't miss your rest timer",
                    subtitle: subtitle,
                    accent: accent
                )

                VStack(alignment: .leading, spacing: 14) {
                    AskBullet("timer",
                              "Your rest timer buzzes even when your phone is locked or in your pocket.",
                              accent: accent)
                    AskBullet("figure.strengthtraining.traditional",
                              "A nudge if you walk away mid workout, so your session time stays accurate.",
                              accent: accent)
                    AskBullet("hand.raised.fill",
                              "That's it. No marketing, no daily pestering, nothing you didn't start.",
                              accent: accent)
                }
                .padding(.horizontal, 4)

                Spacer()

                VStack(spacing: 4) {
                    primaryButton
                    // Once permission is granted there's nothing left to decline,
                    // so the quiet way out disappears with it.
                    if status != .authorized {
                        SecondaryTextButton("Not now", action: onDismiss)
                    }
                }
            }
            .padding(24)
        }
        .interactiveDismissDisabled()
        .task { status = await WorkoutNotifications.authorizationStatus() }
        .onChange(of: scenePhase) { phase in
            // Coming back from the Settings app is the one way `status` changes
            // behind our back.
            guard phase == .active else { return }
            Task { status = await WorkoutNotifications.authorizationStatus() }
        }
    }

    // MARK: - Status-dependent pieces

    private var subtitle: String? {
        switch status {
        case .denied:
            // Claude  Date 08/13/2026
            // The honest explanation for why there's no "ask me again" button: iOS
            // won't show its dialog a second time, so Settings is genuinely the
            // only route. Saying so is better than a button that does nothing.
            return "Notifications are off for Agil. iOS only asks once, so this one has to be flipped in Settings."
        case .authorized, .provisional, .ephemeral:
            return "Notifications are already on. You're all set."
        default:
            return "We'll only use them for your workout. Promise."
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch status {
        case .denied:
            PrimaryCTAButton(title: "Open Settings",
                             systemImage: "gear",
                             accent: accent,
                             action: openSettings)
        case .authorized, .provisional, .ephemeral:
            // Shouldn't normally be reachable — the trigger that presents this page
            // is expected to check first — but a user who grants permission, then
            // backgrounds and returns, lands here. Give them a way out, not a dead
            // "Turn on notifications" button that would no-op.
            PrimaryCTAButton(title: "You're all set",
                             systemImage: "checkmark",
                             accent: accent,
                             action: onDismiss)
        default:
            PrimaryCTAButton(title: "Turn on notifications",
                             systemImage: "bell.fill",
                             accent: accent,
                             action: askSystem)
        }
    }

    // MARK: - Actions

    // Claude  Date 08/13/2026
    // Hand off to the real iOS dialog and dismiss either way — a deny is a valid
    // answer, and keeping the page up after one would just be arguing with them.
    private func askSystem() {
        Task {
            _ = await WorkoutNotifications.requestAuthorization()
            onDismiss()
        }
    }

    private func openSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
        // Not dismissed on purpose: the user is heading to Settings and coming
        // back, and .onChange(of: scenePhase) above refreshes the screen for them.
    }
}

#Preview {
    NotificationRequestView(onDismiss: {})
        .environmentObject(ThemeManager())
}
