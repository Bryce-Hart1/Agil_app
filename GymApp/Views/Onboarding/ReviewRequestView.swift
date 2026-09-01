import SwiftUI
import StoreKit

// Claude  Date 08/13/2026
// The review soft-ask. Wears the onboarding chrome (OnboardingChrome.swift) so it
// reads as part of the app's voice rather than a bolted-on nag.
//
// Why a screen at all instead of just calling requestReview() directly: iOS gives
// each app a *very* small number of review prompts per year, and firing one at a
// random moment burns it on whoever happens to be mid-set. This page asks first —
// only people who tap "Leave a review" ever reach the system prompt, so the scarce
// prompts land on people already inclined to say something nice.
//
// Copy below is a first draft and expected to be rewritten. The argument it makes
// is the honest one: no ads, no paywall, so word of mouth is the only growth lever.
//
// Nothing presents this yet — see .reviewAsk(isPresented:) in OnboardingChrome for
// the one-liner, and pick the trigger (after a PR, after N workouts, …) separately.
struct ReviewRequestView: View {
    @EnvironmentObject private var theme: ThemeManager

    // Claude  Date 08/13/2026
    // SwiftUI's RequestReviewAction (iOS 16+, and we target 16.1) rather than
    // SKStoreReviewController.requestReview(in:), which is deprecated and needs a
    // UIWindowScene we'd have to go fishing for.
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    /// Called for both outcomes — the caller dismisses; this view never does.
    var onDismiss: () -> Void

    @State private var starsShown = false

    private var accent: Color { theme.current.accent }

    var body: some View {
        ZStack {
            theme.current.background.ignoresSafeArea()
            // Fixed index: no wizard to advance, so the glow just sits still.
            AuraBackground(accent: accent, step: 1)

            VStack(spacing: 24) {
                Spacer()

                starRow

                StepHeader(
                    icon: "star.bubble.fill",
                    title: "Help keep Agil free",
                    subtitle: "Thirty seconds from you goes a long way.",
                    accent: accent
                )

                VStack(alignment: .leading, spacing: 14) {
                    AskBullet("heart.fill",
                              "Agil has no ads, and the stuff that matters isn't behind a paywall.",
                              accent: accent)
                    AskBullet("magnifyingglass",
                              "Reviews are how people find us — they're basically the whole marketing budget.",
                              accent: accent)
                    AskBullet("clock.fill",
                              "It takes about ten seconds, and it genuinely helps.",
                              accent: accent)
                }
                .padding(.horizontal, 4)

                Spacer()

                VStack(spacing: 4) {
                    PrimaryCTAButton(title: "Leave a review",
                                     systemImage: "star.fill",
                                     accent: accent,
                                     action: leaveReview)
                    SecondaryTextButton("Maybe later", action: onDismiss)
                }
            }
            .padding(24)
        }
        .interactiveDismissDisabled()
        .onAppear {
            starsShown = true
        }
    }

    // Claude  Date 08/13/2026
    // Five stars springing in one after another — the same staggered
    // .delay(index * 0.08) beat CoinLadder uses on the coins step, so the two
    // "wow" moments in the app feel like they were built by the same hand.
    private var starRow: some View {
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(accent)
                    .scaleEffect(starsShown ? 1 : 0.3)
                    .opacity(starsShown ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6)
                        .delay(Double(index) * 0.08), value: starsShown)
            }
        }
        .shadow(color: accent.opacity(0.4), radius: 8)
    }

    // Claude  Date 08/13/2026
    // Ask, then get out of the way — unconditionally. requestReview() is heavily
    // rate-limited by Apple and very often shows *nothing at all*, and it reports
    // neither whether a prompt appeared nor what the user did. So we cannot wait on
    // it or branch on it; dismissing right after is the only correct behavior, and
    // a silent no-op here is expected, not a bug.
    private func leaveReview() {
        requestReview()
        onDismiss()
    }

    // Claude  Date 08/13/2026
    // Fallback path for later: deep-links straight to the App Store's write-review
    // sheet, which — unlike requestReview() — is never suppressed. Can't be wired up
    // until Agil has an App Store ID, so it's parked here rather than half-built
    // behind a button that would silently do nothing.
    //
    // TODO: replace <APP_ID> with Agil's real App Store ID, then call this from a
    // "Rate on the App Store" row in Settings (App Review rejects a *button* that
    // fires requestReview(), but a link out like this one is the sanctioned form).
    private static let writeReviewURL =
        URL(string: "https://apps.apple.com/app/id<APP_ID>?action=write-review")

    private func openWriteReview() {
        guard let url = Self.writeReviewURL else { return }
        openURL(url)
    }
}

#Preview {
    ReviewRequestView(onDismiss: {})
        .environmentObject(ThemeManager())
}
