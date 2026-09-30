import SwiftUI

// CLAUDE  Date 09/26/2026
// Help & Demos: the sectioned index of guides, pushed from Profile and Settings (so no
// NavigationStack of its own). Paragraph guides push HelpArticleView; demo guides open a
// full-screen demo; demos not built yet sit greyed out as Coming soon.
struct HelpGuidesView: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var activeDemo: DemoLaunch?

    var body: some View {
        List {
            ForEach(HelpGuideCatalog.sections) { section in
                Section(section.title) {
                    ForEach(section.guides) { guide in
                        row(for: guide)
                    }
                }
            }
        }
        .navigationTitle("Help & Demos")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .fullScreenCover(item: $activeDemo) { launch in
            DemoLauncher(kind: launch.kind, title: launch.title)
                .environmentObject(theme)
        }
    }

    @ViewBuilder
    private func row(for guide: HelpGuide) -> some View {
        switch guide.content {
        case .article(let text):
            NavigationLink {
                HelpArticleView(guide: guide, text: text)
            } label: {
                rowLabel(for: guide)
            }
        case .demo(let kind):
            Button {
                activeDemo = DemoLaunch(kind: kind, title: guide.title)
            } label: {
                HStack {
                    rowLabel(for: guide)
                    Spacer(minLength: 8)
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(theme.current.accent)
                }
            }
            .accessibilityHint("Opens an interactive demo")
        case .comingSoon:
            HStack {
                rowLabel(for: guide)
                    .opacity(0.5)
                Spacer(minLength: 8)
                Text("Coming soon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Icon, title, and the one-line summary. The title is set to primary so a demo row's
    // Button doesn't tint it with the accent.
    private func rowLabel(for guide: HelpGuide) -> some View {
        HStack(spacing: 12) {
            guide.icon.image(size: 22)
                .foregroundStyle(theme.current.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(guide.title)
                    .foregroundStyle(.primary)
                Text(guide.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .supportingTextFont()
            }
        }
        .padding(.vertical, 2)
    }
}

// CLAUDE  Date 09/26/2026
// The demo a row asked to open. Carries the row's title so the demo header matches it.
private struct DemoLaunch: Identifiable {
    let kind: DemoKind
    let title: String
    var id: String { kind.id }
}

// CLAUDE  Date 09/26/2026
// One help paragraph: the guide's icon and title, then its text on a surface card.
// Paragraph breaks come from "\n\n" in the catalog copy.
struct HelpArticleView: View {
    @EnvironmentObject private var theme: ThemeManager
    let guide: HelpGuide
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    guide.icon.image(size: 30)
                        .foregroundStyle(theme.current.accent)
                    Text(guide.title)
                        .font(.title3.weight(.semibold))
                    Spacer(minLength: 0)
                }

                Text(text)
                    .font(.callout)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(16)
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationTitle(guide.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { HelpGuidesView() }
        .environmentObject(ThemeManager())
}
