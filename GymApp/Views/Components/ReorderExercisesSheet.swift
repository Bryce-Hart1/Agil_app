import SwiftUI

/// A modal list for drag-reordering a collection of items (used for both a
/// workout's exercises and a preset's items, since per-exercise Sections can't
/// be reordered in place). Edits write straight through the binding.
struct ReorderExercisesSheet<Item: Identifiable>: View {
    let title: String
    @Binding var items: [Item]
    let nameFor: (Item) -> String

    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    Text(nameFor(item))
                }
                .onMove { items.move(fromOffsets: $0, toOffset: $1) }
            }
            .environment(\.editMode, .constant(.active))   // show drag handles immediately
            .themed(theme.current)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
