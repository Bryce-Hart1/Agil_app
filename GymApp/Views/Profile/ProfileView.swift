import SwiftUI

// Claude  Date 06/12/2026 last changed: 07/12/2026 by: Claude
// The Profile tab: the show-off card fills (almost) the whole screen with its
// original edge margins — like a "fullscreen card" view — and you scroll down
// past it to reach Achievements / Edit Profile Card / Shop / Settings. The card
// shows only the user's featured (pinned) badges — the shelf of every other earned
// badge that used to sit below was removed 07/12/2026.
struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    // Claude  Date 07/28/2026
    // Profile is the one screen mounted in BOTH worlds, and its tab tag differs
    // between them (4 lifting, 3 nutrition) — the notch needs the right one to tell
    // whether it's the visible instance. Same persisted key RootTabView reads.
    @AppStorage("appMode") private var modeRaw = AppMode.lifting.rawValue
    @Environment(\.activeTabTag) private var activeTabTag
    private var stats: ProfileStats {
        ProfileStats(workouts: store.workouts, exercises: store.exercises)
    }

    var body: some View {
        NavigationStack {
            // Claude  Date 06/13/2026
            // GeometryReader gives us the viewport height so the card can be sized
            // to ~one full screen; the nav rows then sit just below the fold.
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 16) {
                        ProfileShowcaseCard(
                            name: store.profile.resolvedName,
                            style: CardStyle.style(for: store.profile.cardStyleID),
                            logoAsset: ThemeIcon.logoAsset(for: theme.current),
                            unlockedIDs: store.unlockedAchievementIDs,
                            pinnedIDs: store.profile.showcasedAchievementIDs,
                            memberSince: stats.memberSince,
                            rank: store.strategistRank,
                            rankProgress: store.strategistProgress,
                            ringFillMode: .rankProgress,
                            catalog: store.achievementCatalog,
                            showsBadgeNames: store.profile.showsBadgeNamesOnCard,
                            layout: store.profile.cardLayout   // CLAUDE 09/24/2026
                        )
                        .frame(height: max(380, geo.size.height - 32))
                        // CLAUDE  Date 09/18/2026
                        // Freeze the card's animation while another tab is showing. A
                        // TabView keeps visited tabs alive, so without this the card
                        // keeps repainting behind whatever screen you switched to — the
                        // same reason ModeNotch pauses its rim on `tab != activeTabTag`.
                        .cardMotionActive(profileTab == activeTabTag)
                        // CLAUDE  Date 09/05/2026
                        // The card here is the front only. Tapping it opens the
                        // fullscreen showcase (CardInspectOverlay), and inspect mode in
                        // there is where it turns over — a card in a scrolling list is
                        // the wrong place for a gesture that fights the scroll.
                        .contentShape(RoundedRectangle(cornerRadius: 28))
                        .onTapGesture { store.showsCardInspect = true }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Opens your card fullscreen")
                        // Claude  Date 07/14/2026
                        // Spotlight-tour anchor: the one in-content target, reported
                        // via the real preference plumbing (chrome targets use
                        // synthesized fallbacks instead — see TourSupport).
                        .tourTarget(.profileCard)

                        rankBanner

                        navRows
                    }
                    .padding(16)
                }
                .background(theme.current.background.ignoresSafeArea())
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            // Claude  Date 07/13/2026
            // Centered mode-switcher pill in the nav bar (shared by all root tabs).
            // As the principal item it takes the inline title's spot — the tab
            // label already says Profile, so no title text is lost that matters.
            .modeNotchToolbar(tab: profileTab)
            // Claude  Date 07/28/2026
            // The two destinations worth reaching without scrolling past the card:
            // Achievements on the left (carrying the unopened count that's the whole
            // reason you came here), Settings on the right. Achievements moved up
            // here entirely — its row is gone from navRows below — while Settings is
            // a shortcut and keeps its row, since Settings is where people look by
            // habit. One icon per side also keeps the ModeNotch pill on the midline;
            // see modeNotchToolbar's note on how UIKit centers a principal item.
            //
            // Both report their frames to the tour through the global registry, not
            // .tourTarget: toolbar items live in a UIKit navigation bar and a SwiftUI
            // preference can't escape it. Gated on the tab because ProfileView is
            // mounted in BOTH worlds, so two instances can be alive at once.
            //
            // Claude  Date 08/23/2026
            // (08/23) A coin-balance chip lived on the trailing side here for one build
            // and is gone again. Two items a side is one item a side too many: the
            // ModeNotch pill gets whatever width the bar BUTTONS leave, so the extra
            // chip (plus the navBarBalancer needed to keep the pill centred) squeezed
            // it until "Lifting" truncated to "…" and the calorie stat to "0/…". The
            // balance now rides inside the pill itself, where it costs no bar width and
            // shows on every root screen instead of just this one — see ModeNotch.
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        AchievementBookView()
                    } label: {
                        toolbarIcon("medal")
                            .overlay(alignment: .topTrailing) { unopenedBadge }
                    }
                    .accessibilityLabel("Achievements")
                    .tourTargetGlobal(.profileAchievements, active: tourTargetsActive)
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 19))
                    }
                    .accessibilityLabel("Settings")
                    .tourTargetGlobal(.profileSettings, active: tourTargetsActive)
                }
            }
        }
    }

    // Claude  Date 07/28/2026 last changed: 09/20/2026 by: CLAUDE
    // This screen's tab tag. One value (4) for both worlds — Profile is mounted once and
    // shared, so the tag doesn't move when the world flips.
    private var profileTab: Int {
        AgilTabItem.profileTag(for: AppMode(rawValue: modeRaw) ?? .lifting)
    }

    // Only the visible world's ProfileView should publish toolbar frames to the tour.
    private var tourTargetsActive: Bool {
        store.tourActive && profileTab == activeTabTag
    }

    // Claude  Date 07/28/2026
    // Custom-asset toolbar glyph. .renderingMode(.template) is required — medal.svg
    // declares no template-rendering-intent in its Contents.json, so without it the
    // artwork draws flat instead of taking the bar's tint.
    private func toolbarIcon(_ asset: String) -> some View {
        Image(asset)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
    }

    // Claude  Date 07/28/2026
    // The unopened-badge count, riding the medal icon. Drawn as an overlay so it
    // doesn't widen the toolbar item — the pill's centering depends on the leading
    // and trailing items staying the same width. Same count the Profile tab badge
    // shows; zero draws nothing.
    @ViewBuilder
    private var unopenedBadge: some View {
        let count = store.unopenedAchievementCount
        if count > 0 {
            Text(count > 9 ? "9+" : "\(count)")
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .frame(minWidth: 15, minHeight: 15)
                .background(Color.red, in: Capsule())
                .offset(x: 8, y: -6)
                .accessibilityLabel("\(count) new")
        }
    }

    // Claude  Date 06/15/2026
    // The Strategist rank banner, tappable into the full ladder. Sits between the
    // card and the nav hub.
    private var rankBanner: some View {
        NavigationLink {
            StrategistRankView()
        } label: {
            StrategistRankBanner(
                rank: store.strategistRank,
                progress: store.strategistProgress,
                pointsToNext: StrategistScoring.pointsToNext(forScore: store.strategistScore)
            )
            .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // Claude  Date 06/12/2026 last changed: 06/13/2026 by: Claude
    // The hub revealed by scrolling below the card.
    private var navRows: some View {
        VStack(spacing: 0) {
            // Claude  Date 07/13/2026
            // Icon: custom template asset "wrench" (was slider.horizontal.3).
            profileNavRow("Edit Profile Card", image: "wrench") {
                EditProfileCardView()
            }
            Divider().padding(.leading, 16)
            // Claude  Date 07/14/2026 last changed: 07/23/2026 by: Claude
            // Friends manager (share code, add/accept, friends list, blocks). Sits
            // between Edit Profile Card and Achievements. Disabled (greyed, no push)
            // while in Ghost Mode, since none of the social features work there.
            profileNavRow(
                "Friends",
                systemImage: "person.2",
                disabledMessage: store.profile.dataMode == .ghost ? "Disabled in ghost mode" : nil
            ) {
                FriendsView()
            }
            Divider().padding(.leading, 16)
            // Claude  Date 07/25/2026
            // Browse the shipped workout templates and install one as a preset. Lives
            // here (rather than only on the Presets tab) so it's findable as a "things
            // I can add to my account" destination, alongside the Shop.
            profileNavRow("Premade Workouts", image: "folder-plus") {
                PremadeWorkoutsView()
            }
            Divider().padding(.leading, 16)
            // Claude  Date 07/24/2026 last changed: 07/28/2026 by: Claude
            // (07/28) The Achievement Book row lived here, carrying the unopened
            // count. It's now the medal button in the nav bar's top-left instead —
            // one place, not two, and reachable without scrolling past the card,
            // which is the point when an unopened badge is what brought you here.
            // Claude  Date 08/23/2026
            // The balance rides the row itself, so "how many coins do I have" is
            // answered on the way to the Shop rather than only once you're inside it.
            profileNavRow("Shop", systemImage: "bag", accessory: {
                Label("\(theme.balance.formatted())", systemImage: "circle.hexagongrid.fill")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(theme.current.accent)
            }) {
                ShopView()
            }
            Divider().padding(.leading, 16)
            // Claude  Date 08/23/2026
            // Help & Demos: written walkthroughs of the flows a new user has to be
            // shown once (build a preset, log a custom food, change the theme…),
            // each step carrying the real on-screen icon. Sits next to Settings
            // because that's where the guided tour already lives — this is the
            // reference you read at your own pace, the tour is the one that walks
            // you around. Copy is still being written; see HelpGuides.swift.
            profileNavRow("Help & Demos", systemImage: "questionmark.circle") {
                HelpGuidesView()
            }
            Divider().padding(.leading, 16)
            profileNavRow("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    // Claude  Date 06/12/2026 last changed: 07/13/2026 by: Claude
    // A tappable row that pushes a destination, styled as a settings row. The
    // SF-Symbol and custom-asset variants both funnel into the shared core below.
    private func profileNavRow<Accessory: View, Destination: View>(
        _ title: String,
        systemImage: String,
        disabledMessage: String? = nil,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        profileNavRow(title, disabledMessage: disabledMessage,
                      icon: { Image(systemName: systemImage) },
                      accessory: accessory, destination: destination)
    }

    // Claude  Date 07/13/2026
    // Variant taking a custom asset-catalog icon (template image) instead of an SF
    // Symbol — used by the Edit Profile Card row (wrench). Sized to match the
    // symbol rows' icon footprint.
    private func profileNavRow<Accessory: View, Destination: View>(
        _ title: String,
        image: String,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        profileNavRow(
            title,
            icon: { Image(image).resizable().scaledToFit().frame(width: 20, height: 20) },
            accessory: accessory,
            destination: destination
        )
    }

    // Claude  Date 07/13/2026 last changed: 07/28/2026 by: Claude
    // Shared row body — accepts any icon view so both the SF-Symbol and custom-asset
    // variants above can reuse it. When `disabledMessage` is set the row is inert:
    // no NavigationLink push, the title/icon are greyed (.plain buttons don't auto-
    // grey, so opacity is applied manually), and the message replaces the chevron.
    // (07/28) The `badgeCount` parameter came out with the Achievements row — it was
    // that row's alone, and nothing else here has ever wanted a count. The unopened
    // count now rides the nav bar's medal button instead; see unopenedBadge.
    //
    // Claude  Date 08/23/2026
    // (08/23) `accessory` is a trailing slot between the title and the chevron, added so
    // the Shop row can show the coin balance inline. Generic and @ViewBuilder rather
    // than a `detail: String?` because what goes there is a coin Label, not text.
    //
    // It sits BEFORE `destination` on purpose, and callers pass it as a labelled
    // argument rather than a second trailing closure. Swift matches an unlabelled
    // trailing closure by scanning the parameter list BACKWARDS for the first
    // function-typed parameter, so parking a defaulted closure last would silently
    // re-point every existing `profileNavRow("Settings", …) { SettingsView() }` call at
    // `accessory` and leave `destination` unsatisfied. Destination stays last; the one
    // row that wants an accessory spells it out.
    @ViewBuilder
    private func profileNavRow<Icon: View, Accessory: View, Destination: View>(
        _ title: String,
        disabledMessage: String? = nil,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        if let disabledMessage {
            HStack {
                Label { Text(title) } icon: { icon() }
                    .opacity(0.5)
                Spacer()
                Text(disabledMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .foregroundStyle(.primary)
        } else {
            NavigationLink(destination: destination()) {
                HStack {
                    Label { Text(title) } icon: { icon() }
                    Spacer()
                    accessory()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Showcase card

// Claude  Date 07/22/2026
// The set of "edit this element" callbacks handed to ProfileShowcaseCard to turn it into
// an interactive editor (see EditProfileCardView). Each closure just signals which element
// was tapped; the owner raises the matching sheet. Defaulted so a caller can wire up only
// what it needs.
//
// Claude 08/03/2026: `rank` is gone. It routed to the avatar's editor, so the card carried
// TWO pencils — one on the ring, one on the rank title right beneath it — opening the same
// sheet. Nothing equips a rank from the card any more, so the title is plain text.
//
// Claude 08/07/2026: `avatar` is gone too, with the face feature. The picture is the rank
// emblem now — earned, not configured — so there is nothing to edit there and the ring
// carries no pencil.
//
// CLAUDE 09/24/2026: `header` and `avatar` are back as the layout became editable — the
// AGIL mark picks logo/wordmark, and the picture opens the Avatar sheet (picture + ring/bar).
struct ProfileCardEditActions {
    var background: () -> Void = {}
    var badges: () -> Void = {}
    var header: () -> Void = {}
    var avatar: () -> Void = {}
}

// Claude  Date 06/12/2026 last changed: 07/12/2026 by: Claude
// The shareable card: a CardStyle background (color or image) drawn by
// CardBackgroundView and a row of featured (pinned) achievement badges. Rounded +
// shadowed so it reads as a card with the screen showing at its edges. (The shelf
// of every other earned badge that used to sit below the featured row was removed.)
struct ProfileShowcaseCard: View {
    let name: String
    let style: CardStyle
    // CLAUDE  Date 09/03/2026
    // The equipped theme's logo asset (see ThemeIcon). Passed in, not read from
    // ThemeManager, because this card is rendered in three places — including a friend's
    // card — and it has no environment object of its own.
    var logoAsset: String = ThemeIcon.classicLogoAsset
    let unlockedIDs: Set<String>
    let pinnedIDs: [String]
    let memberSince: Date?
    // Claude  Date 06/15/2026
    // The Strategist rank equipped onto the card (nil = not equipped); progress
    // fills its ring toward the next rank.
    var rank: StrategistRank? = nil
    var rankProgress: Double = 1
    // Claude  Date 07/09/2026
    // How the rank ring reads. Your OWN card uses .rankProgress (the ring fills toward your
    // next rank — a personal "how close am I" meter). Friends viewing your card keep the
    // default .rankSegments (your rank crest), so your progress-to-next stays private.
    var ringFillMode: RankRingFill = .rankSegments
    // Claude  Date 07/14/2026
    // Which achievement catalog resolves the pinned badge ids. Your OWN card passes the
    // gender-calibrated store.achievementCatalog; friend cards keep the baseline default —
    // a friend's identity is never shared (SharedCard privacy contract), and ids/tiers are
    // identical across variants so the badges themselves render the same.
    var catalog: [Achievement] = Achievement.all
    // Claude  Date 09/14/2026
    // Whether each featured badge prints its title underneath. Off leaves just the icons —
    // set from the owner's Edit Profile Card switch, or from SharedCard for a friend's card.
    var showsBadgeNames: Bool = true
    // CLAUDE  Date 09/24/2026
    // The owner's header, picture, progress style and text colour. Default = the card as it
    // looked before these were choosable, which is also what an older friend's card gets.
    var layout: CardLayout = .default

    private var ink: Color { layout.ink.color }

    // Claude  Date 07/22/2026
    // Opt-in edit affordances. nil (the default, used by the Profile tab, Friends and
    // FriendCard) renders a plain, read-only card exactly as before. When set — only by
    // EditProfileCardView — each editable element becomes tappable and grows a small pencil
    // chip, turning the live card into its own editor. The closures just report which
    // element was tapped; the owning view decides what sheet to raise.
    var edit: ProfileCardEditActions? = nil

    // Claude  Date 06/13/2026 last changed: 07/12/2026 by: Claude
    // Just the user's pinned badges (in their chosen order, still-unlocked, capped at
    // maxFeatured). The empty slots that AchievementShowcase.featured pads with are
    // dropped here, so the row shows only real badges — no "Locked" placeholders.
    private var featuredBadges: [Achievement] {
        AchievementShowcase.featured(unlockedIDs: unlockedIDs, pinnedIDs: pinnedIDs,
                                     catalog: catalog)
            .compactMap { $0 }
    }

    // Claude  Date 07/01/2026 last changed: 07/12/2026 by: Claude
    // Whether any badge is pinned. When none are, the card omits the row entirely
    // (a fully blank card).
    private var hasFeatured: Bool { !featuredBadges.isEmpty }

    // Claude  Date 06/12/2026 last changed: 09/05/2026 by: CLAUDE
    // (09/05) The padding/background/hairline/shadow moved to CardFaceChrome, and
    // shadowColor onto CardStyle, so the new back face is the SAME shell rather than a
    // copy of it that can drift. No visual change.
    // (09/24) The ink is published to the environment so shared pieces (header, palette
    // chip, ring track, initials) pick up the chosen text colour too.
    var body: some View {
        content
            .environment(\.cardInk, layout.ink)
            .cardFaceChrome(style: style)
    }

    // Claude  Date 07/09/2026 last changed: 09/24/2026 by: CLAUDE
    // The picture at the top of the card: the rank's chess piece inside the RankRing, or
    // initials when no rank is equipped (there's no emblem to draw without one).
    //
    // (08/07) This used to be a three-way face — customizable character, stock avatar, or
    // initials — and on your own card a two-sided coin that turned over to show the
    // character. All of that is gone; what's left is what the coin's HEADS side always was.
    //
    // (09/24) Choosable again via CardLayout: rank piece, an AGIL icon, or none, framed by
    // the ring or shown bare (with the bar under it, or nothing). The ring stays earned.
    private let ringSize: CGFloat = 120
    private let bareDiameter: CGFloat = 92

    @ViewBuilder private var cardAvatar: some View {
        if let rank {
            if layout.resolvedProgress == .ring {
                RankRing(rank: rank, progress: rankProgress, size: ringSize,
                         fillMode: ringFillMode) {
                    CardAvatarCore(avatar: layout.avatar, rank: rank,
                                   diameter: RingGeometry.coreDiameter(for: ringSize))
                }
            } else {
                CardAvatarCore(avatar: layout.avatar, rank: rank, diameter: bareDiameter)
            }
        } else if case .icon = layout.avatar {
            CardAvatarCore(avatar: layout.avatar, rank: nil, diameter: bareDiameter)
        } else {
            RankRingInitials(name: name, size: 92)
        }
    }

    // CLAUDE  Date 09/24/2026
    // The rank bar, drawn under the picture — or under the rank title when there is no
    // picture. Needs a rank to measure, so a friend's card with rank hidden has none.
    @ViewBuilder private var progressBar: some View {
        if let rank, layout.resolvedProgress == .bar {
            RankProgressBar(rank: rank, progress: rankProgress, fillMode: ringFillMode)
        }
    }

    // CLAUDE  Date 09/24/2026
    // The picture block: avatar with its bar, tappable as one unit in edit mode. With no
    // picture chosen, edit mode shows a small "Picture" slot instead — otherwise there'd be
    // nothing left on the card to tap to bring one back. Read-only cards show nothing there.
    @ViewBuilder private var avatarSection: some View {
        if layout.avatar == .none {
            if let edit {
                Button(action: edit.avatar) { pictureSlot }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add a picture")
            }
        } else {
            editable(edit?.avatar, chip: .topTrailing) {
                VStack(spacing: 14) {
                    cardAvatar
                    progressBar
                }
            }
        }
    }

    private var pictureSlot: some View {
        VStack(spacing: 4) {
            Image("selection-plus")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 40, height: 40)
            Text("Picture")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(ink.opacity(0.9))
    }

    private var content: some View {
        VStack(spacing: 16) {
            header

            avatarSection

            // Claude  Date 07/22/2026
            // The name is intentionally NOT editable from the card — renaming carries
            // backend/identity weight, so it lives behind Settings › Change Name instead.
            Text(name)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            // Claude  Date 06/15/2026 last changed: 08/03/2026 by: Claude
            // The equipped rank's title (when turned on in Edit Profile Card). The
            // emblem that used to sit here is gone — the rank ring around the avatar now
            // carries the rank visually, so this is just the label. (StrategistEmblem
            // still lives on the rank banner and the ladder.)
            // (08/03) No longer editable — it opened the avatar's editor, which put a
            // second pencil on the card doing the same job as the ring's. See
            // ProfileCardEditActions.
            if let rank {
                Text(rank.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink)
            }

            // CLAUDE  Date 09/24/2026 — with no picture the bar sits under the title
            // instead; in edit mode it opens the same Avatar sheet as the picture would.
            // Padded so the pencil chip clears the last segment rather than covering it.
            if layout.avatar == .none, rank != nil, layout.resolvedProgress == .bar {
                editable(edit?.avatar, chip: .trailing) { progressBar.padding(.horizontal, 24) }
            }

            // Claude  Date 07/22/2026
            // Edit mode gets the interactive badge editor (tappable badges + an add slot
            // or a "change or delete" prompt). Read-only cards keep the original behaviour:
            // the row is shown only when something is pinned, and omitted otherwise.
            if let edit {
                badgeEditor(edit)
            } else if hasFeatured {
                featuredRow
            }

            Spacer(minLength: 12)

            if let memberSince {
                Text("Member since \(memberSince.formatted(.dateTime.month().year()))")
                    .font(.caption2)
                    .foregroundStyle(ink.opacity(0.75))
            }
        }
    }

    // Claude  Date 07/22/2026
    // Wraps an editable element: with an action it becomes a plain button carrying a small
    // pencil chip (so it reads as tappable); without one it's just the content, unchanged.
    @ViewBuilder
    private func editable<Content: View>(_ action: (() -> Void)?,
                                         chip alignment: Alignment,
                                         @ViewBuilder content: () -> Content) -> some View {
        if let action {
            Button(action: action) { content() }
                .buttonStyle(.plain)
                .overlay(alignment: alignment) { CardEditChip().padding(-4) }
        } else {
            content()
        }
    }

    // Claude  Date 07/22/2026
    // The badges section in edit mode. Each featured badge stays tappable (opens the
    // picker to reorder/remove). While there's still room, a badge-sized "selection-plus"
    // slot sits to the RIGHT of the badges, as if it were the next badge, to add more.
    // Once the row is full (maxFeatured), that slot is dropped — there's nowhere to put a
    // new badge — and a "minus-square + Change or delete badges" prompt sits underneath
    // instead, routing to the same picker.
    @ViewBuilder
    private func badgeEditor(_ edit: ProfileCardEditActions) -> some View {
        let isFull = featuredBadges.count >= AchievementShowcase.maxFeatured
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(featuredBadges) { achievement in
                    Button(action: edit.badges) { badgeCell(achievement) }
                        .buttonStyle(.plain)
                }
                if !isFull {
                    Button(action: edit.badges) { addBadgeSlot }
                        .buttonStyle(.plain)
                }
            }

            if isFull {
                Button(action: edit.badges) {
                    VStack(spacing: 4) {
                        Image("minus-square")
                            .renderingMode(.template)
                            .resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                        Text("Change or delete badges")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(ink.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // A badge-sized add slot: the selection-plus glyph where a badge would be, so it reads
    // as the next empty badge position.
    private var addBadgeSlot: some View {
        VStack(spacing: 6) {
            Image("selection-plus")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 58, height: 58)
                .foregroundStyle(ink.opacity(0.9))
            Text("Add")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ink.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
    }

    // Claude  Date 07/22/2026 last changed: 09/05/2026 by: CLAUDE
    // In edit mode the background has no single element to tap, so the header carries a
    // palette chip for it (a whole-card tap would fight the inner elements' gestures).
    // Hidden entirely on read-only cards. (09/05: header markup shared with the back.)
    // (09/24) Honours the chosen header mode; in edit mode the mark itself opens its sheet.
    private var header: some View {
        CardBrandHeader(logoAsset: logoAsset, mode: layout.header, onEdit: edit?.header) {
            if let edit { CardPaletteChip(action: edit.background) }
        }
    }

    // Claude  Date 06/13/2026 last changed: 07/12/2026 by: Claude
    // The featured badges row across the top (transparent), badge over title. Shows
    // only the user's pinned badges — empty slots no longer render as "Locked"
    // placeholders. Each badge takes an equal share of the width so 1–4 badges stay
    // evenly spread.
    private var featuredRow: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(featuredBadges) { badgeCell($0) }
        }
    }

    // Claude  Date 07/22/2026 — one badge + its title, shared by featuredRow and the editor.
    private func badgeCell(_ achievement: Achievement) -> some View {
        VStack(spacing: 6) {
            BadgeView(icon: achievement.icon, tier: achievement.tier, unlocked: true, size: 58, glimmer: true, ringed: false)
            // Claude  Date 09/14/2026 — hidden when the "Badge names" switch is off.
            if showsBadgeNames {
                Text(achievement.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
    }

}

#Preview {
    let store = AppStore()
    store.addWorkout(Workout(exercises: [
        LoggedExercise(exerciseId: store.exercises[0].id,
                       sets: [ExerciseSet(reps: 8, weight: 185), ExerciseSet(reps: 5, weight: 225)])
    ]))
    return ProfileView()
        .environmentObject(store)
        .environmentObject(ThemeManager())
}
