import SwiftUI

// CLAUDE  Date 09/26/2026
// Look-alike pieces of the app's chrome for demo shells. Each one copies a real control's
// look but only calls back into the demo, so nothing here can change the real app.

// CLAUDE  Date 09/26/2026
// A static copy of the ModeNotch pill: side icon, the other side's stat, and the coin
// balance (read only). The real ModeNotch can't be reused: it writes "appMode" and would
// flip the real app. Drawn with its settled lit rim, no tracing light.
struct DemoNotch: View {
    let mode: AppMode
    let stat: String
    let onTap: () -> Void

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    modeIcon
                    Text(stat)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "circle.hexagongrid.fill")
                    Text(Coins.compact(theme.balance))
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.current.accent)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(theme.current.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(theme.current.accent.opacity(0.25), lineWidth: 1))
            .overlay(AccentRim(shape: Capsule(), accent: theme.current.accent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.label) mode. \(stat).")
    }

    @ViewBuilder private var modeIcon: some View {
        Group {
            if mode.iconIsCustomAsset {
                Image(mode.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: mode.icon)
                    .font(.subheadline)
            }
        }
        .foregroundStyle(theme.current.accent)
    }
}

// CLAUDE  Date 09/26/2026
// A sheet drawn INSIDE the demo frame. A real .sheet covers the whole window, which would
// hide the guide panel, so this slides a rounded card up over the shell instead.
struct DemoSheet<Content: View>: View {
    let isPresented: Bool
    /// Gap above the card. A sheet stacked on another uses a bigger one so the first peeks out.
    var topInset: CGFloat = 28
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            if isPresented {
                Color.black.opacity(0.35)
                    .transition(.opacity)
                content()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    // Push the bottom corners past the frame's clip so only the top rounds.
                    .padding(.bottom, -16)
                    .padding(.top, topInset)
                    .transition(.move(edge: .bottom))
            }
        }
    }
}

// CLAUDE  Date 09/26/2026
// Stand-in for a pushed screen's system back button. Demos hide the real one (a system
// pop can't be refused), so this draws the same chevron and title and just calls back.
struct DemoBackButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
            }
        }
        .accessibilityLabel("Back")
    }
}

// CLAUDE  Date 09/26/2026
// The Workouts tab's custom toolbar glyph, same treatment as WorkoutsListView.toolbarIcon:
// the PNGs have white backgrounds, so invert + luminance-to-alpha turns them into a mask.
struct DemoToolbarIcon: View {
    let asset: String

    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        theme.current.accent
            .frame(width: 22, height: 22)
            .mask {
                Image(asset)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .colorInvert()
                    .luminanceToAlpha()
                    .scaleEffect(1.3)
            }
    }
}

// CLAUDE  Date 09/27/2026
// A form field drawn as text: the placeholder in placeholder grey until the demo fills in
// `value`. Demos never raise the keyboard, so this stands in for every TextField.
struct DemoFieldText: View {
    let value: String?
    let placeholder: String

    var body: some View {
        Text(value ?? placeholder)
            .foregroundStyle(value == nil ? Color(uiColor: .placeholderText) : Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}

// CLAUDE  Date 09/27/2026
// A look-alike search bar for demo lists. Display only: tapping it would mean typing.
struct DemoSearchField: View {
    let prompt: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
            Text(prompt)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
    }
}

// CLAUDE  Date 09/27/2026
// The real AgilTabBar for a demo world, with a ring drawn over one cell when a step says
// "tap this tab". The bar splits its width evenly, so the ring's spot is just math.
struct DemoTabBar: View {
    let mode: AppMode
    let selectedTag: Int
    var highlightedTag: Int? = nil
    var nudges: Int = 0
    let onSelect: (Int) -> Void

    var body: some View {
        let items = AgilTabItem.items(for: mode)
        AgilTabBar(items: items, selection: Binding(get: { selectedTag }, set: onSelect))
            .overlay {
                GeometryReader { geo in
                    if let tag = highlightedTag,
                       let index = items.firstIndex(where: { $0.tag == tag }) {
                        let width = geo.size.width / CGFloat(items.count)
                        Color.clear
                            .frame(width: width - 12, height: geo.size.height - 10)
                            .demoHighlight(true, nudges: nudges, inset: 0)
                            .position(x: width * (CGFloat(index) + 0.5), y: geo.size.height / 2 + 2)
                    }
                }
                .allowsHitTesting(false)
            }
    }
}

// CLAUDE  Date 09/27/2026
// A toolbar button drawn with one of the app's template assets (the barcode, say), sized
// like the real ones.
struct DemoAssetButton: View {
    let asset: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
        }
    }
}

// CLAUDE  Date 09/27/2026
// A lift's note row as ExerciseNoteFields draws it (tier bar, icon, placeholder), display
// only: the real one writes straight to the exercise library.
struct DemoNoteRow: View {
    let icon: String
    let tint: Color
    let placeholder: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(tint)
                .frame(width: 3)
                .frame(maxHeight: .infinity)
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(tint)
                .frame(width: 14)
                .padding(.top, 3)
            DemoFieldText(value: nil, placeholder: placeholder)
                .font(.subheadline)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
