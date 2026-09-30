import SwiftUI

// CLAUDE  Date 09/26/2026
// The catalog behind Help & Demos: sections of guides, each either a short help paragraph
// or an interactive demo (see Demos/). Data only; HelpGuidesView renders it, so editing
// copy never means touching layout code.

// Claude  Date 08/23/2026
// An icon the guide points at, drawn the way the real screen draws it. The app
// mixes SF Symbols with Bryce's custom template assets (which need
// .renderingMode(.template) or they draw flat instead of taking the tint).
enum GuideIcon: Hashable {
    case system(String)
    case asset(String)

    @ViewBuilder func image(size: CGFloat) -> some View {
        switch self {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.8, weight: .regular))
                .frame(width: size, height: size)
        case .asset(let name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}

// CLAUDE  Date 09/26/2026
// What opening a guide shows: a paragraph page, a demo, or nothing yet. `comingSoon` is a
// demo that isn't built; its row is greyed out and can't be tapped.
enum HelpGuideContent {
    case article(String)
    case demo(DemoKind)
    case comingSoon
}

struct HelpGuide: Identifiable {
    let id: String
    let title: String
    /// One line under the title in the list.
    let summary: String
    let icon: GuideIcon
    let content: HelpGuideContent
}

// Claude  Date 08/23/2026
// A titled run of guides in the list. Sections follow the app's own shape.
struct HelpGuideSection: Identifiable {
    let id: String
    let title: String
    let guides: [HelpGuide]
}

// CLAUDE  Date 09/26/2026
// Every guide, in list order. Copy rules: short, no em dashes, and every step a user needs.
// Paragraph facts are checked against the screens they describe; update them with the UI.
enum HelpGuideCatalog {
    static let sections: [HelpGuideSection] = [
        HelpGuideSection(id: "around", title: "Getting around", guides: [flippingSides]),
        HelpGuideSection(id: "you", title: "Your profile",
                         guides: [userCard, prsAndAchievements, appTheme, font]),
        HelpGuideSection(id: "lifting", title: "Lifting",
                         guides: [newWorkout, presetWorkout, buildPreset, customExercise, progressWidget]),
        HelpGuideSection(id: "food", title: "Food", guides: [logMeal, customFood, recipe])
    ]

    // MARK: - Getting around

    static let flippingSides = HelpGuide(
        id: "flipping-sides",
        title: "Flipping sides",
        summary: "Switch between Lifting and Food.",
        icon: .system("arrow.left.arrow.right"),
        content: .article("Agil has two sides, Lifting and Food. Tap the pill at the top of any main screen to flip between them.\n\nThe pill shows your side, your coins, and one number from the other side: calories eaten while lifting, your weekly workout streak while on Food.\n\nYou land in the same spot on the tab bar, and Profile is shared by both sides.")
    )

    // MARK: - Your profile

    static let userCard = HelpGuide(
        id: "user-card",
        title: "Your user card",
        summary: "Style the card your friends see.",
        icon: .asset("user-circle-dashed"),
        content: .article("Your card sits at the top of the Profile tab, and it's what friends see.\n\nTo change it, scroll down and tap Edit Profile Card, then tap any part of the card: the background for its style and text color, the badges to pin favorites, the header for logo and name, and the picture for your emblem and rank progress (ring or bar).\n\nSwitch to Back at the top to pick the back's stats and style, or have it match the front. More styles are in the Shop.")
    )

    static let prsAndAchievements = HelpGuide(
        id: "prs-achievements",
        title: "Seeing PRs and achievements",
        summary: "Find your records and badges.",
        icon: .asset("medal"),
        content: .article("PRs: open the Progress tab and tap the trophy at the top right to see every personal record. The Personal records widget shows your 5 latest, and a new PR shows in gold on the summary after you finish a workout.\n\nAchievements: open the Profile tab and tap the medal at the top left to open the Achievement Book. A red number means badges you haven't opened yet. Swipe through the book by category. Secret badges are on the last page.")
    )

    static let appTheme = HelpGuide(
        id: "app-theme",
        title: "Changing the app theme",
        summary: "Colors, app icon, and font.",
        icon: .system("paintpalette"),
        content: .article("Open the Profile tab, tap the gear at the top right, then tap Theme under Appearance.\n\nTap a theme to apply it everywhere. Each theme brings its own app icon and font.\n\nGet more themes in the Shop on the Profile tab.")
    )

    static let font = HelpGuide(
        id: "font",
        title: "Changing the font",
        summary: "Use Apple's standard font.",
        icon: .system("textformat"),
        content: .article("Each theme has its own font. To use Apple's standard font instead, open Settings (the gear on the Profile tab) and turn on Use system font under Appearance. Turn it off to go back.\n\nThe workout screen always uses the standard font so your numbers line up.")
    )

    // MARK: - Lifting

    static let newWorkout = HelpGuide(
        id: "new-workout",
        title: "Starting a new workout",
        summary: "Log a workout from scratch.",
        icon: .asset("note-blank"),
        content: .demo(.newWorkout)
    )

    static let presetWorkout = HelpGuide(
        id: "preset-workout",
        title: "Starting from a preset",
        summary: "Start a workout that comes pre-filled.",
        icon: .asset("note"),
        content: .demo(.presetWorkout)
    )

    static let buildPreset = HelpGuide(
        id: "build-preset",
        title: "Building a preset",
        summary: "Save a workout template to reuse.",
        icon: .asset("hammer"),
        content: .demo(.buildPreset)
    )

    static let customExercise = HelpGuide(
        id: "custom-exercise",
        title: "Adding a custom exercise",
        summary: "Add a lift that isn't in the library.",
        icon: .system("list.bullet"),
        content: .demo(.customExercise)
    )

    static let progressWidget = HelpGuide(
        id: "progress-widget",
        title: "Adding a progress widget",
        summary: "Choose the charts on Progress.",
        icon: .asset("chart-scatter"),
        content: .article("On the Lifting side, open the Progress tab and tap the pencil at the top left, or Edit Progress at the bottom of the page.\n\nPick Workouts or Food at the top, then tap + on a widget to add it or the check to remove it. Changes save right away.\n\nFood widgets show below your workout charts. Weight trend starts off, and Daily water intake only shows while water tracking is on.")
    )

    // MARK: - Food

    static let logMeal = HelpGuide(
        id: "log-meal",
        title: "Logging a meal",
        summary: "Add food to a meal.",
        icon: .asset("scroll"),
        content: .demo(.logMeal)
    )

    static let customFood = HelpGuide(
        id: "custom-food",
        title: "Adding a custom food",
        summary: "Save a food that isn't in the database.",
        icon: .system("plus.circle"),
        content: .demo(.customFood)
    )

    static let recipe = HelpGuide(
        id: "recipe",
        title: "Making a recipe",
        summary: "Combine foods and log them as one.",
        icon: .system("list.bullet.rectangle"),
        content: .demo(.recipe)
    )
}
