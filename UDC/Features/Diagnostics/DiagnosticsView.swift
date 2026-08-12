import SwiftUI

struct DiagnosticsView: View {
    @Environment(DrivingTelemetryService.self) private var telemetry

    private var diagnostics: DrivingDiagnostics { telemetry.diagnostics }
    private var state: DrivingState { telemetry.state }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Development diagnostics for live GPS. Not shown in normal navigation.")
                    .font(AppTypography.secondary())
                    .foregroundStyle(Color.appTextSecondary)

                diagnosticsCard(title: "Authorization & Status") {
                    row("Authorization", diagnostics.authorizationStatus.displayName)
                    row("Location Services", diagnostics.isLocationServicesEnabled ? "Enabled" : "Disabled")
                    row("GPS Status", diagnostics.gpsStatus.badgeTitle)
                    row("Speed Source", diagnostics.speedSource.displayName)
                    row("Moving", diagnostics.isMoving ? "Yes" : "No", showsDivider: false)
                }

                diagnosticsCard(title: "Position") {
                    row("Latitude", format(diagnostics.latitude, digits: 6))
                    row("Longitude", format(diagnostics.longitude, digits: 6))
                    row("Horizontal Accuracy", meters(diagnostics.horizontalAccuracyMeters))
                    row("Vertical Accuracy", meters(diagnostics.verticalAccuracyMeters))
                    row("Heading", degrees(diagnostics.headingDegrees))
                    row("Heading Accuracy", degrees(diagnostics.headingAccuracyDegrees), showsDivider: false)
                }

                diagnosticsCard(title: "Speed Pipeline") {
                    row("Raw GPS Speed", mps(diagnostics.rawSpeedMetersPerSecond))
                    row("Filtered Speed", mps(diagnostics.filteredSpeedMetersPerSecond))
                    row("Displayed Speed", displaySpeed(diagnostics.displayedSpeed, unit: diagnostics.preferredSpeedUnit))
                    row("Filter Rejection", diagnostics.filterRejection ?? "—", showsDivider: false)
                }

                diagnosticsCard(title: "Timing") {
                    row("Timestamp", timestamp(diagnostics.timestamp))
                    row("Location Age", age(diagnostics.locationAgeSeconds), showsDivider: false)
                }

                diagnosticsCard(title: "Vehicle") {
                    row("Active Vehicle", diagnostics.activeVehicleName ?? "—")
                    row("Current Units", diagnostics.preferredSpeedUnit.settingsLabel, showsDivider: false)
                }

                diagnosticsCard(title: "Session") {
                    row("Session State", diagnostics.sessionPhase.displayName)
                    row("Trip ID", diagnostics.tripID?.uuidString ?? "—")
                    row("Session Start", timestamp(diagnostics.sessionStartedAt))
                    row("Distance", meters(diagnostics.sessionDistanceMeters))
                    row("Drive Time", age(diagnostics.sessionDurationSeconds))
                    row("Average Speed", mps(diagnostics.sessionAverageSpeedMetersPerSecond))
                    row("Maximum Speed", mps(diagnostics.sessionMaximumSpeedMetersPerSecond))
                    row("Start Reason", diagnostics.sessionStartReason?.rawValue ?? "—")
                    row("End Reason", diagnostics.sessionEndReason?.rawValue ?? "—")
                    row(
                        "Movement Threshold",
                        String(format: "%.2f m/s", diagnostics.movementThresholdMetersPerSecond),
                        showsDivider: false
                    )
                }

                diagnosticsCard(title: "Sample Counts") {
                    row("GPS Samples", "\(diagnostics.gpsSampleCount)")
                    row("Accepted Samples", "\(diagnostics.acceptedSampleCount)")
                    row("Rejected Samples", "\(diagnostics.rejectedSampleCount)", showsDivider: false)
                }

                diagnosticsCard(title: "Performance") {
                    row("Performance State", diagnostics.performancePhase.displayName)
                    row("Launch Detected", diagnostics.performanceLaunchDetected ? "Yes" : "No")
                    row("Distance", meters(diagnostics.performanceDistanceMeters))
                    row("Elapsed", age(diagnostics.performanceElapsedSeconds))
                    row("30 Reached", diagnostics.performanceReached30 ? "Yes" : "No")
                    row("40 Reached", diagnostics.performanceReached40 ? "Yes" : "No")
                    row("60 Reached", diagnostics.performanceReached60 ? "Yes" : "No")
                    row("1/8 Reached", diagnostics.performanceReachedEighth ? "Yes" : "No")
                    row("1/4 Reached", diagnostics.performanceReachedQuarter ? "Yes" : "No")
                    row("GPS Quality", diagnostics.performanceGPSQualityReady ? "Ready" : "Not ready")
                    row("Run Valid", diagnostics.performanceRunValid ? "Yes" : "No")
                    row(
                        "Cancel Reason",
                        diagnostics.performanceCancelReason?.rawValue ?? "—",
                        showsDivider: false
                    )
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .appScreenBackground()
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .tint(Color.appAccent)
    }

    private func diagnosticsCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: title)
            AppCard {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    private func row(_ title: String, _ value: String, showsDivider: Bool = true) -> some View {
        InfoRow(title: title, value: value, showsDivider: showsDivider)
    }

    private func format(_ value: Double?, digits: Int) -> String {
        guard let value else { return "—" }
        return String(format: "%.\(digits)f", value)
    }

    private func meters(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value < 0 { return "Invalid" }
        return String(format: "%.1f m", value)
    }

    private func degrees(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f°", value)
    }

    private func mps(_ value: Double?) -> String {
        guard let value else { return "—" }
        let mph = SpeedUnit.milesPerHour.value(fromMetersPerSecond: value)
        return String(format: "%.2f m/s (%.1f mph)", value, mph)
    }

    private func displaySpeed(_ value: Double, unit: SpeedUnit) -> String {
        String(format: "%.2f %@", value, unit.rawValue)
    }

    private func timestamp(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .omitted, time: .standard)
    }

    private func age(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "—" }
        return String(format: "%.2f s", seconds)
    }
}

#Preview {
    NavigationStack {
        DiagnosticsView()
            .environment(DrivingTelemetryService(locationProvider: NoOpLocationProvider()))
    }
    .preferredColorScheme(.dark)
}
