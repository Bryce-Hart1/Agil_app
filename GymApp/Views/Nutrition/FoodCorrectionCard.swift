import SwiftUI
import UIKit

// Claude  Date 08/06/2026 Peer reviewed 08/06/2026 Bryce Hart
// The last card on the food detail page: what the record doesn't say, and the way to
// do something about it. Two jobs in one place on purpose —
//
//  • Since empty nutrients stopped rendering as rows of "—", the page no longer shows
//    the SIZE of what's missing. Stating it once here ("18 of 32 nutrients aren't
//    reported") is honest without being 18 lines of nothing.
//  • That admission is exactly where the offer to fix it belongs. One tap opens a short
//    reason sheet; sending puts the food (back) into the review queue.
//
// Self-contained by design: it owns the card credentials and the network call so
// FoodDetailView keeps its store-free contract and both call sites (the Foods tab
// sheet, the diary picker's push) get the behavior without wiring anything.
struct FoodCorrectionCard: View {
    @EnvironmentObject private var theme: ThemeManager

    let food: FoodDetail

    var body: some View {
        // A hand-entered food lives only on this device — there's no shared record to
        // correct, and the user can just edit it. Nothing to offer here.
        if food.source != .userSubmitted {
            content
        }
    }

    private var content: some View {
        FoodCorrectionCardBody(food: food)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(theme.current.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

// Claude  Date 08/06/2026
// The card's interior, split out so the state (and the CardSyncService dependency) is
// only created for foods that can actually be reported.
private struct FoodCorrectionCardBody: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var cardSync: CardSyncService

    let food: FoodDetail

    @State private var showingReasons = false
    @State private var sent = false

    // Claude  Date 08/06/2026
    // Last quota the server reported, and the UTC day it applied to, so the card can
    // say "2 left today" instead of leaving the limit a surprise. Display only — the
    // server is the authority, and a stale count never blocks a send (only its 429
    // does). Stored per-device rather than per-food: the quota is per user.
    @AppStorage("foodCorrectionsRemaining") private var remainingToday: Int = -1
    @AppStorage("foodCorrectionsDay") private var quotaDay: String = ""

    private var canReport: Bool { cardSync.backendAuth != nil }

    // How many of the 32 tracked micronutrients this food has no value for.
    private var missingCount: Int {
        MicroField.all.filter { $0.value(food.micros) == nil }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if sent {
                Label("Thanks — this food is in the review queue.",
                      systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(theme.current.accent)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(headline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showingReasons = true
                } label: {
                    Label("Ask for correction", systemImage: "exclamationmark.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(theme.current.accent)
                .controlSize(.large)
                .disabled(!canReport)

                if let note = footnote {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .sheet(isPresented: $showingReasons) {
            FoodCorrectionReasonSheet(food: food) { receipt in
                remainingToday = receipt.remainingToday
                quotaDay = Self.today()
                sent = true
            }
            .themed(theme.current)
        }
    }

    private var headline: String {
        missingCount > 0
            ? "\(missingCount) of \(MicroField.all.count) nutrients aren't reported for this food."
            : "Numbers look wrong?"
    }

    // Claude  Date 08/06/2026
    // Ghost mode gets the explanation instead of a dead button; otherwise show the
    // remaining quota, but only when it was last read TODAY (yesterday's count is
    // meaningless — the limit resets daily).
    private var footnote: String? {
        guard canReport else {
            return "Correction requests need Friends mode turned on."
        }
        guard quotaDay == Self.today(), remainingToday >= 0 else { return nil }
        return remainingToday == 1 ? "1 request left today" : "\(remainingToday) requests left today"
    }

    // The server's quota rolls on the UTC day, so the local label has to agree.
    private static func today() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }
}

// Bryce Hart Date 08/06/2026
// The reason picker: five buttons, no free-text field. Tapping a reason IS the send —
// a confirm step would only add a tap to a request that's already cheap to make and
// rate-limited anyway. The sheet stays up while the call is in flight so a failure can
// be reported against the choice that caused it.
private struct FoodCorrectionReasonSheet: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var cardSync: CardSyncService
    @Environment(\.dismiss) private var dismiss

    let food: FoodDetail
    let onSent: (FoodCorrectionClient.Receipt) -> Void

    @State private var sending: FoodCorrectionReason?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(FoodCorrectionReason.allCases) { reason in
                        Button { Task { await send(reason) } } label: {
                            HStack {
                                Label(reason.label, systemImage: reason.systemImage)
                                Spacer()
                                if sending == reason { ProgressView() }
                            }
                        }
                        .disabled(sending != nil)
                    }
                } header: {
                    Text("What's wrong?")
                } footer: {
                    Text("This sends \(food.name) back to be checked. Sending wrong labels helps keep Agil free for everyone.")
                }
            }
            .navigationTitle("Ask for correction")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(sending != nil)
                }
            }
            .alert("Couldn't send", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium])
    }

    private func send(_ reason: FoodCorrectionReason) async {
        // The card hides the button without auth, so this is belt-and-braces; report it
        // rather than failing silently if the state ever changes mid-sheet.
        guard let auth = cardSync.backendAuth else {
            errorMessage = FoodCorrectionError.noAccount.errorDescription
            return
        }
        sending = reason
        do {
            let receipt = try await FoodCorrectionClient().report(food, reason: reason, auth: auth)
            sending = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSent(receipt)
            dismiss()
        } catch {
            sending = nil
            errorMessage = (error as? FoodCorrectionError)?.errorDescription
                ?? "Couldn't send this correction request. Check your connection and try again."
        }
    }
}

#if DEBUG
#Preview("Sparse food") {
    FoodCorrectionCard(food: FoodDetail(
        name: "Natural Jif Creamy Peanut Butter Spread",
        brand: "Jif",
        category: "Peanut butter spreads",
        source: .openFoodFacts,
        servingQuantity: 33,
        per100: Nutrients(calories: 594, protein: 21, carbs: 21, fat: 51,
                          fiber: 6, sugar: 6, sodium: 152),
        micros: Micros(vE: 3.1)))
        .padding()
        .environmentObject(ThemeManager())
        .environmentObject(CardSyncService())
}
#endif
