import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 09/01/2026
// The app's haptic vocabulary. Two reasons this exists rather than more inline
// UIImpactFeedbackGenerator() calls:
//
//   • The generators are RETAINED and prepare()d. A freshly-allocated generator has to
//     spin the Taptic Engine up, so the first hit lands late and feels mushy — which is
//     exactly how the old inline calls felt. A warm generator fires with the pixels.
//   • Distinct events should feel distinct. Finishing a set, undoing one and nudging one
//     up the list are three different things and now have three different textures.
//
// All iOS 16-safe: .sensoryFeedback would need iOS 17. No-ops off UIKit (previews, mac).
enum Haptics {
    #if canImport(UIKit)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notice = UINotificationFeedbackGenerator()
    #endif

    /// Warm the Taptic Engine ~seconds before the feedback is expected. Cheap, and the
    /// engine idles back down on its own — call it when a gesture surface appears.
    static func prepare() {
        #if canImport(UIKit)
        light.prepare(); soft.prepare(); rigid.prepare(); heavy.prepare(); notice.prepare()
        #endif
    }

    /// A generic tick — buttons, selections.
    static func tap() {
        #if canImport(UIKit)
        light.impactOccurred(); light.prepare()
        #endif
    }

    /// The gentlest texture. For undoing something, where a celebratory buzz would lie.
    static func soften() {
        #if canImport(UIKit)
        soft.impactOccurred(intensity: 0.7); soft.prepare()
        #endif
    }

    /// A crisp mechanical click — for a thing snapping into a new position (a detent).
    static func click() {
        #if canImport(UIKit)
        rigid.impactOccurred(); rigid.prepare()
        #endif
    }

    /// The system's two-beat success pattern. For completing a unit of work.
    static func success() {
        #if canImport(UIKit)
        notice.notificationOccurred(.success); notice.prepare()
        #endif
    }

    // Claude  Date 09/01/2026
    // Success plus a heavier chaser a beat later, so finishing the LAST set of a lift
    // lands harder than finishing any other set. The delay is what makes it read as
    // punctuation rather than one muddled buzz.
    static func celebrate() {
        #if canImport(UIKit)
        notice.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            heavy.impactOccurred(intensity: 0.9); heavy.prepare()
        }
        notice.prepare()
        #endif
    }
}
