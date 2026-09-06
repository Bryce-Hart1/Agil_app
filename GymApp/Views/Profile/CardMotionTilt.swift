import Foundation
import CoreMotion
import CoreGraphics

// CLAUDE  Date 09/05/2026
// Device-motion tilt for inspect mode: a few degrees of pitch and roll relative to
// however the phone was held when inspecting began, so the card leans as you move the
// phone and its light band shifts with it. Built to be cheap on older devices — 30 Hz
// updates, a low-pass filter, and an epsilon gate so noise never triggers a re-render.
// Needs no permission (device motion isn't a privacy-gated CoreMotion API). Does
// nothing at all on hardware without a gyroscope, including the simulator.
final class CardMotionTilt: ObservableObject {
    // Degrees. `width` is about the vertical axis (roll), `height` about the horizontal
    // (pitch) — the same layout CardFlipView's `tilt` parameter takes.
    @Published private(set) var tilt: CGSize = .zero

    private let manager = CMMotionManager()
    private var reference: CMAttitude?

    private let maxDegrees: Double = 9
    private let gain: Double = 0.45
    private let smoothing: Double = 0.35

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        reference = nil
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let attitude = motion.attitude
            // The first sample is "level": tilt is measured from there, so inspecting
            // works the same lying in bed as standing up.
            guard let reference = self.reference else {
                self.reference = attitude.copy() as? CMAttitude
                return
            }
            attitude.multiply(byInverseOf: reference)

            // Sign convention: tilt the phone's right edge down and the card's right
            // edge turns away — the card moves WITH the phone, slightly exaggerated.
            let roll = attitude.roll * 180 / .pi
            let pitch = attitude.pitch * 180 / .pi
            let target = CGSize(width: self.clamp(roll * self.gain),
                                height: self.clamp(-pitch * self.gain))
            let next = CGSize(
                width: self.tilt.width + (target.width - self.tilt.width) * self.smoothing,
                height: self.tilt.height + (target.height - self.tilt.height) * self.smoothing)
            guard abs(next.width - self.tilt.width) > 0.04
                    || abs(next.height - self.tilt.height) > 0.04 else { return }
            self.tilt = next
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        reference = nil
        tilt = .zero
    }

    private func clamp(_ degrees: Double) -> CGFloat {
        CGFloat(min(max(degrees, -maxDegrees), maxDegrees))
    }

    deinit { manager.stopDeviceMotionUpdates() }
}
