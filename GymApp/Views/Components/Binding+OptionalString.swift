import SwiftUI

extension Binding where Value == String {
    /// Bridges an optional-string binding to a non-optional one for use with
    /// `TextField`. Reads nil as `fallback`, and stores an empty string back as
    /// nil so the underlying JSON stays clean (no empty "" notes persisted).
    init(_ source: Binding<String?>, replacingNilWith fallback: String) {
        self.init(
            get: { source.wrappedValue ?? fallback },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}
