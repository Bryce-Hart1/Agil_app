import SwiftUI

// Claude  Date 08/18/2026
// "Add Brand": turn a lift into a branded version of itself — Leg Press ·
// Hammer Strength — as a SEPARATE library entry.
//
// Why separate: a Hammer Strength leg press and a Cybex one don't move the same
// weight, so charting them on one line makes Progress lie. Everything in the app keys
// off exerciseId, so giving the branded version its own id is the whole mechanism:
// it starts with an empty chart and graphs on its own, and the generic lift keeps
// every set it already had. Nothing is reassigned.
//
// The sheet is deliberately one field. All the movement metadata (region, muscle
// group, mover, unilateral/bodyweight, equipment) is cloned from the base lift by
// AppStore.addBrandVariant, because branding a machine doesn't change any of it —
// re-asking would be a form to fill out while standing at the machine.
struct AddBrandVariantView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    /// The lift being branded. Its name and metadata carry into the new entry.
    let base: Exercise
    /// Called with the saved variant — the picker uses this to select it immediately.
    var onCreate: (Exercise) -> Void = { _ in }

    @State private var brand = ""

    private var trimmed: String { brand.trimmingCharacters(in: .whitespaces) }

    /// What the brand will actually be saved as, after snapping to a spelling the
    /// library already uses. Shown live so the case-fixing is visible, not surprising.
    private var canonical: String { store.normalizedBrand(brand) }

    private var previewLabel: String {
        var preview = base
        preview.brand = canonical
        return preview.displayLabel
    }

    // Claude  Date 08/18/2026
    // Whether this base+brand pair is already in the library — the same check
    // addBrandVariant makes. Rather than blocking, the sheet says so and Save becomes
    // "Use Existing", which returns the existing lift (so the picker still selects
    // something and closes instead of dead-ending).
    private var duplicate: Exercise? {
        guard !canonical.isEmpty else { return nil }
        return store.exercises.first {
            $0.id != base.id
                && $0.name.caseInsensitiveCompare(base.name) == .orderedSame
                && $0.brand.caseInsensitiveCompare(canonical) == .orderedSame
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Brand (e.g. Hammer Strength)", text: $brand)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    // Brands already in the library, so the second machine of a brand
                    // is one tap and can't be misspelled into a second entry.
                    ForEach(store.brandSuggestions(matching: brand), id: \.self) { suggestion in
                        Button {
                            brand = suggestion
                        } label: {
                            Label(suggestion, systemImage: "arrow.up.left.circle")
                                .font(.subheadline)
                        }
                    }
                } header: {
                    Text("Brand")
                } footer: {
                    Text("The manufacturer of the machine — or the gym's name, if you don't know it.")
                }

                Section {
                    LabeledContent("Saves as", value: previewLabel)
                    if let equipment = base.equipmentType {
                        LabeledContent("Equipment") {
                            EquipmentBadge(type: equipment, style: .detail)
                        }
                    }
                } footer: {
                    if duplicate != nil {
                        Text("You already have this one. Saving will just use it.")
                    } else {
                        Text("This becomes its own lift with its own history and its own line in Progress. Your existing \(base.name) sets stay with the original.")
                    }
                }
            }
            .navigationTitle("Add Brand")
            .navigationBarTitleDisplayMode(.inline)
            .themed(theme.current)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(duplicate == nil ? "Save" : "Use Existing", action: save)
                        .disabled(trimmed.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let created = store.addBrandVariant(of: base, brand: brand) else { return }
        onCreate(created)
        dismiss()
    }
}

#Preview {
    AddBrandVariantView(base: Exercise(name: "Leg Press", region: .legs, category: "Quads",
                                       primaryMover: "Quadriceps", equipmentType: .machine))
        .environmentObject(AppStore())
        .environmentObject(ThemeManager())
}
