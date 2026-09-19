import SwiftUI

// CLAUDE  Date 09/18/2026
// One removal that can still be taken back (Bryce, 9/18/26): what the popup says, how to put
// it back, and when the offer runs out. A fresh id per removal, so a second one restarts the
// clock and replaces the first — only the latest removal is undoable.
struct PendingUndo: Identifiable, Equatable {
    /// How long the popup stays up — long enough to notice a mis-tap, short enough to not linger.
    static let window: TimeInterval = 10

    let id = UUID()
    let message: String
    let deadline = Date().addingTimeInterval(PendingUndo.window)
    let restore: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

extension View {
    // CLAUDE  Date 09/18/2026
    // Shows the undo popup along the bottom while `pending` is set and clears it at its deadline.
    // A safe-area inset rather than an overlay, so the page can still scroll its last rows (e.g.
    // Complete Workout) clear of it. Leaving the page drops the offer: the removal stands.
    func undoToast(_ pending: Binding<PendingUndo?>, accent: Color, surface: Color) -> some View {
        modifier(UndoToastModifier(pending: pending, accent: accent, surface: surface))
    }
}

private struct UndoToastModifier: ViewModifier {
    @Binding var pending: PendingUndo?
    let accent: Color
    let surface: Color

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // CLAUDE  Date 09/18/2026 — the spring is scoped to this stack so it can't
                // restyle the caller's own removal animation, which shares the transaction.
                ZStack {
                    if let undo = pending {
                        UndoToast(message: undo.message, accent: accent, surface: surface) {
                            Haptics.soften()
                            withAnimation(.easeInOut(duration: 0.25)) {
                                undo.restore()
                                pending = nil
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: pending?.id)
            }
            // CLAUDE  Date 09/18/2026
            // Sleeps to the DEADLINE rather than a fixed 10s: switching tabs cancels this and
            // coming back restarts it, and a restart must not hand the offer a fresh 10s.
            .task(id: pending?.id) {
                guard let undo = pending else { return }
                UIAccessibility.post(notification: .announcement, argument: "\(undo.message). Undo available.")
                let remaining = undo.deadline.timeIntervalSinceNow
                if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
                guard !Task.isCancelled, pending?.id == undo.id else { return }
                withAnimation(.easeInOut(duration: 0.25)) { pending = nil }
            }
    }
}

// CLAUDE  Date 09/18/2026
// The "Removed Bench Press · Undo" capsule. Surface fill + AccentRim so it reads as one family
// with the notch, the mini bar and the keyboard bar. Static on purpose: nothing animates while
// it waits, so the ~10s it's up costs no frames on older phones.
private struct UndoToast: View {
    let message: String
    let accent: Color
    let surface: Color
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onUndo) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Undo")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Undo")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(surface)
        .clipShape(Capsule())
        .overlay(AccentRim(shape: Capsule(), accent: accent))
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }
}
