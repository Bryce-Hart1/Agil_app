import SwiftUI
import AVFoundation

// Claude  Date 06/18/2026
// The barcode scan flow: handles camera permission, shows the live camera with a
// reticle, and on a scan resolves the product through CachedFoodService (local cache
// first, then Open Food Facts — caching the result). On success it hands the FoodItem
// back via `onResolved` and dismisses (the caller logs it / adds it to Recents); on a
// miss it offers "Scan again" or "Enter manually" (→ `onManualEntry` with the barcode).
//
// Reusable: the picker uses it to scan-and-log into a meal; the Foods tab uses it to
// scan-into-Recents. The caller decides what "resolved" means.
struct BarcodeScanSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var onResolved: (FoodItem) -> Void
    var onManualEntry: (String) -> Void = { _ in }

    // Claude  Date 06/18/2026
    // Offline mode (shared with the food search): when on, a scan only checks the local
    // cache; a miss offers an explicit "Search online" before falling back to manual.
    @AppStorage("offlineFoodMode") private var offlineMode = false

    @State private var phase: Phase = .requesting
    @State private var lookupTask: Task<Void, Never>?

    private enum Phase: Equatable {
        case requesting                          // checking / asking for camera permission
        case denied                              // no camera access
        case scanning                            // live, waiting for a barcode
        case looking(String)                     // resolving a scanned code
        case notFound(String, canGoOnline: Bool) // genuinely not in the catalogue — offer online / manual / retry
        case connectionError(String)             // couldn't reach Open Food Facts (no signal / server error)
    }

    // Claude  Date 06/30/2026
    // Cache-first resolver: local BarcodeCache → Agil backend (which is itself a
    // read-through cache over Open Food Facts). The local cache short-circuits repeat
    // scans before any server round-trip.
    private var resolver: CachedFoodService {
        CachedFoodService(base: BackendFoodClient(), store: store)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                content
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await requestAccessIfNeeded() }
            .onDisappear { lookupTask?.cancel() }
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .requesting:
            ProgressView().tint(.white)
        case .denied:
            deniedView
        case .scanning, .looking, .notFound, .connectionError:
            cameraStack
        }
    }

    // MARK: - Camera + overlay

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
                statusBar.padding(24)
            }
        }
    }

    @ViewBuilder private var statusBar: some View {
        switch phase {
        case .looking:
            pill {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Looking up…").foregroundStyle(.white)
                }
            }
        case .notFound(let code, let canGoOnline):
            pill {
                VStack(spacing: 12) {
                    Text(canGoOnline ? "Not in your offline foods" : "No product found")
                        .font(.headline).foregroundStyle(.white)
                    Text(code).font(.caption.monospaced()).foregroundStyle(.white.opacity(0.75))
                    if canGoOnline {
                        Button { searchOnline(code) } label: {
                            Label("Search online", systemImage: "wifi").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(theme.current.accent)
                    }
                    HStack(spacing: 12) {
                        Button("Scan again") { phase = .scanning }
                            .buttonStyle(.bordered).tint(.white)
                        // Prominent only when it's the primary fallback (no online option).
                        if canGoOnline {
                            Button("Enter manually") { onManualEntry(code); dismiss() }
                                .buttonStyle(.bordered).tint(.white)
                        } else {
                            Button("Enter manually") { onManualEntry(code); dismiss() }
                                .buttonStyle(.borderedProminent).tint(theme.current.accent)
                        }
                    }
                }
            }
        case .connectionError(let code):
            pill {
                VStack(spacing: 12) {
                    Text("Couldn't reach Open Food Facts").font(.headline).foregroundStyle(.white)
                    Text("Check your connection and try again.")
                        .font(.caption).foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                    Button { searchOnline(code) } label: {
                        Label("Try again", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(theme.current.accent)
                    HStack(spacing: 12) {
                        Button("Scan again") { phase = .scanning }
                            .buttonStyle(.bordered).tint(.white)
                        Button("Enter manually") { onManualEntry(code); dismiss() }
                            .buttonStyle(.bordered).tint(.white)
                    }
                }
            }
        default:
            pill {
                Label("Point at a barcode", systemImage: "barcode.viewfinder")
                    .foregroundStyle(.white)
            }
        }
    }

    private func pill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.8))
            Text("Camera access is off")
                .font(.headline).foregroundStyle(.white)
            Text("Allow camera access in Settings to scan barcodes.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                #if canImport(UIKit)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #endif
            }
            .buttonStyle(.borderedProminent).tint(theme.current.accent)
        }
        .padding(32)
    }

    // MARK: - Flow

    private func handleScan(_ code: String) {
        guard phase == .scanning else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        phase = .looking(code)
        lookupTask?.cancel()
        lookupTask = Task {
            if offlineMode {
                // Cache only — a miss isn't an error, just "not saved offline".
                let food = await store.cachedFood(forBarcode: code)
                if Task.isCancelled { return }
                if let food { onResolved(food); dismiss() }
                else { phase = .notFound(code, canGoOnline: true) }
            } else {
                await resolveOnline(code)
            }
        }
    }

    // Explicit one-off online lookup (from the offline "not found" or a connection-error
    // "try again").
    private func searchOnline(_ code: String) {
        phase = .looking(code)
        lookupTask?.cancel()
        lookupTask = Task { await resolveOnline(code) }
    }

    // Claude  Date 06/18/2026
    // Online resolve that separates the two failure modes: a `nil` result means the
    // product genuinely isn't in Open Food Facts (→ notFound); a thrown error means we
    // couldn't reach it at all (→ connectionError, which offers "Try again").
    @MainActor
    private func resolveOnline(_ code: String) async {
        do {
            let food = try await resolver.lookup(barcode: code)
            if Task.isCancelled { return }
            if let food { onResolved(food); dismiss() }
            else { phase = .notFound(code, canGoOnline: false) }
        } catch is CancellationError {
            // Superseded by a newer lookup — leave the state to it.
        } catch {
            if Task.isCancelled { return }
            phase = .connectionError(code)
        }
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
