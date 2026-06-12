#if canImport(UIKit)
import SwiftUI
import UIKit

extension View {
    // Claude  Date 06/10/2026
    // When a numeric-keyboard text field begins editing, select all of its text
    // so the first keystroke replaces the old value (e.g. re-entering a set's
    // weight). Filters by keyboard type so name/notes fields (default keyboard)
    // are left alone — only number/decimal pads get the select-all behavior.
    func selectAllWhenEditingNumberFields() -> some View {
        onReceive(
            NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)
        ) { note in
            guard let field = note.object as? UITextField else { return }
            switch field.keyboardType {
            case .numberPad, .decimalPad:
                // Defer so it runs after the field places its caret.
                DispatchQueue.main.async { field.selectAll(nil) }
            default:
                break
            }
        }
    }
}
#endif
