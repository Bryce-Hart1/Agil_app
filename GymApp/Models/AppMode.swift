import Foundation

// Claude  Date 06/16/2026 last changed: 07/13/2026 by: Claude
// The two "worlds" the app switches between: the existing lifting tracker and the
// nutrition tracker. Switching now happens from the ModeNotch pill pinned at the
// top of the screen (it replaced the old leftmost switcher tab) — the notch shows
// the CURRENT mode's icon/label plus a cross-mode stat, and tapping it flips
// RootTabView's whole tab set. Persisted (via @AppStorage) so the app reopens in
// the last-used world.
enum AppMode: String, CaseIterable, Hashable {
    case lifting
    case nutrition

    /// The mode you land in when tapping the switcher from this one.
    var toggled: AppMode { self == .lifting ? .nutrition : .lifting }

    // Claude  Date 07/13/2026 last changed: 07/13/2026 by: Claude
    // The notch advertises where you ARE (the old switcher tab advertised the
    // other world instead), so these describe the current mode itself. Food now
    // uses the hand-made "bowl-food" asset; lifting stays on the SF Symbol
    // dumbbell — see iconIsCustomAsset for how the notch picks the right Image init.
    var icon: String { self == .lifting ? "dumbbell" : "bowl-food" }
    var label: String { self == .lifting ? "Lifting" : "Food" }

    // Claude  Date 07/13/2026
    // Whether `icon` names a custom asset-catalog image (Image("name")) rather than
    // an SF Symbol (Image(systemName:)). Only the food side uses a custom asset.
    var iconIsCustomAsset: Bool { self == .nutrition }
}
