import SwiftUI

struct FuelView: View {
    private let cards: [FuelCardModel] = [
        .init(title: "Fuel Economy", detail: "Rolling average MPG", value: "24.8", symbol: "chart.line.uptrend.xyaxis"),
        .init(title: "Fill-Ups", detail: "Logged this month", value: "3", symbol: "fuelpump.fill"),
        .init(title: "Fuel Cost", detail: "Spend this month", value: "$142", symbol: "dollarsign.circle.fill"),
        .init(title: "Gas911", detail: "Nearby stations", value: "—", symbol: "mappin.and.ellipse")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                hero
                    .appearAnimation(delay: 0.02)

                SectionHeader(title: "Overview", subtitle: "Placeholder insights")

                VStack(spacing: AppSpacing.md) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        FuelFeatureCard(
                            title: card.title,
                            detail: card.detail,
                            value: card.value,
                            symbol: card.symbol,
                            delay: 0.08 + Double(index) * 0.05
                        )
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        SectionHeader(title: "Coming Online")
                        Text("Fill-up history, cost tracking, and Gas911 station discovery will live here—designed for quick glances between drives.")
                            .font(AppTypography.secondary())
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
                .appearAnimation(delay: 0.3)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .appScreenBackground()
        .navigationTitle("Fuel")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .tint(Color.appAccent)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            StatusBadge(title: "Economy", icon: "leaf.fill", style: .success)

            Text("Know every gallon")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)

            Text("Track economy, cost, and fill-ups with the same quiet precision as the instrument cluster.")
                .font(AppTypography.secondary())
                .foregroundStyle(Color.appTextSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("24.8")
                    .font(AppTypography.display(56))
                    .foregroundStyle(Color.appTextPrimary)
                    .monospacedDigit()
                Text("mpg")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.bottom, 8)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Fuel economy 24.8 miles per gallon")
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: AppCornerRadius.xl, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: AppShadow.elevated.color, radius: AppShadow.elevated.radius, y: AppShadow.elevated.y)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.xl, style: .continuous)
                .strokeBorder(Color.appBorder, lineWidth: 0.5)
        }
    }
}

private struct FuelCardModel: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let value: String
    let symbol: String
}

#Preview {
    NavigationStack {
        FuelView()
    }
    .preferredColorScheme(.dark)
}
