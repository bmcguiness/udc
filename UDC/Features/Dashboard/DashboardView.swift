import SwiftUI

struct DashboardView: View {
    private let staticData = DashboardPreviewData.sample

    @State private var displayedSpeed: Double = DashboardPreviewData.sample.speed
#if DEBUG
    @State private var demoTask: Task<Void, Never>?
#endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    DashboardHeader(
                        vehicleName: staticData.vehicleName,
                        statusTitle: staticData.driveStatus,
                        statusStyle: .success,
                        statusIcon: "waveform.path.ecg"
                    )
                    .appearAnimation(delay: 0.02)

                    speedCluster
                        .appearAnimation(delay: 0.06)

                    HStack(spacing: AppSpacing.sm) {
                        DashboardMetric(title: "RPM", value: staticData.rpmText, symbol: "gauge.with.needle.fill")
                        DashboardMetric(title: "Trip", value: staticData.trip, symbol: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                    .appearAnimation(delay: 0.12)

                    HStack(spacing: AppSpacing.sm) {
                        DashboardMetric(title: "Drive Time", value: staticData.duration, symbol: "timer")
                        DashboardMetric(title: "Avg Speed", value: staticData.avgSpeed, symbol: "speedometer")
                    }
                    .appearAnimation(delay: 0.16)

                    statusCard
                        .appearAnimation(delay: 0.2)

                    PrimaryButton(title: "Start Drive", symbol: "play.fill") { }
                        .appearAnimation(delay: 0.24)
                        .padding(.top, AppSpacing.xs)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
            }
            .appScreenBackground()
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
#if DEBUG
            .onAppear { startDebugSpeedDemoIfNeeded() }
            .onDisappear {
                demoTask?.cancel()
                demoTask = nil
            }
#endif
        }
        .tint(Color.appAccent)
    }

    private var speedCluster: some View {
        VStack(spacing: AppSpacing.md) {
            Text("CURRENT SPEED")
                .font(AppTypography.micro())
                .foregroundStyle(Color.appTextTertiary)
                .tracking(1.4)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(Int(displayedSpeed.rounded()))")
                    .font(AppTypography.display(104))
                    .foregroundStyle(Color.appTextPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)
                    .animation(AppMotion.emphasize, value: Int(displayedSpeed.rounded()))
                Text(staticData.speedUnit.uppercased())
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.appAccentMuted)
                    .tracking(1.2)
                    .padding(.bottom, 18)
            }

            SpeedBand(speed: displayedSpeed, maximum: 120)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, 2)
                .animation(.easeInOut(duration: 0.85), value: displayedSpeed)

            HStack(spacing: AppSpacing.xs) {
                StatusBadge(title: staticData.source, icon: "antenna.radiowaves.left.and.right", style: .accent)
                StatusBadge(title: staticData.precision, icon: "location.fill", style: .neutral)
            }
            .padding(.top, AppSpacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
        .padding(.horizontal, AppSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: AppCornerRadius.xl, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: AppShadow.elevated.color, radius: AppShadow.elevated.radius, y: AppShadow.elevated.y)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.xl, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.appAccentMuted.opacity(0.28),
                            Color.appBorder,
                            Color.appBorder
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current speed \(Int(displayedSpeed.rounded())) \(staticData.speedUnit), \(staticData.source)")
    }

    private var statusCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SectionHeader(title: "Session", subtitle: "Live drive telemetry")
                InfoRow(title: "Drive Status", value: staticData.driveStatus, symbol: "checkmark.seal.fill")
                InfoRow(title: "Data Source", value: staticData.source, symbol: "dot.radiowaves.left.and.right")
                InfoRow(title: "Signal", value: staticData.signal, symbol: "location.north.circle.fill", showsDivider: false)
            }
        }
    }

#if DEBUG
    private func startDebugSpeedDemoIfNeeded() {
        guard demoTask == nil else { return }
        // Invisible development sequence so the SpeedBand can be evaluated without a production control.
        let sequence: [Double] = [0, 25, 47, 65, 35, 0]
        demoTask = Task { @MainActor in
            var index = 0
            while !Task.isCancelled {
                let target = sequence[index % sequence.count]
                withAnimation(.easeInOut(duration: 1.15)) {
                    displayedSpeed = target
                }
                index += 1
                try? await Task.sleep(nanoseconds: 1_600_000_000)
            }
        }
    }
#endif
}

private struct DashboardPreviewData {
    let vehicleName: String
    let speed: Double
    let speedUnit: String
    let rpmText: String
    let trip: String
    let duration: String
    let avgSpeed: String
    let source: String
    let precision: String
    let driveStatus: String
    let signal: String

    static let sample = Self(
        vehicleName: "1967 Mustang",
        speed: 47,
        speedUnit: "mph",
        rpmText: "2,840",
        trip: "18.6 mi",
        duration: "00:24:18",
        avgSpeed: "32 mph",
        source: "Manual Driveline",
        precision: "GPS Ready",
        driveStatus: "Armed",
        signal: "Excellent"
    )
}

#Preview {
    DashboardView()
        .preferredColorScheme(.dark)
}
