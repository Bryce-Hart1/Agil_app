import SwiftUI

/// Sets or edits a target rep range. Shows an "add" affordance when no range is
/// set, and inline min/max fields (with a clear button) once it is.
///
/// Shared by the workout editor (per logged exercise) and the preset editor
/// (per preset item).
struct RepRangeRow: View {
    @Binding var targetRepRange: RepRange?

    var body: some View {
        if targetRepRange != nil {
            HStack {
                Label("Target", systemImage: "target")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("min", value: minBinding, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 40)
                Text("–").foregroundStyle(.secondary)
                TextField("max", value: maxBinding, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 40)
                Text("reps").foregroundStyle(.secondary)
                Button {
                    targetRepRange = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        } else {
            Button {
                targetRepRange = RepRange(min: 8, max: 12)
            } label: {
                Label("Set rep range", systemImage: "target")
            }
        }
    }

    private var minBinding: Binding<Int> {
        Binding(get: { targetRepRange?.min ?? 0 },
                set: { targetRepRange?.min = $0 })
    }

    private var maxBinding: Binding<Int> {
        Binding(get: { targetRepRange?.max ?? 0 },
                set: { targetRepRange?.max = $0 })
    }
}
