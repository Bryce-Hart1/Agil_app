import SwiftUI
import AVFoundation

// Claude  Date 08/04/2026
// A camera sheet that just READS a barcode and hands back the digits — no lookup, no
// caching, no "not found" flow. BarcodeScanSheet resolves a scan into a food, which is
// wrong for the new-food form: there the user is describing a product the catalogue
// doesn't have yet, and all we want off the camera is the number on the package.
//
// Shares the underlying BarcodeScannerView (and its permission handling shape) with
// BarcodeScanSheet; only the "what happens after a scan" half differs.
struct BarcodeCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Called with the scanned digits. The sheet dismisses itself right after.
    var onCapture: (String) -> Void

    @State private var phase: Phase = .requesting

    private enum Phase: Equatable {
        case requesting     // checking / asking for camera permission
        case denied         // no camera access
        case scanning       // live, waiting for a barcode
        case captured(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                switch phase {
                case .requesting:
                    ProgressView().tint(.white)
                case .denied:
                    deniedView
                case .scanning, .captured:
                    cameraStack
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await requestAccessIfNeeded() }
        }
    }

    private var cameraStack: some View {
        ZStack {
            BarcodeScannerView(onScan: handleScan, isActive: phase == .scanning)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.9), lineWidth: 3)
                .frame(width: 260, height: 160)
                .shadow(radius: 6)

            VStack {
                Spacer()
                statusPill.padding(24)
            }
        }
    }

    @ViewBuilder private var statusPill: some View {
        VStack(spacing: 8) {
            if case .captured(let code) = phase {
                Label(code, systemImage: "checkmark.circle.fill")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.green)
            } else {
                Text("Point at the barcode on the package")
                    .font(.subheadline).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var deniedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill").font(.largeTitle).foregroundStyle(.white)
            Text("Camera access is off")
                .font(.headline).foregroundStyle(.white)
            Text("Turn on camera access for Agil in Settings to scan a barcode, or type the digits in by hand.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(28)
    }

    // Claude  Date 08/04/2026
    // Hold the captured code on screen for a beat before dismissing — the scan
    // succeeds faster than the eye can follow, and a sheet that vanishes instantly
    // reads as a glitch rather than a confirmation. The form flashes green on the
    // way back, so this is the first half of one continuous confirmation.
    private func handleScan(_ code: String) {
        guard case .scanning = phase else { return }
        let digits = code.filter(\.isNumber)
        guard !digits.isEmpty else { return }
        phase = .captured(digits)
        onCapture(digits)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { dismiss() }
    }

    private func requestAccessIfNeeded() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            phase = .scanning
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            phase = granted ? .scanning : .denied
        default:
            phase = .denied
        }
    }
}
