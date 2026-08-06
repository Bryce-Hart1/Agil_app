import SwiftUI

// Claude  Date 06/16/2026 last changed: 08/04/2026 by: Claude
// Form sheet for adding a food — the nutrition analog of NewExerciseView. You define
// one reference serving and its nutrients; logging later multiplies by a serving count.
// Calls `onCreate` with the saved food (the picker uses that to jump straight into
// logging it), then dismisses.
//
// (Reworked into a submission form as well as a local one. Three additions:
//  • A "kind" step — restaurant / generic — which is what the backend's curation flags
//    carry, and what decides the food's provenance badge.
//  • A barcode step under the name/brand, red while empty and flashing green once
//    captured. It sits high in the form on purpose: the barcode is the vault's lookup
//    key, so a food without one can be saved locally but can never be verified.
//  • The full micronutrient block, driven by the same MicroField table the detail page
//    reads out, so what you can enter and what the app can display never drift.
// A food can now also be sent to the backend review queue — see FoodSubmissionClient.)
struct NewFoodView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var cardSync: CardSyncService
    @Environment(\.dismiss) private var dismiss

    let initialName: String
    // Claude  Date 06/18/2026
    // When the user creates a food after a barcode scan found nothing, the scanned code
    // is carried here so it's stored on the food (and remembered in the cache, so a
    // future scan of the same product resolves to it).
    let initialBarcode: String?
    let onCreate: (FoodItem) -> Void

    @State private var name: String
    @State private var brand = ""
    @State private var barcode: String
    @State private var servingSize: Double = 100
    @State private var servingUnit = "g"
    @State private var calories: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    @State private var fiber: Double = 0
    @State private var sugar: Double = 0
    @State private var sodium: Double = 0

    // Claude  Date 08/04/2026
    // What kind of food this is. One choice rather than the backend's two independent
    // booleans, because the two are not independent in practice: a food is a packaged
    // product, a restaurant menu item, or a generic whole food, never two of those.
    // Modelling it as an enum also makes the barcode question answer itself — only a
    // packaged product has one — so the barcode step appears for exactly one case
    // instead of being a field the user has to know not to fill in.
    @State private var kind: FoodKind = .packaged

    // Micronutrients as typed — per serving, like the macros above. Converted to
    // per-100 on submission; MicroField owns which fields exist and in what unit.
    @State private var micros = Micros()

    // Barcode step state: the camera sheet, and the green pulse right after a capture.
    @State private var showingScanner = false
    @State private var barcodeFlash = false

    // Submission state. The food is always saved locally first, so a failed submit
    // never loses what the user typed.
    @State private var shareForReview = true
    @State private var isSubmitting = false
    @State private var submitError: String?

    init(initialName: String = "", initialBarcode: String? = nil,
         onCreate: @escaping (FoodItem) -> Void = { _ in }) {
        self.initialName = initialName
        self.initialBarcode = initialBarcode
        self.onCreate = onCreate
        _name = State(initialValue: initialName)
        _barcode = State(initialValue: initialBarcode ?? "")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var trimmedBarcode: String { barcode.filter(\.isNumber) }
    private var hasBarcode: Bool { !trimmedBarcode.isEmpty }
    private var canSubmit: Bool { cardSync.backendAuth != nil }

    // Claude  Date 08/04/2026
    // The three kinds a hand-entered food can be, and the two backend curation flags
    // each one implies. Split this way because "does it have a barcode?" is answered
    // by the kind, not asked separately: only a packaged retail product carries one.
    private enum FoodKind: String, CaseIterable, Identifiable {
        case packaged, restaurant, generic
        var id: String { rawValue }

        var title: String {
            switch self {
            case .packaged:   return "Packaged"
            case .restaurant: return "Restaurant"
            case .generic:    return "Generic"
            }
        }

        /// Only a packaged product has a barcode to scan.
        var hasBarcode: Bool { self == .packaged }

        var isRestaurant: Bool { self == .restaurant }
        var isGeneric: Bool { self == .generic }

        /// The origin stamped on the local copy, mirroring the flags the backend gets.
        var localSource: FoodSource {
            switch self {
            case .packaged:   return .custom
            case .restaurant: return .restaurant
            case .generic:    return .usda
            }
        }

        var explanation: String {
            switch self {
            case .packaged:
                return "A branded product with a barcode on the package."
            case .restaurant:
                return "A menu item, like a Chipotle bowl. No barcode — restaurant food isn't packaged."
            case .generic:
                return "A whole food, like \u{201C}apple, raw\u{201D}. No barcode — generic food isn't a branded product."
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Brand / restaurant (optional)", text: $brand)
                }

                kindSection
                if kind.hasBarcode { barcodeSection }

                Section("Serving") {
                    LabeledContent("Size") {
                        TextField("Size", value: $servingSize, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    TextField("Unit (g, ml, cup…)", text: $servingUnit)
                }

                Section {
                    macroField("Calories (kcal)", value: $calories)
                    macroField("Protein (g)", value: $protein)
                    macroField("Carbs (g)", value: $carbs)
                    macroField("Fat (g)", value: $fat)
                } header: {
                    Text("Nutrition per serving")
                }

                Section("Extras (optional)") {
                    macroField("Fiber (g)", value: $fiber)
                    macroField("Sugar (g)", value: $sugar)
                    macroField("Sodium (mg)", value: $sodium)
                }

                microSections
                shareSection
            }
            .navigationTitle("New Food")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .disabled(trimmedName.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeCaptureSheet { code in captured(code) }
            }
            // Claude  Date 08/04/2026
            // Submission failed but the local save already succeeded, so the title
            // leads with what DID happen — the user's typing is not lost, and the
            // message explains the part that didn't.
            .alert("Saved to this device", isPresented: Binding(
                get: { submitError != nil },
                set: { if !$0 { submitError = nil } }
            )) {
                Button("OK") {
                    submitError = nil
                    dismiss()
                }
            } message: {
                Text(submitError ?? "")
            }
        }
    }

    // MARK: - Kind

    // Claude  Date 08/04/2026
    // One three-way choice, sitting directly above the barcode step because it decides
    // whether that step exists at all. Replaced two independent toggles that could both
    // be off (ambiguous) or both be on (nonsense, and only prevented by a pair of
    // onChange handlers clearing each other) — a segmented picker makes the invalid
    // states unrepresentable instead of merely unreachable.
    private var kindSection: some View {
        Section {
            Picker("Kind", selection: $kind) {
                ForEach(FoodKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Kind")
        } footer: {
            Text(kind.explanation)
        }
    }

    // MARK: - Barcode step

    // Claude  Date 08/04/2026
    // The barcode step, sitting right under the name/brand because it decides how far
    // this food can go: the verified vault is keyed BY barcode, so a food without one
    // can never be verified no matter how good its numbers are. Hence the red state —
    // it's not decoration, it's "this food will stay unverifiable". Scanning is the
    // main path (the number is long and mistyping it silently poisons a lookup); the
    // field stays typeable for a damaged label or a denied camera.
    private var barcodeSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: hasBarcode ? "checkmark.circle.fill" : "barcode")
                    .font(.title3)
                    .foregroundStyle(barcodeTint)
                    .accessibilityHidden(true)

                TextField("Barcode digits", text: $barcode)
                    .keyboardType(.numberPad)
                    .font(.body.monospacedDigit())

                Button {
                    showingScanner = true
                } label: {
                    Label("Scan", systemImage: "camera.fill")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .padding(8)
                        .background(theme.current.accent.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Scan barcode with camera")
            }
            .listRowBackground(barcodeTint.opacity(barcodeFlash ? 0.38 : 0.12))
        } header: {
            Text("Barcode")
        } footer: {
            Text(hasBarcode
                 ? "Scanned. This food can be verified into the Agil database once it's reviewed."
                 : "No barcode yet — tap the camera to scan the package. Without one this food stays on your device only.")
                .foregroundStyle(hasBarcode ? Color.secondary : barcodeTint)
        }
    }

    private var barcodeTint: Color {
        hasBarcode ? FoodSourcePalette.verifiedStack : .red
    }

    // Claude  Date 08/04/2026
    // Flash the row green on capture: a bright pulse that settles into the steady
    // "filled" green, so the confirmation is visible without a second dialog.
    private func captured(_ code: String) {
        barcode = code
        withAnimation(.easeOut(duration: 0.18)) { barcodeFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.55)) { barcodeFlash = false }
        }
    }

    // MARK: - Micronutrients

    // Claude  Date 08/04/2026
    // Every micronutrient the verified food format can hold, collapsed by default —
    // 32 fields open would bury the macros nobody wants to scroll past. Driven by
    // MicroField.all, the same table the detail page renders, so a field added there
    // becomes enterable here for free. Blank means "not available" and is stored as
    // absent, which is meaningfully different from a typed 0.
    @ViewBuilder private var microSections: some View {
        Section {
            ForEach(MicroGroup.allCases) { group in
                DisclosureGroup(group.rawValue) {
                    ForEach(MicroField.fields(in: group)) { field in
                        LabeledContent("\(field.label) (\(field.unit))") {
                            TextField("—", value: microBinding(field), format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        } header: {
            Text("Micronutrients per serving (optional)")
        } footer: {
            Text("Leave a nutrient blank if the label doesn't list it — blank means \u{201C}not available\u{201D}, which isn't the same as zero.")
        }
    }

    // A binding onto one micro field. Optional-typed so an empty text field clears the
    // value back to nil ("not available") instead of writing a 0.
    private func microBinding(_ field: MicroField) -> Binding<Double?> {
        Binding(
            get: { micros[keyPath: field.key] },
            set: { micros[keyPath: field.key] = $0 }
        )
    }

    // MARK: - Sharing

    // Claude  Date 08/04/2026
    // Submission to the review queue. Card auth is required by the endpoint (an
    // anonymous submit could be looped to flood the queue), so in Ghost mode this
    // section explains the situation instead of offering a toggle that would fail.
    @ViewBuilder private var shareSection: some View {
        Section {
            if canSubmit {
                Toggle("Send for review", isOn: $shareForReview)
            } else {
                Label("Friends mode is off", systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Agil database")
        } footer: {
            if canSubmit {
                switch kind {
                case .restaurant:
                    Text("Your entry joins the review queue so others can find it. Restaurant nutrition facts are published by the chains themselves — enter them as listed, and don't copy menu descriptions.")
                case .generic:
                    Text("Your entry joins the review queue so others can find it.")
                case .packaged:
                    Text("Your entry joins the review queue. Once it's checked it becomes a verified food for everyone.")
                }
            } else {
                Text("Foods can only be shared with the database in Friends mode. This one will be saved to your device.")
            }
        }
    }

    // MARK: - Save

    private func macroField(_ label: String, value: Binding<Double>) -> some View {
        LabeledContent(label) {
            TextField(label, value: value, format: .number)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
        }
    }

    // Claude  Date 06/16/2026 last changed: 08/04/2026 by: Claude
    // Save locally FIRST, always — the local library is the user's own copy and must
    // never depend on a network call succeeding. Submission is a best-effort second
    // step; when it fails the food is already safe and the alert says so rather than
    // implying the entry was lost.
    private func save() async {
        let unit = servingUnit.trimmingCharacters(in: .whitespaces)
        // Only a packaged product carries a barcode. A code typed before switching
        // kinds stays in the field (so switching back doesn't lose it) but never
        // reaches the saved food — the kind is the authority on whether one exists.
        let code = kind.hasBarcode ? trimmedBarcode : ""
        let willSubmit = shareForReview && canSubmit

        let food = store.addFood(FoodItem(
            name: trimmedName,
            brand: brand.trimmingCharacters(in: .whitespaces),
            barcode: code.isEmpty ? nil : code,
            servingSize: servingSize > 0 ? servingSize : 1,
            servingUnit: unit.isEmpty ? "serving" : unit,
            nutrients: Nutrients(calories: calories, protein: protein, carbs: carbs,
                                 fat: fat, fiber: fiber, sugar: sugar, sodium: sodium),
            source: kind.localSource,
            // Pending only when it's actually on its way to the queue; a device-only
            // food isn't waiting on anyone.
            verification: willSubmit ? .pending : nil,
            micros: micros))

        // Claude  Date 06/18/2026 — remember the scanned barcode so a future scan of the
        // same product resolves straight to this food (no "not found" again).
        if !code.isEmpty {
            store.rememberScannedFood(food, forBarcode: code)
        }

        if willSubmit, let auth = cardSync.backendAuth {
            isSubmitting = true
            do {
                _ = try await FoodSubmissionClient().submit(
                    food, micros: micros, isRestaurant: kind.isRestaurant,
                    isGeneric: kind.isGeneric, auth: auth)
            } catch {
                isSubmitting = false
                // The local save already happened; report and let the user dismiss.
                submitError = (error as? FoodSubmissionError)?.errorDescription
                    ?? "Saved to your device, but couldn't send it for review."
                onCreate(food)
                return
            }
            isSubmitting = false
        }

        onCreate(food)
        dismiss()
    }
}

#Preview {
    NewFoodView()
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
        .environmentObject(CardSyncService())
}
