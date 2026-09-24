import SwiftUI

// Claude  Date 08/23/2026
// The content model behind Help & Demos: a flat catalog of walkthroughs, each a
// short ordered list of steps. Data, not views — HelpGuidesView renders the list
// and HelpGuideDetailView renders one guide, so filling in the prose never means
// touching layout code.
//
// EVERY body here is deliberately nil: the step titles + icons describe the real
// navigation (verified against the screens they describe), and the prose under
// each one is Bryce's to write. A nil body renders as a visible "TODO" placeholder
// rather than an empty gap, so an unwritten step is obvious in the app instead of
// silently looking finished. Search this file for `TODO:` to find what's left.

// Claude  Date 08/23/2026
// An icon the guide points at, drawn the way the real screen draws it. The app
// mixes SF Symbols with Bryce's custom template assets (which need
// .renderingMode(.template) — the SVGs declare no template intent in their
// Contents.json, so without it they'd draw flat instead of taking the tint).
// Same split AgilTabItem.Icon makes for the tab bar; kept separate because the
// sizes here are guide-sized, not bar-sized.
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

// Claude  Date 08/23/2026
// One step of a walkthrough. `icon` is what the user should look for on screen,
// `title` is where/what to tap, `body` is the explanation — nil until written.
struct HelpGuideStep: Identifiable {
    let id = UUID()
    let icon: GuideIcon
    let title: String
    var body: String? = nil
}

struct HelpGuide: Identifiable {
    let id: String
    let title: String
    /// One-line summary shown under the title in the list. nil = TODO.
    var summary: String? = nil
    /// The icon that identifies this guide in the list.
    let icon: GuideIcon
    /// Asset-catalog name of the demo image/animation shown at the top of the
    /// guide. nil renders the "demo goes here" placeholder.
    var demoAsset: String? = nil
    /// Caption under the demo. nil = TODO.
    var demoCaption: String? = nil
    let steps: [HelpGuideStep]

    /// How many pieces of copy are still unwritten — drives the list's TODO chip.
    var todoCount: Int {
        (summary == nil ? 1 : 0)
            + (demoAsset == nil ? 1 : 0)
            + (demoCaption == nil ? 1 : 0)
            + steps.filter { $0.body == nil }.count
    }
}

// Claude  Date 08/23/2026
// A titled run of guides in the list. Sections follow the app's own shape —
// the lifting world, the food world, then the things that cut across both.
struct HelpGuideSection: Identifiable {
    let id: String
    let title: String
    let guides: [HelpGuide]
}

enum HelpGuideCatalog {
    static let sections: [HelpGuideSection] = [
        HelpGuideSection(id: "you", title: "Your profile", guides: [userCard, appTheme]),
        HelpGuideSection(id: "lifting", title: "Lifting", guides: [blankWorkout, buildPreset, customExercise]),
        HelpGuideSection(id: "food", title: "Food", guides: [customFood, recipe])
    ]

    static var all: [HelpGuide] { sections.flatMap(\.guides) }

    // MARK: - Your profile

    // TODO: bodies for every step below.
    static let userCard = HelpGuide(
        id: "user-card",
        title: "Your user card",
        icon: .asset("user-circle-dashed"),
        steps: [
            HelpGuideStep(icon: .asset("user-circle-dashed"),
                          title: "Open the Profile tab"),
            HelpGuideStep(icon: .system("rectangle.on.rectangle.angled"),
                          title: "The card fills the top of the screen"),
            HelpGuideStep(icon: .asset("wrench"),
                          title: "Scroll down and tap Edit Profile Card"),
            HelpGuideStep(icon: .system("photo"),
                          title: "Tap the background pencil to change the style"),
            HelpGuideStep(icon: .asset("medal"),
                          title: "Tap the badge pencil to pin featured badges"),
            HelpGuideStep(icon: .system("circle.dotted"),
                          title: "The ring around your emblem tracks Strategist rank"),
            HelpGuideStep(icon: .system("bag"),
                          title: "New card styles come from the Shop")
        ]
    )

    // TODO: bodies for every step below.
    static let appTheme = HelpGuide(
        id: "app-theme",
        title: "Changing the app theme",
        icon: .system("paintpalette"),
        steps: [
            HelpGuideStep(icon: .asset("user-circle-dashed"),
                          title: "Open the Profile tab"),
            HelpGuideStep(icon: .system("gearshape"),
                          title: "Tap the gear in the top-right for Settings"),
            HelpGuideStep(icon: .system("paintpalette"),
                          title: "Under Appearance, tap Theme"),
            HelpGuideStep(icon: .system("checkmark"),
                          title: "Tap a theme to apply it everywhere"),
            HelpGuideStep(icon: .system("bag"),
                          title: "Locked themes are unlocked in the Shop")
        ]
    )

