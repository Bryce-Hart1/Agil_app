import SwiftUI

// Claude  Date 08/23/2026
// Help & Demos: the index of walkthroughs, pushed from the Profile tab's nav hub.
// Pushed (not a root), so it hosts no NavigationStack of its own — same contract
// SettingsView has.
//
// The guides themselves live in HelpGuides.swift as data. This file only renders
// them, so writing the missing copy never means editing layout code.
struct HelpGuidesView: View {
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        List {
            ForEach(HelpGuideCatalog.sections) { section in
                Section(section.title) {
                    ForEach(section.guides) { guide in
                        NavigationLink {
                            HelpGuideDetailView(guide: guide)
                        } label: {
                            row(for: guide)
                        }
                    }
                }
            }
        }
        .navigationTitle("Help & Demos")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
    }

    // Claude  Date 08/23/2026
    // A guide's row: its icon, title, and either the summary or — while the copy is
    // unwritten — a count of what's still TODO. The count is the honest thing to show
    // in an alpha: an empty subtitle would read as a finished guide with nothing to say.
    private func row(for guide: HelpGuide) -> some View {
        HStack(spacing: 12) {
            guide.icon.image(size: 22)
                .foregroundStyle(theme.current.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(guide.title)
                if let summary = guide.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    TodoChip(label: "\(guide.todoCount) to write")
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// Claude  Date 08/23/2026
// One guide: the demo up top, then the numbered steps. Unwritten copy shows as a
// TODO placeholder rather than nothing at all — see the note in HelpGuides.swift.
struct HelpGuideDetailView: View {
    @EnvironmentObject private var theme: ThemeManager
    let guide: HelpGuide

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                demo
                ForEach(Array(guide.steps.enumerated()), id: \.element.id) { index, step in
                    stepCard(step, number: index + 1)
                }
            }
            .padding(16)
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationTitle(guide.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 12) {
            guide.icon.image(size: 30)
                .foregroundStyle(theme.current.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(guide.title)
                    .font(.title3.weight(.semibold))
                if let summary = guide.summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    TodoChip(label: "Summary")
                }
            }
            Spacer(minLength: 0)
        }
    }

    // Claude  Date 08/23/2026
    // The demo slot. Once `demoAsset` names a screenshot or animation in the asset
    // catalog it draws that; until then it's a dashed frame at the same 16:10 the
    // real thing will occupy, so dropping the art in doesn't reflow the page.
    @ViewBuilder
    private var demo: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let demoAsset = guide.demoAsset {
                Image(demoAsset)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .aspectRatio(16.0 / 10.0, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "play.rectangle")
                                .font(.system(size: 26))
                            Text("Demo")
                                .font(.subheadline.weight(.semibold))
                            TodoChip(label: "Add a demo")
                        }
                        .foregroundStyle(.secondary)
                    }
            }
            if let caption = guide.demoCaption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // Claude  Date 08/23/2026
    // A step: its number, the icon to hunt for on screen, what to tap, and the
    // explanation. The icon is drawn the way the real screen draws it — that's the
    // whole point of showing it here.
    private func stepCard(_ step: HelpGuideStep, number: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.footnote.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(theme.current.accent, in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    step.icon.image(size: 20)
                        .foregroundStyle(theme.current.accent)
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                }
                if let body = step.body {
                    Text(body)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    TodoChip(label: "Write this step")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

// Claude  Date 08/23/2026
// The marker for copy that hasn't been written yet. One shared look so unfinished
// guides are unmistakable at a glance — and so they're trivial to find and delete
// once the writing is done.
struct TodoChip: View {
    let label: String

    var body: some View {
        Text("TODO — \(label)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15), in: Capsule())
    }
}

#Preview {
    NavigationStack { HelpGuidesView() }
        .environmentObject(ThemeManager())
}
