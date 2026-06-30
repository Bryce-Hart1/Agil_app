import SwiftUI
import AVFoundation

// Claude  Date 06/18/2026
// The raw camera barcode reader — a thin UIKit (AVFoundation) bridge that reports the
// first decoded barcode string via `onScan`. It owns only the capture session/preview;
// camera permission and the resolve-and-log flow live in BarcodeScanSheet. `isActive`
// gates detection so the host can pause it (e.g. while looking a code up) and re-arm it
// for "Scan again" without tearing the camera down.
struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    var isActive: Bool = true

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ controller: ScannerViewController, context: Context) {
        controller.onScan = onScan
        controller.setScanning(isActive)
    }
}

// Claude  Date 06/18/2026
// Owns the AVCaptureSession. Configuration + start/stop run off the main thread (the
// session calls block); the preview layer and delegate callbacks stay on main.
final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "agil.barcode.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var scanningEnabled = true

    // The 1D retail barcodes we care about, plus QR for good measure. Filtered against
    // what the output actually supports before being set.
    private static let desiredTypes: [AVMetadataObject.ObjectType] = [
        .ean8, .ean13, .upce, .code39, .code93, .code128, .itf14, .qr
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = Self.desiredTypes.filter {
            output.availableMetadataObjectTypes.contains($0)
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer

        start()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        if let connection = previewLayer?.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [session] in if session.isRunning { session.stopRunning() } }
    }

    private func start() {
        sessionQueue.async { [session] in if !session.isRunning { session.startRunning() } }
    }

    func setScanning(_ enabled: Bool) { scanningEnabled = enabled }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard scanningEnabled,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return }
        // Latch off immediately so a single barcode can't fire repeatedly in one frame
        // burst; the host re-arms via isActive when it wants another scan.
        scanningEnabled = false
        onScan?(value)
    }
}
