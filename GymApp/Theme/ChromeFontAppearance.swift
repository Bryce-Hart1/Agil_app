import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Claude  Date 07/21/2026
// SwiftUI's .fontDesign() (applied once in RootTabView) re-skins everything SwiftUI
// itself draws, but navigation-bar titles and bar-button labels are drawn by UIKit,
// which never sees it — so on a monospaced theme they'd stay SF Pro while the rest of
// the app went mono. This mirrors the theme's typeface onto that chrome.
//
// Two halves, both needed:
//  1. The appearance proxies, which only affect navigation bars created AFTER the call.
//  2. A refresh pass over bars that are already on screen — otherwise switching themes
//     from Settings leaves every live nav bar on the old typeface until it's rebuilt.
//     Same class of problem as retintOnThemeChange in ThemedModifiers.swift (UIKit-backed
//     controls caching what was in effect when they were created).
//
// Out of reach and accepted: UIAlertController (the .alert() sites) and the keyboard
// are drawn by the system in its own font.
enum ChromeFontAppearance {
    static func apply(_ design: AppFontDesign) {
        #if canImport(UIKit)
        let titleFont = font(ofSize: 17, weight: .semibold, design: design)
        let largeTitleFont = font(ofSize: 34, weight: .bold, design: design)
        let buttonFont = font(ofSize: 17, weight: .regular, design: design)

        for appearance in [UINavigationBar.appearance().standardAppearance,
                           UINavigationBar.appearance().compactAppearance,
                           UINavigationBar.appearance().scrollEdgeAppearance] {
            guard let appearance else { continue }
            appearance.titleTextAttributes[.font] = titleFont
            appearance.largeTitleTextAttributes[.font] = largeTitleFont
        }
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: buttonFont], for: .normal)

        refreshLiveNavigationBars(titleFont: titleFont, largeTitleFont: largeTitleFont)
        #endif
    }

    #if canImport(UIKit)
    // Claude  Date 07/21/2026
    // A system font of the given size/weight, re-rendered in the theme's design. The
    // descriptor round-trip is what maps .monospaced onto SF Mono; it can fail for an
    // unavailable design, hence the plain-system fallback.
    private static func font(ofSize size: CGFloat, weight: UIFont.Weight,
                             design: AppFontDesign) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(design.uiDesign) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    // Claude  Date 07/21/2026
    // Walk every window's view tree and re-stamp the nav bars that already exist, so a
    // theme switch lands immediately instead of on the next push. The window lookup is
    // the same connectedScenes route RootTabView.deviceInsets uses.
    private static func refreshLiveNavigationBars(titleFont: UIFont, largeTitleFont: UIFont) {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)

        for window in windows {
            for bar in navigationBars(in: window) {
                for appearance in [bar.standardAppearance, bar.compactAppearance, bar.scrollEdgeAppearance] {
                    guard let appearance else { continue }
                    appearance.titleTextAttributes[.font] = titleFont
                    appearance.largeTitleTextAttributes[.font] = largeTitleFont
                }
                bar.setNeedsLayout()
            }
        }
    }

    private static func navigationBars(in view: UIView) -> [UINavigationBar] {
        var found: [UINavigationBar] = []
        if let bar = view as? UINavigationBar { found.append(bar) }
        for subview in view.subviews { found.append(contentsOf: navigationBars(in: subview)) }
        return found
    }
    #endif
}
