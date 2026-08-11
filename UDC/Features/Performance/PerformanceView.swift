import SwiftUI

struct PerformanceView: View {
    private let accelerationRuns: [PerformanceRunResult] = [
        .init(title: "0–30", subtitle: "Launch response", elapsedTime: "2.41", elapsedUnit: "sec", symbol: "hare.fill"),
        .init(title: "0–40", subtitle: "Midrange punch", elapsedTime: "3.68", elapsedUnit: "sec", symbol: "gauge.with.needle.fill"),
        .init(title: "0–60", subtitle: "Benchmark sprint", elapsedTime: "5.92", elapsedUnit: "sec", symbol: "flag.checkered")
    ]

    private let distanceRuns: [PerformanceRunResult] = [
        .init(
            title: "1/8 Mile",
            subtitle: "Short strip",
            elapsedTime: "9.84",
            elapsedUnit: "sec",
            topSpeed: "72.4",
            topSpeedUnit: "mph",
            symbol: "road.lanes"
        ),
        .init(
            title: "1/4 Mile",
            subtitle: "Full quarter",
            elapsedTime: "15.21",
            elapsedUnit: "sec",
            topSpeed: "91.8",
            topSpeedUnit: "mph",
            symbol: "flag.checkered.2.crossed"
        )
    ]

    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    hero
                        .appearAnimation(delay: 0.02)

                    SectionHeader(
                        title: "Acceleration",
                        subtitle: "Elapsed time only"
                    )
                    .padding(.horizontal, 2)

                    LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                        ForEach(Array(accelerationRuns.enumerated()), id: \.element.id) { index, run in
                            PerformanceRunCard(
                                title: run.title,
                                subtitle: run.subtitle,
                                elapsedTime: run.elapsedTime,
                                elapsedUnit: run.elapsedUnit,
                                topSpeed: run.topSpeed,
                                topSpeedUnit: run.topSpeedUnit,
                                symbol: run.symbol,
                                delay: 0.06 + Double(index) * 0.05
                            )
                        }
                    }

                    SectionHeader(
                        title: "Distance",
                        subtitle: "Elapsed time and top speed"
                    )
                    .padding(.horizontal, 2)
                    .padding(.top, AppSpacing.xs)

                    LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                        ForEach(Array(distanceRuns.enumerated()), id: \.element.id) { index, run in
                            PerformanceRunCard(
                                title: run.title,
                                subtitle: run.subtitle,
                                elapsedTime: run.elapsedTime,
                                elapsedUnit: run.elapsedUnit,
                                topSpeed: run.topSpeed,
                                topSpeedUnit: run.topSpeedUnit,
                                symbol: run.symbol,
                                delay: 0.2 + Double(index) * 0.05
                            )
                        }
                    }

                    insightCard
                        .appearAnimation(delay: 0.34)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
            }
            .appScreenBackground()
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
        }
        .tint(Color.appAccent)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                StatusBadge(title: "Track Mode", icon: "stopwatch.fill", style: .accent)
                Spacer()
                StatusBadge(title: "GPS + IMU", icon: "gyroscope", style: .neutral)
            }

            Text("Measure what matters")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)

            Text("Acceleration and distance runs designed like a digital pit board—precise, calm, and ready when you are.")
                .font(AppTypography.secondary())
                .foregroundStyle(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: AppSpacing.sm) {
                heroStat(value: "5", label: "Tests")
                heroStat(value: "—", label: "Last Run")
                heroStat(value: "Ready", label: "Status")
            }
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

    private func heroStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(AppTypography.metric(22))
                .foregroundStyle(Color.appTextPrimary)
                .monospacedDigit()
            Text(label)
                .font(AppTypography.micro())
                .foregroundStyle(Color.appTextTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
                .fill(Color.appSurfaceInset)
        }
    }

    private var insightCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SectionHeader(title: "Session Notes")
                Text("Performance timing will use on-device motion and location data. Distance runs will capture elapsed time and top speed. Results stay private unless you choose otherwise.")
                    .font(AppTypography.secondary())
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
    }
}

/// Presentation model for a performance result.
/// Future live timing can populate `elapsedTime` and optional `topSpeed` without redesigning the cards.
struct PerformanceRunResult: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let elapsedTime: String
    let elapsedUnit: String
    let topSpeed: String?
    let topSpeedUnit: String?
    let symbol: String

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        elapsedTime: String,
        elapsedUnit: String = "sec",
        topSpeed: String? = nil,
        topSpeedUnit: String? = nil,
        symbol: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.elapsedTime = elapsedTime
        self.elapsedUnit = elapsedUnit
        self.topSpeed = topSpeed
        self.topSpeedUnit = topSpeedUnit
        self.symbol = symbol
    }

    var includesTopSpeed: Bool { topSpeed != nil }
}

#Preview {
    PerformanceView()
        .preferredColorScheme(.dark)
}
