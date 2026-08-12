import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(DrivingTelemetryService.self) private var telemetry
    @Environment(DrivingEngine.self) private var drivingEngine
    @Environment(PerformanceEngine.self) private var performanceEngine
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]

    private var activeVehicle: VehicleProfile? {
        vehicles.first(where: \.isActive) ?? vehicles.first
    }

    private var state: DrivingState { telemetry.state }
    private var session: DrivingEngineSnapshot { drivingEngine.snapshot }
    private var liveTrip: LiveTrip? { session.liveTrip }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    DashboardHeader(
                        vehicleName: activeVehicle?.name ?? "No Vehicle",
                        statusTitle: headerStatusTitle,
                        statusStyle: headerStatusStyle,
                        statusIcon: headerStatusIcon
                    )
                    .appearAnimation(delay: 0.02)

                    speedCluster
                        .appearAnimation(delay: 0.06)

                    tripMetricsGrid
                        .appearAnimation(delay: 0.1)

                    sessionCard
                        .appearAnimation(delay: 0.14)

                    statusCard
                        .appearAnimation(delay: 0.18)

                    permissionOrWaitingCard
                        .appearAnimation(delay: 0.22)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
            }
            .appScreenBackground()
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .onAppear {
                drivingEngine.attach(modelContext: modelContext)
                performanceEngine.attach(modelContext: modelContext)
                syncVehiclePreferences()
                telemetry.start()
            }
            .onChange(of: activeVehicle?.id) { _, _ in syncVehiclePreferences() }
            .onChange(of: activeVehicle?.preferredSpeedUnit) { _, _ in syncVehiclePreferences() }
            .onChange(of: activeVehicle?.preferredDistanceUnit) { _, _ in syncVehiclePreferences() }
        }
        .tint(Color.appAccent)
    }

    private var displayedSpeed: Double { state.displayedSpeed }

    private var speedUnitLabel: String { state.preferredSpeedUnit.rawValue }

    private var distanceUnit: DistanceUnit {
        activeVehicle?.preferredDistanceUnit ?? .miles
    }

    private var headerStatusTitle: String {
        if session.phase != .idle {
            return session.phase.displayName
        }
        switch state.gpsStatus {
        case .ready: return state.isMoving ? "Live" : "Ready"
        case .searching: return "Searching"
        case .poorSignal: return "Weak Signal"
        case .permissionNeeded: return "Permission"
        case .locationDisabled: return "Disabled"
        case .unavailable: return "Unavailable"
        }
    }

    private var headerStatusStyle: StatusBadge.Style {
        switch session.phase {
        case .driving: .success
        case .preparing: .accent
        case .stopped: .warning
        case .idle: gpsBadgeStyle(state.gpsStatus)
        }
    }

    private var headerStatusIcon: String {
        switch session.phase {
        case .driving: "car.fill"
        case .preparing: "hare.fill"
        case .stopped: "pause.fill"
        case .idle: gpsBadgeSymbol(state.gpsStatus)
        }
    }

    private var speedCluster: some View {
        VStack(spacing: AppSpacing.md) {
            Text("CURRENT SPEED")
                .font(AppTypography.micro())
                .foregroundStyle(Color.appTextTertiary)
                .tracking(1.4)

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(speedReadout)
                    .font(AppTypography.display(104))
                    .foregroundStyle(Color.appTextPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)
                    .animation(AppMotion.emphasize, value: speedReadout)
                Text(speedUnitLabel.uppercased())
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.appAccentMuted)
                    .tracking(1.2)
                    .padding(.bottom, 18)
            }

            SpeedBand(
                speed: max(displayedSpeed, 0),
                maximum: state.preferredSpeedUnit.speedBandMaximum
            )
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, 2)
            .animation(.easeInOut(duration: 0.35), value: displayedSpeed)

            HStack(spacing: AppSpacing.xs) {
                StatusBadge(
                    title: session.phase.displayName,
                    icon: headerStatusIcon,
                    style: headerStatusStyle
                )
                StatusBadge(
                    title: state.gpsStatus.badgeTitle,
                    icon: gpsBadgeSymbol(state.gpsStatus),
                    style: gpsBadgeStyle(state.gpsStatus)
                )
                if performanceEngine.snapshot.phase == .running || performanceEngine.snapshot.phase == .armed {
                    StatusBadge(
                        title: performanceEngine.snapshot.phase == .running ? "Perf" : "Armed",
                        icon: "stopwatch",
                        style: performanceEngine.snapshot.phase == .running ? .success : .accent
                    )
                }
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
        .accessibilityLabel(accessibilitySpeedLabel)
    }

    private var tripMetricsGrid: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                DashboardMetric(
                    title: "Trip",
                    value: tripDistanceText,
                    symbol: "point.topleft.down.to.point.bottomright.curvepath"
                )
                DashboardMetric(
                    title: "Drive Time",
                    value: tripDurationText,
                    symbol: "timer"
                )
            }
            HStack(spacing: AppSpacing.sm) {
                DashboardMetric(
                    title: "Avg Speed",
                    value: averageSpeedText,
                    symbol: "speedometer"
                )
                DashboardMetric(
                    title: "Max Speed",
                    value: maxSpeedText,
                    symbol: "gauge.with.needle.fill"
                )
            }
        }
    }

    private var sessionCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SectionHeader(title: "Session", subtitle: sessionSubtitle)
                InfoRow(title: "Status", value: session.phase.displayName, symbol: "car.side")
                InfoRow(title: "Vehicle", value: activeVehicle?.name ?? "—", symbol: "car.fill")
                InfoRow(
                    title: "Started",
                    value: liveTrip.map { $0.startedAt.formatted(date: .omitted, time: .shortened) } ?? "—",
                    symbol: "clock",
                    showsDivider: false
                )
            }
        }
    }

    private var sessionSubtitle: String {
        switch session.phase {
        case .idle: "Waiting for meaningful movement"
        case .preparing: "Confirming a drive has begun"
        case .driving: "Recording trip statistics"
        case .stopped: "Paused — will end after an extended stop"
        }
    }

    private var tripDistanceText: String {
        guard let trip = liveTrip else { return "—" }
        let value = distanceUnit.value(fromMeters: trip.distanceMeters)
        return String(format: "%.1f %@", value, distanceUnit.rawValue)
    }

    private var tripDurationText: String {
        guard let trip = liveTrip else { return "—" }
        return formatDuration(trip.duration())
    }

    private var averageSpeedText: String {
        guard let trip = liveTrip else { return "—" }
        let value = state.preferredSpeedUnit.value(fromMetersPerSecond: trip.averageSpeedMetersPerSecond())
        return String(format: "%.0f %@", value, state.preferredSpeedUnit.rawValue)
    }

    private var maxSpeedText: String {
        guard let trip = liveTrip else { return "—" }
        let value = state.preferredSpeedUnit.value(fromMetersPerSecond: trip.maximumSpeedMetersPerSecond)
        return String(format: "%.0f %@", value, state.preferredSpeedUnit.rawValue)
    }

    private var speedReadout: String {
        guard canShowLiveSpeed else { return "—" }
        return "\(Int(displayedSpeed.rounded()))"
    }

    private var canShowLiveSpeed: Bool {
        switch state.gpsStatus {
        case .ready, .poorSignal, .searching:
            state.authorizationStatus.allowsLocationUpdates
        case .permissionNeeded, .locationDisabled, .unavailable:
            false
        }
    }

    private var accessibilitySpeedLabel: String {
        if canShowLiveSpeed {
            "Current speed \(Int(displayedSpeed.rounded())) \(speedUnitLabel), \(session.phase.displayName), \(state.gpsStatus.badgeTitle)"
        } else {
            "Speed unavailable, \(state.gpsStatus.badgeTitle)"
        }
    }

    private var statusCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SectionHeader(title: "Signal", subtitle: "Live GPS telemetry")
                InfoRow(
                    title: "GPS Status",
                    value: state.gpsStatus.badgeTitle,
                    symbol: gpsBadgeSymbol(state.gpsStatus)
                )
                InfoRow(
                    title: "Speed Source",
                    value: state.speedSource.displayName,
                    symbol: "dot.radiowaves.left.and.right"
                )
                InfoRow(
                    title: "Accuracy",
                    value: accuracyText,
                    symbol: "scope",
                    showsDivider: false
                )
            }
        }
    }

    private var accuracyText: String {
        guard let meters = state.horizontalAccuracyMeters, meters >= 0 else { return "—" }
        if state.preferredSpeedUnit == .kilometersPerHour {
            return String(format: "±%.0f m", meters)
        }
        let feet = meters * 3.28084
        return String(format: "±%.0f ft", feet)
    }

    @ViewBuilder
    private var permissionOrWaitingCard: some View {
        switch state.gpsStatus {
        case .permissionNeeded:
            AppCard(elevated: true) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    StatusBadge(title: "Location", icon: "location.fill", style: .warning)
                    Text(permissionTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                    Text(permissionMessage)
                        .font(AppTypography.secondary())
                        .foregroundStyle(Color.appTextSecondary)

                    if state.authorizationStatus == .notDetermined {
                        PrimaryButton(title: "Enable Location", symbol: "location.fill") {
                            telemetry.requestPermission()
                        }
                    } else {
                        PrimaryButton(title: "Open Settings", symbol: "gearshape") {
                            openSystemSettings()
                        }
                    }
                }
            }
        case .locationDisabled:
            AppCard(elevated: true) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    StatusBadge(title: "Disabled", icon: "location.slash.fill", style: .warning)
                    Text("Location Services are off")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                    Text("Turn on Location Services in iOS Settings to show live speed.")
                        .font(AppTypography.secondary())
                        .foregroundStyle(Color.appTextSecondary)
                    PrimaryButton(title: "Open Settings", symbol: "gearshape") {
                        openSystemSettings()
                    }
                }
            }
        case .searching:
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeader(title: "Acquiring Fix")
                    Text("Waiting for a reliable GPS signal. Move outdoors if the search continues.")
                        .font(AppTypography.secondary())
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        case .ready, .poorSignal, .unavailable:
            EmptyView()
        }
    }

    private var permissionTitle: String {
        switch state.authorizationStatus {
        case .notDetermined: "Allow location for live speed"
        case .denied, .restricted: "Location permission needed"
        default: "Location permission needed"
        }
    }

    private var permissionMessage: String {
        switch state.authorizationStatus {
        case .notDetermined:
            "UDC uses your location while you use the app to display live driving speed. Data stays on your device."
        case .denied, .restricted:
            "Location access is turned off for UDC. Enable it in Settings to drive the live dashboard."
        default:
            "Enable location access to show live speed."
        }
    }

    private func syncVehiclePreferences() {
        telemetry.updateActiveVehicle(
            name: activeVehicle?.name,
            speedUnit: activeVehicle?.preferredSpeedUnit ?? .milesPerHour
        )
        drivingEngine.updateActiveVehicle(
            id: activeVehicle?.id,
            name: activeVehicle?.name,
            speedUnit: activeVehicle?.preferredSpeedUnit ?? .milesPerHour,
            distanceUnit: activeVehicle?.preferredDistanceUnit ?? .miles
        )
        performanceEngine.updateActiveVehicle(
            id: activeVehicle?.id,
            name: activeVehicle?.name,
            speedUnit: activeVehicle?.preferredSpeedUnit ?? .milesPerHour,
            distanceUnit: activeVehicle?.preferredDistanceUnit ?? .miles,
            bestsJSON: activeVehicle?.performanceBestsJSON
        )
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func gpsBadgeStyle(_ status: GPSStatus) -> StatusBadge.Style {
        switch status {
        case .ready: .success
        case .searching: .accent
        case .poorSignal, .unavailable: .warning
        case .permissionNeeded, .locationDisabled: .neutral
        }
    }

    private func gpsBadgeSymbol(_ status: GPSStatus) -> String {
        switch status {
        case .permissionNeeded: "hand.raised.fill"
        case .locationDisabled: "location.slash.fill"
        case .searching: "location.magnifyingglass"
        case .poorSignal: "location.north.circle"
        case .ready: "location.fill"
        case .unavailable: "exclamationmark.triangle.fill"
        }
    }
}

#Preview("Live mock") {
    let provider = NoOpLocationProvider()
    provider.setAuthorization(.authorizedWhenInUse)
    let telemetry = DrivingTelemetryService(locationProvider: provider)
    let engine = DrivingEngine(telemetry: telemetry)
    let performance = PerformanceEngine(telemetry: telemetry, drivingEngine: engine)
    return DashboardView()
        .environment(telemetry)
        .environment(engine)
        .environment(performance)
        .modelContainer(for: [VehicleProfile.self, DriveRecord.self], inMemory: true)
        .preferredColorScheme(.dark)
}
