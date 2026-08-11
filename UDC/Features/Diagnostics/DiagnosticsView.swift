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
