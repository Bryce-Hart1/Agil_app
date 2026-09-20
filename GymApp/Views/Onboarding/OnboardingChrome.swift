import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 08/13/2026
// Shared chrome for Agil's full-screen "ask" pages.
//
// All of this used to be private inside OnboardingView.swift, which meant any new
// screen that wanted the onboarding look — the drifting aura, the accent-circle
// header, the gradient capsule CTA — had to copy it. It's now one source of truth
// shared by OnboardingView, ReviewRequestView and NotificationRequestView, so a
// tweak to the CTA (or a fix to the truncation bug documented in StepHeader) lands
// everywhere at once.
//
// Nothing here owns state or talks to AppStore/ThemeManager: each piece takes the
// accent color it should paint with, so callers stay the ones reading `theme.current`.

// MARK: - Haptics

// Claude  Date 07/12/2026
// Light haptic tick for onboarding taps. UIKit-only, no-op elsewhere (previews
// on mac, etc.), and safe on iOS 16 — .sensoryFeedback would need iOS 17.
func tapHaptic() {
    #if canImport(UIKit)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    #endif
}

// MARK: - Background

// Claude  Date 07/12/2026
// Two big blurred accent circles behind the content. Their positions are keyed
// to the current step index, so advancing through the wizard gently drifts the
// glow around the screen — cheap "alive" feeling with no timers.
//
// Single-page asks (the review and notification screens) just pass a fixed index
// and get a still glow, which is the point: same visual family, no motion.
struct AuraBackground: View {
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

// MARK: - Header

// Claude  Date 07/12/2026 last changed: 08/13/2026 by: Claude
// Icon sits in a soft accent-tinted circle instead of floating bare, giving each
// page a visual anchor that matches the glow background. (Was OnboardingView's
// private stepHeader(icon:title:subtitle:); lifted out unchanged so the ask pages
// share it.)
struct StepHeader: View {
    let icon: String
    let title: String
    var subtitle: String?
    let accent: Color

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 84, height: 84)
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(accent)
            }
            // Claude  Date 07/27/2026
            // fixedSize(vertical:) is load-bearing, not polish: these sit in a VStack
            // with Spacers, and a Spacer outranks a Text for leftover height. Without
            // it the VStack hands Text its *minimum* height — one line — and the
            // headings truncate mid-word ("calibrate your streng…") even when there's
            // visible empty space above and below. Fixing the size makes the text
            // inflexible so the Spacers absorb the slack instead.
            Text(title)
                .font(.system(.title2, design: .rounded).bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Bullets

// Claude  Date 08/13/2026
// One reason/benefit line: accent SF Symbol in a fixed-width gutter so the text
// column lines up down the list. Extracted from OnboardingView's coinBullet, which
// now calls through to it — the ask pages use the same shape to list why they're
// asking.
struct AskBullet: View {
    let icon: String
    let text: String
    let accent: Color

    init(_ icon: String, _ text: String, accent: Color) {
        self.icon = icon
        self.text = text
        self.accent = accent
    }

    var body: some View {
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
}

// MARK: - Progress

// CLAUDE  Date 09/19/2026
// The wizard's progress capsules, counted rather than tied to one screen's Step enum, so any
// multi-step ask can use them. OnboardingView keeps its own copy for now — its version is
// wired to Step.allCases and isn't worth disturbing.
struct StepDots: View {
    let count: Int
    let index: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i <= index
                          ? AnyShapeStyle(LinearGradient(colors: [accent, accent.opacity(0.7)],
                                                         startPoint: .leading, endPoint: .trailing))
                          : AnyShapeStyle(Color.secondary.opacity(0.25)))
                    .frame(width: i == index ? 26 : 8, height: 8)
                    .shadow(color: i == index ? accent.opacity(0.5) : .clear, radius: 4)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
    }
}

// MARK: - Choice card

