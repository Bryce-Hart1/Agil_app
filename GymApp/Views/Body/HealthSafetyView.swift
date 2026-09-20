import SwiftUI

// CLAUDE  Date 09/19/2026
// The health and safety page: what the plan is, what it isn't, who shouldn't use it, the limits
// it keeps to, and where the data lives. Reachable from the consent step, the plan hub and
// Settings → Help & About, so a user can always re-read what they agreed to.
//
// CLAUDE  Date 09/20/2026 — the formula walkthrough that used to sit here is gone (Bryce,
// 9/20/26): how the estimate is derived is Agil's business, not something to hand the user.
// What stays is the part that is their business — that these are estimates, who shouldn't rely
// on them, and the limits the app won't cross.
//
// TODO: CLAUDE  Date 09/19/2026 — before release, have the wording reviewed, confirm the two
// support links still resolve, and pair this with a Terms of Use and Privacy Policy (the App
// Store requires a privacy policy URL and Agil has none yet).
struct HealthSafetyView: View {
    @EnvironmentObject private var theme: ThemeManager

    private var accent: Color { theme.current.accent }

    var body: some View {
        List {
            Section {
                Text("Agil's calorie plan is a general fitness tool, not medical or nutrition advice. It isn't a medical device, and it isn't intended to diagnose, treat, cure or prevent any condition.")
                Text("Talk to a doctor or a registered dietitian before making a big change to how you eat — especially if you have a medical condition, take medication that affects your weight or appetite, or have any history of disordered eating.")
            } header: {
                Text("This isn't medical advice")
            }

            Section {
                Text("Your starting numbers come from population formulas. For any one person they can be off by 10–20%, which is why the weekly check-in exists: it corrects them from your own results.")
                Text("The check-in is only as good as what you log. The more consistently you weigh in and log your food, the closer it gets.")
                Text("Body-fat estimates from scales, calipers and photos are rough. They're useful for tracking a direction, not for a number you should take literally.")
            } header: {
                Text("These are estimates")
            }

            Section {
                bullet("Under 18")
                bullet("Pregnant or breastfeeding")
                bullet("A current or past eating disorder")
                bullet("Diabetes, kidney, heart or thyroid conditions")
                bullet("Medication that affects weight or appetite, such as insulin or a GLP-1")
                bullet("Recovering from surgery or a serious illness")
            } header: {
                Text("Talk to a professional first if any of these apply")
            } footer: {
                Text("Agil can't account for any of these, and a general formula is the wrong tool for them.")
            }

            Section {
                Text("Dizziness, fainting, or feeling cold all the time")
                Text("Periods becoming irregular or stopping")
                Text("Thoughts about food, weight or training that feel hard to put down")
                Text("Losing weight much faster than your plan intends")
            } header: {
                Text("Stop and get help if you notice")
            } footer: {
                Text("None of these are a normal price for progress.")
            }

            limitsSection
            privacySection
            supportSection
        }
        .navigationTitle("Health & safety")
        .navigationBarTitleDisplayMode(.inline)
        .themed(theme.current)
    }

    private var limitsSection: some View {
        Section {
            bullet("Plans are for adults 18 and over")
            bullet("Never below your estimated resting burn, and never below \(Int(BodySafety.sexCalorieFloor(.female)))–\(Int(BodySafety.sexCalorieFloor(.male))) kcal depending on your details")
            bullet("At most 1% of your bodyweight lost per week")
            bullet("At most 1.5% of your bodyweight gained per month")
            bullet("No body-fat goals below \(Int(BodySafety.targetBodyFatFloor(.male)))% for men or \(Int(BodySafety.targetBodyFatFloor(.female)))% for women — contest prep isn't something Agil plans")
            bullet("No goal below a BMI of \(String(format: "%.1f", BodySafety.minimumBMI))")
            bullet("At most \(Int(BodySafety.maxCheckInAdjustment)) kcal of change per check-in, and none at all for the first two weeks of a phase")
            bullet("If you're losing too fast, your calories go up — never down")
        } header: {
            Text("The limits Agil enforces")
        } footer: {
            Text("These are deliberately cautious. A plan that's a little slow costs you a week; one that's too aggressive costs you muscle.")
        }
    }

    private var privacySection: some View {
        Section {
            Text("Your weight, body details and plan are stored only on this iPhone, encrypted.")
            Text("They are never sent to Agil's servers, shown to friends, or put on the home-screen widget. Only an encrypted iPhone backup can carry them to a new phone.")
            Text("You can erase all of it at any time in Settings → Body & Plan.")
        } header: {
            Text("Where your data lives")
        }
    }

    private var supportSection: some View {
        Section {
            Link(destination: URL(string: "https://www.nationaleatingdisorders.org/get-help/")!) {
                Label("National Eating Disorders Association", systemImage: "heart.text.square")
            }
            Link(destination: URL(string: "https://anad.org/get-help/")!) {
                Label("ANAD — free peer support and helpline", systemImage: "phone")
            }
        } header: {
            Text("If food or weight stops feeling okay")
        } footer: {
            Text("Wanting help early isn't an overreaction. These are free and confidential.")
        }
        .tint(accent)
    }

    private func bullet(_ text: String) -> some View {
        Label(text, systemImage: "circle.fill")
            .labelStyle(BulletLabelStyle(accent: accent))
    }

}

// CLAUDE  Date 09/19/2026
// A small accent dot instead of a bullet character, so lists here match the tinted-icon look
// the rest of the app uses without shouting with a full SF Symbol.
private struct BulletLabelStyle: LabelStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
            configuration.title
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
    }
}

#Preview {
    NavigationStack { HealthSafetyView() }
        .environmentObject(ThemeManager())
}
