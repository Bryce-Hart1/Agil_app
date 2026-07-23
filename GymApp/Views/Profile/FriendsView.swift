import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 07/14/2026
// The friends manager: share your code, add friends by code, act on incoming
// requests, see your friends, and manage blocks. Reached from the Profile hub
// (between Edit Profile Card and Achievements). Every action funnels through
// CardSyncService, which owns the identity + secret the backend's /friends calls
// require. Requests are sent BY short code; accept/decline/unfriend/unblock all key
// off the other user's UUID (SharedCard.userId) — the backend contract's one gotcha.
struct FriendsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var cardSync: CardSyncService

    @State private var requests: [SharedCard] = []
    @State private var friends: [SharedCard] = []
    @State private var blocked: [SharedCard] = []

    @State private var codeInput = ""
    @State private var isSending = false
    // The result of the last add attempt, shown inline under the field. `isError`
    // just tints it; the 429 rate-limit message is passed through verbatim.
    @State private var addStatus: (text: String, isError: Bool)?

    private var accent: Color { theme.current.accent }
    private var isFriendsMode: Bool { store.profile.dataMode == .friends }

    var body: some View {
        List {
            if isFriendsMode {
                myCodeSection
                addFriendSection
                if !requests.isEmpty { requestsSection }
                friendsSection
                if !blocked.isEmpty { blockedSection }
            } else {
                enableSection
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
        .task { await onAppear() }
        .refreshable { await reloadAll() }
    }

    // MARK: - Enable prompt (Ghost Mode)

    private var enableSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ghost Mode is on")
                    .font(.headline)
                Text("While Ghost Mode is on, everything stays on this device — you can't add friends, share, or see other people's cards. Turn on Friends mode to get a friend code, add friends, and see their profile cards. Only your profile card is ever shared — your workouts, nutrition, and everything else stay on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    store.profile.dataMode = .friends
                    cardSync.handleModeChange(to: .friends, store: store)
                    Task { await onAppear() }
                } label: {
                    Text("Turn on Friends mode")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - My code

    private var myCodeSection: some View {
        Section {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your friend code").font(.subheadline)
                    if let code = cardSync.myFriendCode {
                        Text(code)
                            .font(.title3.monospaced().weight(.bold))
                            .foregroundStyle(accent)
                            .textSelection(.enabled)
                    } else {
                        Text("Syncing…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let code = cardSync.myFriendCode {
                    Button {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = code
                        #endif
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                }
            }
        } footer: {
            Text("Share this code so friends can add you.")
        }
    }

    // MARK: - Add a friend

    private var addFriendSection: some View {
        Section {
            HStack {
                TextField("Enter a friend code", text: $codeInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .submitLabel(.send)
                    .onSubmit(sendRequest)
                    .disabled(isSending)
                if isSending {
                    ProgressView()
                } else {
                    Button("Add", action: sendRequest)
                        .buttonStyle(.borderless)
                        .disabled(codeInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if let status = addStatus {
                Text(status.text)
                    .font(.footnote)
                    .foregroundStyle(status.isError ? .red : .green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Add a friend")
        } footer: {
            Text("Codes aren't case-sensitive. If your friend already requested you, adding them back connects you instantly.")
        }
    }

    // MARK: - Incoming requests

    private var requestsSection: some View {
        Section {
            ForEach(requests, id: \.userId) { card in
                HStack(spacing: 12) {
                    FriendMiniRow(card: card)
                    Spacer(minLength: 8)
                    Button {
                        mutate { await cardSync.declineRequest(card.userId) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    Button {
                        mutate { await cardSync.acceptRequest(card.userId) }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.borderless)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        mutate { await cardSync.block(userId: card.userId) }
                    } label: { Label("Block", systemImage: "hand.raised.fill") }
                }
            }
        } header: {
            Text("Requests · \(requests.count)")
        }
    }

    // MARK: - Friends list

    private var friendsSection: some View {
        Section {
            if friends.isEmpty {
                Text("No friends yet. Share your code or add someone above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(friends, id: \.userId) { card in
                    NavigationLink {
                        FriendCardScreen(card: card)
                    } label: {
                        FriendMiniRow(card: card)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            mutate { await cardSync.unfriend(card.userId) }
                        } label: { Label("Remove", systemImage: "person.badge.minus") }
                        Button {
                            mutate { await cardSync.block(userId: card.userId) }
                        } label: { Label("Block", systemImage: "hand.raised.fill") }
                        .tint(.orange)
                    }
                }
            }
        } header: {
            Text("Friends · \(friends.count)")
        }
    }

    // MARK: - Blocked

    private var blockedSection: some View {
        Section {
            ForEach(blocked, id: \.userId) { card in
                HStack {
                    FriendMiniRow(card: card)
                    Spacer(minLength: 8)
                    Button("Unblock") {
                        mutate { await cardSync.unblock(card.userId) }
                    }
                    .buttonStyle(.borderless)
                    .tint(accent)
                }
            }
        } header: {
            Text("Blocked · \(blocked.count)")
        }
    }

    // MARK: - Actions

    private func onAppear() async {
        await cardSync.ensureFriendCode()
        await reloadAll()
    }

    private func reloadAll() async {
        guard isFriendsMode else { return }
        // Kick the three loads concurrently, then apply.
        async let r = cardSync.loadIncomingRequests()
        async let f = cardSync.loadFriends()
        async let b = cardSync.loadBlocked()
        let (loadedRequests, loadedFriends, loadedBlocked) = await (r, f, b)
        requests = loadedRequests
        friends = loadedFriends
        blocked = loadedBlocked
    }

    private func sendRequest() {
        let code = codeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty, !isSending else { return }
        isSending = true
        addStatus = nil
        Task {
            let result = await cardSync.sendFriendRequest(code: code)
            isSending = false
            switch result {
            case .sent:
                addStatus = ("Request sent.", false)
                codeInput = ""
            case .autoAccepted:
                addStatus = ("You're now friends!", false)
                codeInput = ""
            case .failed(let message):
                addStatus = (message, true)
            }
            await reloadAll()
        }
    }

    // Run a mutation, then refresh every list so the row moves to its new section.
    private func mutate(_ action: @escaping () async -> Bool) {
        Task {
            _ = await action()
            await reloadAll()
        }
    }
}

// Claude  Date 07/14/2026
// Compact identity row for a friend/requester/blocked card: their equipped rank
// crest (or initials) beside their name. Reuses the card's own colors.
private struct FriendMiniRow: View {
    let card: SharedCard

    var body: some View {
        HStack(spacing: 12) {
            AvatarBubble(name: card.displayName)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.displayName.isEmpty ? "Unknown" : card.displayName)
                    .font(.headline)
                if let rank = card.rank, card.showsRankOnCard {
                    Text(rank.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// Claude  Date 07/14/2026
// Initials bubble stand-in for a friend row (SharedCard doesn't carry an avatar).
private struct AvatarBubble: View {
    let name: String

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var body: some View {
        Circle()
            .fill(.secondary.opacity(0.2))
            .frame(width: 38, height: 38)
            .overlay(Text(initials).font(.subheadline.weight(.semibold)))
    }
}

// Claude  Date 07/14/2026
// Full-screen view of a friend's card, reusing the same ProfileShowcaseCard the
// owner sees (via FriendCardView).
private struct FriendCardScreen: View {
    let card: SharedCard
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        ScrollView {
            FriendCardView(card: card)
                .frame(height: 460)
                .padding(16)
        }
        .background(theme.current.background.ignoresSafeArea())
        .navigationTitle(card.displayName.isEmpty ? "Friend" : card.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
