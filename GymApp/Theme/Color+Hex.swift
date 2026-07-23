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

    // Claude  Date 07/21/2026
    // Black or white, whichever stays readable ON this color. Needed wherever a theme's
    // accent is used as a solid fill behind a label: accents are user-chosen in the theme
    // editor, so a hardcoded white would disappear on a pale yellow or mint.
    //
    // Uses the sRGB relative-luminance weights (0.2126/0.7152/0.0722) against a 0.6
    // threshold — deliberately above 0.5, because white-on-mid-tone reads worse than
    // black-on-mid-tone. Non-UIKit builds fall back to white, matching toHex() below.
    var contrastingForeground: Color {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
        return luminance > 0.6 ? .black : .white
        #else
        return .white
        #endif
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
