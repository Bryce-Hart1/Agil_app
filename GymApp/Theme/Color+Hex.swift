import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    /// Create a Color from a hex string like "#1C1C1E" or "1C1C1E" (also accepts 8-digit RRGGBBAA).
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: UInt64
        switch cleaned.count {
        case 8: (r, g, b, a) = (value >> 24 & 0xff, value >> 16 & 0xff, value >> 8 & 0xff, value & 0xff)
        case 6: (r, g, b, a) = (value >> 16 & 0xff, value >> 8 & 0xff, value & 0xff, 255)
        default: (r, g, b, a) = (0, 122, 255, 255) // fall back to system blue
        }

        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }

    /// Serialize to "#RRGGBB". Used to store colors in Codable themes.
    func toHex() -> String {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
        #else
        return "#007AFF"
        #endif
    }
}
