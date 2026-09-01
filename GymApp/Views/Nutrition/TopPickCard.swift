import SwiftUI

// Claude  Date 08/22/2026
// One card in the Foods tab's "Top picks" row — a food the user actually eats around
// this hour (see AppStore.topPicks for how it earns its place).
//
// Wider and taller than a chip on purpose. A bare name is not enough to pick between
// "greek yogurt" and "greek yogurt · fage 0%" at a glance, so the card carries the four
// things that identify a food: where the record came from (the same icon-only badge the
// list rows use), its name, its brand, and what a serving costs. Calories are pinned to
// the bottom edge and the card height is fixed, so a one-line and a two-line name still
// line their numbers up across the row.
struct TopPickCard: View {
    let food: FoodItem
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                FoodSourceBadge(source: FoodTrust(food.source),
                                verification: food.verification,
                                style: .row)
                Spacer(minLength: 0)
            }
            Text(food.displayName)
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            // Brands are frequently empty (recipes, generic staples). Drawing nothing
            // rather than a blank line lets the name take the space instead.
            if !brand.isEmpty {
                Text(brand)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            Text("\(Int(food.nutrients.calories.rounded())) kcal")
                .font(.caption).fontWeight(.semibold).monospacedDigit()
                .foregroundStyle(accent)
        }
        .frame(width: 148, height: 108, alignment: .topLeading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.quaternary.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        // The badge is icon-only here, so its meaning would be lost to VoiceOver on a
        // per-element read. One combined label per card instead.
        .accessibilityElement(children: .combine)
    }

    private var brand: String {
        food.displayBrand.trimmingCharacters(in: .whitespaces)
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 10) {
            TopPickCard(food: FoodItem(name: "Greek Yogurt, Plain", brand: "Fage 0%",
                                       servingSize: 170, servingUnit: "g",
                                       nutrients: Nutrients(calories: 120, protein: 20,
                                                            carbs: 7, fat: 0),
                                       source: .openFoodFacts, verification: .verified),
                        accent: .pink)
            TopPickCard(food: FoodItem(name: "Chicken Breast", servingSize: 100,
                                       servingUnit: "g",
                                       nutrients: Nutrients(calories: 165, protein: 31,
                                                            carbs: 0, fat: 3.6),
                                       source: .usda, verification: .unverified),
                        accent: .pink)
        }
        .padding()
    }
}