// CLAUDE  Date 09/19/2026
// A selectable option card: tinted icon tile, title, description, and a check circle, with
// an accent border when chosen. Was private inside OnboardingView; lifted here unchanged so
// the body-plan wizard asks its questions in the same shape. Takes accent and surface as
// parameters, like everything else in this file, so it still owns no state.
struct ChoiceCard<Icon: View>: View {
    let isSelected: Bool
    let title: String
    let description: String
    let accent: Color
    let surface: Color
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { action() }
            tapHaptic()
        } label: {
            HStack(spacing: 14) {
                // Claude  Date 07/12/2026
                // Icon in a tinted rounded tile so the selected card reads instantly.
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? accent.opacity(0.18) : Color.secondary.opacity(0.1))
                        .frame(width: 46, height: 46)
                    icon()
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
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
}

// CLAUDE  Date 09/19/2026
// The two icon flavors the cards actually use: an SF Symbol, or a template-tinted glyph from
// the asset catalog (Ghost Mode's ghost). AnyView keeps the convenience inits readable —
// these are two fixed shapes, not a hot path.
extension ChoiceCard where Icon == AnyView {
    init(isSelected: Bool, systemImage: String, title: String, description: String,
         accent: Color, surface: Color, action: @escaping () -> Void) {
        self.init(isSelected: isSelected, title: title, description: description,
                  accent: accent, surface: surface, action: action) {
            AnyView(Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(isSelected ? accent : .secondary))
        }
    }

    init(isSelected: Bool, assetImage: String, title: String, description: String,
         accent: Color, surface: Color, action: @escaping () -> Void) {
        self.init(isSelected: isSelected, title: title, description: description,
                  accent: accent, surface: surface, action: action) {
            AnyView(Image(assetImage)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .foregroundStyle(isSelected ? accent : .secondary))
        }
    }
}

// MARK: - Buttons

// Claude  Date 07/12/2026 last changed: 08/13/2026 by: Claude
// Primary CTA: gradient capsule with a trailing icon and an accent glow.
// .borderedProminent grays itself out when disabled; a plain-style button
// doesn't, so the disabled look is applied manually via opacity.
// (Generalized from OnboardingView's inline `controls` button — title, icon and
// disabled state are parameters now so every ask page gets the same button.)
struct PrimaryCTAButton: View {
    let title: String
    var systemImage: String?
    let accent: Color
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            tapHaptic()
            action()
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .fontWeight(.semibold)
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [accent, accent.opacity(0.75)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Capsule()
            )
            .foregroundStyle(.white)
            .shadow(color: accent.opacity(isDisabled ? 0 : 0.4), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
}

// Claude  Date 08/13/2026
// The quiet way out of an ask page ("Maybe later" / "Not now"). Deliberately plain
// text rather than a second capsule: on a screen that's asking for a favor, two
// equally-weighted buttons make the decline feel like the default. Secondary color
// and no chrome keeps the gradient CTA as the obvious answer while still leaving
// an escape that's easy to find and easy to hit.
struct SecondaryTextButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button {
            tapHaptic()
            action()
        } label: {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Presentation

// Claude  Date 08/13/2026
// Drop-in presenters so showing an ask page later is one modifier, matching how
// RootTabView presents OnboardingView (.fullScreenCover — these are "moment"
// screens, not sheets you swipe past). Each page's onDismiss just flips the
// binding, so callers never wire up dismissal themselves.
//
// Nothing calls these yet — deciding *when* to ask (after N workouts, on first
// rest timer, etc.) is separate work. These exist so that decision is a one-liner.
extension View {
    func reviewAsk(isPresented: Binding<Bool>) -> some View {
        fullScreenCover(isPresented: isPresented) {
            ReviewRequestView { isPresented.wrappedValue = false }
        }
    }

    func notificationAsk(isPresented: Binding<Bool>) -> some View {
        fullScreenCover(isPresented: isPresented) {
            NotificationRequestView { isPresented.wrappedValue = false }
        }
    }
}