    // MARK: - Lifting

    static let blankWorkout = HelpGuide(
        id: "blank-workout",
        title: "Starting a blank workout",
        icon: .asset("note-blank"),
        steps: [
            HelpGuideStep(icon: .system("dumbbell"),
                          title: "Make sure that you are on the lifting side of the app"),
            HelpGuideStep(icon: .system("dumbbell"),
                          title: "Open the Workouts tab"),
            HelpGuideStep(icon: .asset("note-blank"),
                          title: "Tap the blank-page button in the top-left"),
            HelpGuideStep(icon: .system("plus"),
                          title: "Add your first exercise"),
            HelpGuideStep(icon: .system("square.and.pencil"),
                          title: "Log weight and reps set by set"),
            HelpGuideStep(icon: .system("timer"),
                          title: "The rest timer starts when you finish a set"),
            HelpGuideStep(icon: .system("checkmark.circle"),
                          title: "Finish the workout to log it to History")
        ]
    )

    // TODO: bodies for every step below.
    static let buildPreset = HelpGuide(
        id: "build-preset",
        title: "Building a preset",
        icon: .asset("hammer"),
        steps: [
            HelpGuideStep(icon: .asset("hammer"),
                          title: "Open the Build tab"),
            HelpGuideStep(icon: .system("plus"),
                          title: "Tap + in the top-right"),
            HelpGuideStep(icon: .system("square.and.pencil"),
                          title: "Choose Blank Preset to start from scratch"),
            HelpGuideStep(icon: .system("square.stack"),
                          title: "Or Browse Premade to start from a template"),
            HelpGuideStep(icon: .system("tag"),
                          title: "Name it and pick its icon"),
            HelpGuideStep(icon: .system("plus"),
                          title: "Add exercises and set rep ranges"),
            HelpGuideStep(icon: .asset("note"),
                          title: "Start it later from the Workouts tab's preset button")
        ]
    )

    static let customExercise = HelpGuide(
        id: "custom-exercise",
        title: "Adding a custom exercise",
        icon: .system("list.bullet"),
        steps: [
            HelpGuideStep(icon: .asset("hammer"),
                          title: "Open the Build tab"),
            HelpGuideStep(icon: .system("list.bullet"),
                          title: "Tap Exercises in the top-left"),
            HelpGuideStep(icon: .system("plus"),
                          title: "Tap + in the top-right"),
            HelpGuideStep(icon: .system("character.cursor.ibeam"),
                          title: "Name the lift and pick its body region"),
            HelpGuideStep(icon: .system("wrench.and.screwdriver"),
                          title: "Pick the equipment it uses"),
            HelpGuideStep(icon: .system("tag"),
                          title: "Long-press a lift to add a brand variant, these can be whatever you want (example, brand or place)"),
            HelpGuideStep(icon: .system("pencil"),
                          title: "Swipe a lift to edit or delete it")
        ]
    )

    // MARK: - Food

    static let customFood = HelpGuide(
        id: "custom-food",
        title: "Adding a custom food",
        icon: .system("plus.circle"),
        steps: [
            HelpGuideStep(icon: .asset("bowl-food"),
                          title: "Tap the notch at the top to switch to Food"),
            HelpGuideStep(icon: .asset("orange"),
                          title: "Open the Foods tab"),
            HelpGuideStep(icon: .system("plus"),
                          title: "Tap + in the top right"),
            HelpGuideStep(icon: .system("plus.circle"),
                          title: "Choose Create custom food"),
            HelpGuideStep(icon: .asset("barcode"),
                          title: "Or scan a barcode to fill it in for you"),
            HelpGuideStep(icon: .system("chart.pie"),
                          title: "Enter the serving size and macros"),
            HelpGuideStep(icon: .asset("scroll"),
                          title: "It's now searchable from Log. You can also send it to our team for review to be added to the public database")
        ]
    )

    static let recipe = HelpGuide(
        id: "recipe",
        title: "Making a recipe",
        icon: .system("list.bullet.rectangle"),
        steps: [
            HelpGuideStep(icon: .asset("orange"),
                          title: "Open the Foods tab"),
            HelpGuideStep(icon: .system("plus"),
                          title: "Tap + in the top-right"),
            HelpGuideStep(icon: .system("list.bullet.rectangle"),
                          title: "Choose Create recipe"),
            HelpGuideStep(icon: .system("plus"),
                          title: "Add each ingredient and its amount"),
            HelpGuideStep(icon: .system("divide"),
                          title: "Set how many servings it makes"),
            HelpGuideStep(icon: .system("chart.pie"),
                          title: "Macros per serving are worked out for you"),
            HelpGuideStep(icon: .asset("scroll"),
                          title: "Log a serving from the Log tab like any other food")
        ]
    )
}
