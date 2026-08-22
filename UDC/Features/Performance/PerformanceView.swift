import SwiftData
import SwiftUI

struct PerformanceView: View {
    @Environment(PerformanceEngine.self) private var performanceEngine
    @Environment(DrivingEngine.self) private var drivingEngine
    @Environment(DrivingTelemetryService.self) private var telemetry
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]
    @Query(
        filter: #Predicate<DriveRecord> { $0.isInProgress == false },
        sort: \DriveRecord.endedAt,
        order: .reverse
    ) private var drives: [DriveRecord]

    private var activeVehicle: VehicleProfile? {
        vehicles.first(where: \.isActive) ?? vehicles.first
    }

    private var speedUnit: SpeedUnit {
        activeVehicle?.preferredSpeedUnit ?? .milesPerHour
    }

    private var distanceUnit: DistanceUnit {
        activeVehicle?.preferredDistanceUnit ?? .miles
    }

    private var snap: PerformanceEngineSnapshot { performanceEngine.snapshot }
    private var bests: PerformanceBests { performanceEngine.bests }

    private var historyRuns: [PerformanceRunSummary] {
        var runs = drives.flatMap(\.performanceRuns).filter(\.isValid)
        let persistedIDs = Set(runs.map(\.id))
        let recent = performanceEngine.recentRuns.filter { $0.isValid && !persistedIDs.contains($0.id) }
        runs.append(contentsOf: recent)
        return runs.sorted { $0.launchedAt > $1.launchedAt }
    }

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

                    if let message = statusMessage {
                        AppCard {
                            Text(message)
                                .font(AppTypography.secondary())
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .appearAnimation(delay: 0.04)
                    }

                    SectionHeader(
                        title: "Acceleration",
                        subtitle: liveOrBestSubtitle
                    )
                    .padding(.horizontal, 2)

                    LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                        ForEach(Array(accelerationCards.enumerated()), id: \.element.id) { index, card in
                            PerformanceRunCard(
                                title: card.title,
                                subtitle: card.subtitle,
                                elapsedTime: card.elapsedTime,
                                elapsedUnit: card.elapsedUnit,
                                topSpeed: card.topSpeed,
                                topSpeedUnit: card.topSpeedUnit,
                                symbol: card.symbol,
                                statusTitle: card.statusTitle,
                                statusStyle: card.statusStyle,
                                delay: 0.06 + Double(index) * 0.04
                            )
                        }
                    }

                    SectionHeader(
                        title: "Distance",
                        subtitle: "Elapsed time and trap speed"
                    )
                    .padding(.horizontal, 2)
                    .padding(.top, AppSpacing.xs)

                    LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                        ForEach(Array(distanceCards.enumerated()), id: \.element.id) { index, card in
                            PerformanceRunCard(
                                title: card.title,
                                subtitle: card.subtitle,
                                elapsedTime: card.elapsedTime,
                                elapsedUnit: card.elapsedUnit,
                                topSpeed: card.topSpeed,
                                topSpeedUnit: card.topSpeedUnit,
                                symbol: card.symbol,
                                statusTitle: card.statusTitle,
                                statusStyle: card.statusStyle,
                                delay: 0.18 + Double(index) * 0.04
                            )
                        }
                    }

                    historySection
                        .appearAnimation(delay: 0.3)

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
            .onAppear {
                performanceEngine.attach(modelContext: modelContext)
                syncVehicle()
            }
            .onChange(of: activeVehicle?.id) { _, _ in syncVehicle() }
            .onChange(of: activeVehicle?.performanceBestsJSON) { _, _ in syncVehicle() }
        }
        .tint(Color.appAccent)
    }

    private var liveOrBestSubtitle: String {
        snap.phase == .running ? "Live timing" : "Personal bests"
    }

    private var statusMessage: String? {
        switch snap.phase {
        case .cancelled:
            if let reason = snap.lastCancelReason {
                return "Last run cancelled — \(reason.rawValue). Unreliable results were not saved."
            }
            return "Last run cancelled. Results were not saved."
        case .armed:
            return snap.stopHoldSatisfied
                ? "Armed — waiting for a clean launch from a stop."
                : "Armed — come to a complete stop to prepare a launch."
        case .idle:
            return drivingEngine.snapshot.phase.isActivelyRecording
                ? nil
                : "Performance Mode arms automatically during an active drive."
        case .running, .completed:
            return nil
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                StatusBadge(
                    title: snap.phase.displayName,
                    icon: "stopwatch.fill",
                    style: phaseBadgeStyle
                )
                Spacer()
                StatusBadge(title: "GPS Timing", icon: "location.fill", style: .neutral)
            }

            Text("Performance Timer")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)

            Text("Factory-style acceleration and distance timing. Runs start automatically from a standing launch—no Start button.")
                .font(AppTypography.secondary())
                .foregroundStyle(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: AppSpacing.sm) {
                heroStat(value: "\(historyRuns.count)", label: "Runs")
                heroStat(value: lastRunValue, label: "Last 0–60")
                heroStat(value: snap.phase.displayName, label: "Status")
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
        .accessibilityElement(children: .contain)
    }

    private var lastRunValue: String {
        if let live = snap.liveRun?.zeroTo60Seconds {
            return formatSeconds(live)
        }
        if let last = performanceEngine.recentRuns.first(where: \.isValid)?.zeroTo60Seconds
            ?? bests.zeroTo60Seconds {
            return formatSeconds(last)
        }
        return "—"
    }

    private var phaseBadgeStyle: StatusBadge.Style {
        switch snap.phase {
        case .running: .success
        case .armed: .accent
        case .completed: .success
        case .cancelled: .warning
        case .idle: .neutral
        }
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(AppTypography.metric(22))
                .foregroundStyle(Color.appTextPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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

    private var accelerationCards: [PerformanceRunResult] {
        [
            card(
                title: PerformanceLabels.accelerationTitle(mphTarget: 30, unit: speedUnit),
                subtitle: "Launch response",
                seconds: displayedSeconds(live: snap.liveRun?.zeroTo30Seconds, completed: snap.lastCompletedRun?.zeroTo30Seconds, best: bests.zeroTo30Seconds),
                symbol: "hare.fill",
                reached: snap.liveRun?.reached30
            ),
            card(
                title: PerformanceLabels.accelerationTitle(mphTarget: 40, unit: speedUnit),
                subtitle: "Midrange punch",
                seconds: displayedSeconds(live: snap.liveRun?.zeroTo40Seconds, completed: snap.lastCompletedRun?.zeroTo40Seconds, best: bests.zeroTo40Seconds),
                symbol: "gauge.with.needle.fill",
                reached: snap.liveRun?.reached40
            ),
            card(
                title: PerformanceLabels.accelerationTitle(mphTarget: 60, unit: speedUnit),
                subtitle: "Benchmark sprint",
                seconds: displayedSeconds(live: snap.liveRun?.zeroTo60Seconds, completed: snap.lastCompletedRun?.zeroTo60Seconds, best: bests.zeroTo60Seconds),
                symbol: "flag.checkered",
                reached: snap.liveRun?.reached60
            )
        ]
    }

    private var distanceCards: [PerformanceRunResult] {
        [
            card(
                title: PerformanceLabels.eighthTitle(unit: distanceUnit),
                subtitle: "Short strip",
                seconds: displayedSeconds(live: snap.liveRun?.eighthMileSeconds, completed: snap.lastCompletedRun?.eighthMileSeconds, best: bests.eighthMileSeconds),
                topSpeed: displayedSpeedMPS(live: snap.liveRun?.eighthMileTopSpeedMetersPerSecond, completed: snap.lastCompletedRun?.eighthMileTopSpeedMetersPerSecond, best: bests.eighthMileTopSpeedMetersPerSecond),
                symbol: "road.lanes",
                reached: snap.liveRun?.reachedEighth
            ),
            card(
                title: PerformanceLabels.quarterTitle(unit: distanceUnit),
                subtitle: "Full quarter",
                seconds: displayedSeconds(live: snap.liveRun?.quarterMileSeconds, completed: snap.lastCompletedRun?.quarterMileSeconds, best: bests.quarterMileSeconds),
                topSpeed: displayedSpeedMPS(live: snap.liveRun?.quarterMileTopSpeedMetersPerSecond, completed: snap.lastCompletedRun?.quarterMileTopSpeedMetersPerSecond, best: bests.quarterMileTopSpeedMetersPerSecond),
                symbol: "flag.checkered.2.crossed",
                reached: snap.liveRun?.reachedQuarter
            )
        ]
    }

    private func displayedSeconds(live: Double?, completed: Double?, best: Double?) -> Double? {
        if let live { return live }
        if let completed, snap.lastCompletedRun?.isValid == true { return completed }
        return best
    }

    private func displayedSpeedMPS(live: Double?, completed: Double?, best: Double?) -> Double? {
        if let live { return live }
        if let completed, snap.lastCompletedRun?.isValid == true { return completed }
        return best
    }

    private func card(
        title: String,
        subtitle: String,
        seconds: Double?,
        topSpeed: Double? = nil,
        symbol: String,
        reached: Bool?
    ) -> PerformanceRunResult {
        let status: (String, StatusBadge.Style) = {
            if snap.phase == .running {
                if reached == true { return ("Set", .success) }
                return ("Timing", .accent)
            }
            if seconds != nil { return ("Best", .neutral) }
            return ("Ready", .accent)
        }()

        return PerformanceRunResult(
            title: title,
            subtitle: subtitle,
            elapsedTime: seconds.map(formatSeconds) ?? "—",
            elapsedUnit: "sec",
            topSpeed: topSpeed.map { String(format: "%.1f", speedUnit.value(fromMetersPerSecond: $0)) },
            topSpeedUnit: topSpeed != nil ? speedUnit.rawValue : nil,
            symbol: symbol,
            statusTitle: status.0,
            statusStyle: status.1
        )
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: "History", subtitle: "Validated runs, newest first")
            if historyRuns.isEmpty {
                AppCard {
                    Text("Completed launches appear here with 0–60, 1/8, 1/4, and trap speed.")
                        .font(AppTypography.secondary())
                        .foregroundStyle(Color.appTextSecondary)
                }
            } else {
                ForEach(historyRuns.prefix(20)) { run in
                    NavigationLink {
                        PerformanceDetailView(run: run)
                    } label: {
                        PerformanceHistoryRow(run: run)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var insightCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SectionHeader(title: "Session Notes")
                Text("Timing uses filtered GPS speed and trip distance from the Driving Engine. Poor signal cancels a run without saving. Best results update only when a run improves a mark.")
                    .font(AppTypography.secondary())
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
    }

    private func syncVehicle() {
        performanceEngine.updateActiveVehicle(
            id: activeVehicle?.id,
            name: activeVehicle?.name,
            speedUnit: activeVehicle?.preferredSpeedUnit ?? .milesPerHour,
            distanceUnit: activeVehicle?.preferredDistanceUnit ?? .miles,
            bestsJSON: activeVehicle?.performanceBestsJSON
        )
    }

    private func formatSeconds(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

private struct PerformanceHistoryRow: View {
    let run: PerformanceRunSummary

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.vehicleName)
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                    Text(run.launchedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(AppTypography.footnote())
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appTextTertiary)
                    .accessibilityHidden(true)
            }

            HStack(spacing: AppSpacing.sm) {
                metric("0–60", run.zeroTo60Seconds.map { String(format: "%.2f s", $0) } ?? "—")
                metric("1/8", run.eighthMileSeconds.map { String(format: "%.2f s", $0) } ?? "—")
                metric("1/4", run.quarterMileSeconds.map { String(format: "%.2f s", $0) } ?? "—")
                metric(
                    "Top",
                    String(format: "%.0f %@", run.displayPeakSpeed, run.speedUnit.rawValue)
                )
            }
        }
        .padding(AppSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, y: AppShadow.card.y)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .strokeBorder(Color.appBorder, lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(run.vehicleName), \(run.launchedAt.formatted(date: .abbreviated, time: .shortened))")
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(AppTypography.micro())
                .foregroundStyle(Color.appTextTertiary)
            Text(value)
                .font(AppTypography.label())
                .foregroundStyle(Color.appTextPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PerformanceDetailView: View {
    let run: PerformanceRunSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                AppCard(elevated: true) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        StatusBadge(
                            title: run.isValid ? "Validated" : "Cancelled",
                            icon: run.isValid ? "checkmark" : "xmark",
                            style: run.isValid ? .success : .warning
                        )
                        Text(run.vehicleName)
                            .font(.title.weight(.semibold))
                            .foregroundStyle(Color.appTextPrimary)
                        Text(run.launchedAt.formatted(date: .complete, time: .standard))
                            .font(AppTypography.secondary())
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: 0) {
                        InfoRow(title: "Launch", value: run.launchedAt.formatted(date: .omitted, time: .standard), symbol: "flag")
                        InfoRow(
                            title: "Duration",
                            value: String(format: "%.2f sec", run.durationSeconds),
                            symbol: "timer"
                        )
                        InfoRow(
                            title: "Distance",
                            value: String(
                                format: "%.0f m (%.2f %@)",
                                run.distanceMeters,
                                run.distanceUnit.value(fromMeters: run.distanceMeters),
                                run.distanceUnit.rawValue
                            ),
                            symbol: "point.topleft.down.to.point.bottomright.curvepath"
                        )
                        InfoRow(
                            title: "Peak Speed",
                            value: String(format: "%.1f %@", run.displayPeakSpeed, run.speedUnit.rawValue),
                            symbol: "gauge.with.needle.fill",
                            showsDivider: false
                        )
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: 0) {
                        InfoRow(title: PerformanceLabels.accelerationTitle(mphTarget: 30, unit: run.speedUnit), value: seconds(run.zeroTo30Seconds), symbol: "hare")
                        InfoRow(title: PerformanceLabels.accelerationTitle(mphTarget: 40, unit: run.speedUnit), value: seconds(run.zeroTo40Seconds), symbol: "gauge.with.needle")
                        InfoRow(title: PerformanceLabels.accelerationTitle(mphTarget: 60, unit: run.speedUnit), value: seconds(run.zeroTo60Seconds), symbol: "flag.checkered", showsDivider: false)
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: 0) {
                        InfoRow(
                            title: PerformanceLabels.eighthTitle(unit: run.distanceUnit),
                            value: seconds(run.eighthMileSeconds),
                            symbol: "road.lanes"
                        )
                        InfoRow(
                            title: "1/8 Trap",
                            value: speed(run.displayEighthTopSpeed),
                            symbol: "speedometer"
                        )
                        InfoRow(
                            title: PerformanceLabels.quarterTitle(unit: run.distanceUnit),
                            value: seconds(run.quarterMileSeconds),
                            symbol: "flag.checkered.2.crossed"
                        )
                        InfoRow(
                            title: "1/4 Trap",
                            value: speed(run.displayQuarterTopSpeed),
                            symbol: "speedometer",
                            showsDivider: false
                        )
                    }
                }

                futureSection(title: "Graphs", message: "Speed and distance charts will appear here.")
                futureSection(title: "Acceleration Curve", message: "Launch profile visualization will appear here.")
                futureSection(title: "G-Force", message: "Longitudinal acceleration will appear here.")
                futureSection(title: "OBD Data", message: "RPM and throttle traces will appear here when connected.")
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .appScreenBackground()
        .navigationTitle("Run")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .tint(Color.appAccent)
    }

    private func seconds(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f sec", value)
    }

    private func speed(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f %@", value, run.speedUnit.rawValue)
    }

    private func futureSection(title: String, message: String) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SectionHeader(title: title, subtitle: "Coming later")
                Text(message)
                    .font(AppTypography.secondary())
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
    }
}

/// Presentation model for a performance result card.
struct PerformanceRunResult: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let elapsedTime: String
    let elapsedUnit: String
    let topSpeed: String?
    let topSpeedUnit: String?
    let symbol: String
    let statusTitle: String
    let statusStyle: StatusBadge.Style

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        elapsedTime: String,
        elapsedUnit: String = "sec",
        topSpeed: String? = nil,
        topSpeedUnit: String? = nil,
        symbol: String,
        statusTitle: String = "Ready",
        statusStyle: StatusBadge.Style = .accent
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.elapsedTime = elapsedTime
        self.elapsedUnit = elapsedUnit
        self.topSpeed = topSpeed
        self.topSpeedUnit = topSpeedUnit
        self.symbol = symbol
        self.statusTitle = statusTitle
        self.statusStyle = statusStyle
    }

    var includesTopSpeed: Bool { topSpeed != nil }
}

#Preview {
    let provider = NoOpLocationProvider()
    let telemetry = DrivingTelemetryService(locationProvider: provider)
    let driving = DrivingEngine(telemetry: telemetry)
    let performance = PerformanceEngine(telemetry: telemetry, drivingEngine: driving)
    return PerformanceView()
        .environment(telemetry)
        .environment(driving)
        .environment(performance)
        .modelContainer(for: [VehicleProfile.self, DriveRecord.self], inMemory: true)
        .preferredColorScheme(.dark)
}
