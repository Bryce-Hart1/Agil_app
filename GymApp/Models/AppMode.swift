import Foundation

// Claude  Date 06/16/2026
// The two "worlds" the app switches between from the leftmost tab: the existing
// lifting tracker and the new nutrition tracker. The bottom bar always shows a
// switcher tab on the far left whose icon/label advertise the OTHER mode — tapping
// it flips RootTabView's whole tab set. Persisted (via @AppStorage) so the app
// reopens in the last-used world.
enum AppMode: String, CaseIterable, Hashable {
    case lifting
    case nutrition

    /// The mode you land in when tapping the switcher from this one.
    var toggled: AppMode { self == .lifting ? .nutrition : .lifting }

    // Claude  Date 06/16/2026
    // The switcher tab advertises where it takes you, so it shows the OTHER mode's
    // icon/label (in Lifting you see a fork to go to Food, and vice-versa).
    var switchIcon: String { self == .lifting ? "fork.knife" : "dumbbell" }
    var switchLabel: String { self == .lifting ? "Food" : "Lifting" }
}
