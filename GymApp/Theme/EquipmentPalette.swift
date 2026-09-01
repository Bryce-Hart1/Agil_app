import SwiftUI

// Claude  Date 08/18/2026
// The tints behind the equipment nameplates (Machine / Free Weight / Cable / Smith
// Machine / Bodyweight) — the chip that sits beside a lift's name in the library, the
// picker, and the workout/preset editors.

enum EquipmentPalette {
    /// Plate-loaded and selectorized machines. Blue — the most common type in the
    /// library, so it takes the calmest, most neutral-reading hue.
    static let machine = Color(hex: "#0EA5E9")
    /// Barbells, dumbbells, and anything else you load by hand. Slate: deliberately
    /// the quietest tint of the set, since a free weight is the one type that can't
    /// be branded — nothing about it needs to draw the eye.
    static let freeWeight = Color(hex: "#64748B")
    /// Cable stacks. Green, clearly apart from `machine` blue, which it most often
    /// appears next to (a cable row and a machine row in the same Back section).
    static let cable = Color(hex: "#10B981")
    /// Smith machines. Violet — a fixed bar path is its own animal, and this keeps it
    /// from being mistaken for either a plain machine or a free weight at a glance.
    static let smithMachine = Color(hex: "#8B5CF6")
    /// Movements loaded by your own bodyweight. Amber, matching how the app already
    /// treats bodyweight lifts as a distinct logging mode ("+25 lb").
    static let bodyweight = Color(hex: "#F59E0B")
}
