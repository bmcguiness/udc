import Foundation
import Observation
import SwiftData

/// Times acceleration / distance runs from filtered telemetry + DrivingEngine trip distance.
@Observable
@MainActor
final class PerformanceEngine {
    private(set) var snapshot: PerformanceEngineSnapshot = .idle
    /// In-memory history for the current app session (also flushed onto DriveRecord).
    private(set) var recentRuns: [PerformanceRunSummary] = []
    private(set) var bests: PerformanceBests = .empty

    private let telemetry: DrivingTelemetryService
    private let drivingEngine: DrivingEngine
    private let configuration: PerformanceConfiguration
    private var modelContext: ModelContext?
    private var observerID: UUID?

    private var activeVehicleID: UUID?
    private var activeVehicleName: String = "Vehicle"
    private var preferredSpeedUnit: SpeedUnit = .milesPerHour
    private var preferredDistanceUnit: DistanceUnit = .miles

    private var phase: PerformancePhase = .idle
    private var liveRun: LivePerformanceRun?
    private var distanceBaselineMeters: Double = 0
    private var stoppedSince: Date?
    private var slowdownSince: Date?
    private var lastSpeedMetersPerSecond: Double = 0
    private var lastSampleAt: Date?
    private var cooldownUntil: Date?
    private var pendingRunsByTripID: [UUID: [PerformanceRunSummary]] = [:]
    private var lastSeenCompletedTripID: UUID?

    init(
        telemetry: DrivingTelemetryService,
        drivingEngine: DrivingEngine,
        configuration: PerformanceConfiguration = .init()
    ) {
        self.telemetry = telemetry
        self.drivingEngine = drivingEngine
        self.configuration = configuration
        bindTelemetry()
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func updateActiveVehicle(
        id: UUID?,
        name: String?,
        speedUnit: SpeedUnit,
        distanceUnit: DistanceUnit,
        bestsJSON: String?
    ) {
        activeVehicleID = id
        activeVehicleName = name ?? "Vehicle"
        preferredSpeedUnit = speedUnit
        preferredDistanceUnit = distanceUnit
        bests = Self.decodeBests(bestsJSON)
        publishSnapshot()
    }

    // MARK: - Telemetry

    private func bindTelemetry() {
        observerID = telemetry.addStateObserver { [weak self] state in
            self?.handle(state: state)
        }
    }

    private func handle(state: DrivingState) {
        flushCompletedDriveAttachmentsIfNeeded()

        let now = state.timestamp ?? .now
        let gpsReady = state.gpsStatus == .ready
        snapshot.gpsQualityReady = gpsReady

        let session = drivingEngine.snapshot
        let inDrive = session.phase.isActivelyRecording

        if let cooldownUntil, now < cooldownUntil {
            publishSnapshot()
            return
        }

        switch phase {
        case .idle:
            if inDrive {
                transition(to: .armed)
                resetArmingState()
            }
        case .armed:
            if !inDrive {
                transition(to: .idle)
                resetArmingState()
            } else {
                considerLaunch(state: state, session: session, now: now, gpsReady: gpsReady)
            }
        case .running:
            if !gpsReady || state.gpsStatus == .poorSignal || state.gpsStatus == .unavailable {
                cancelRun(reason: .poorGPS, at: now)
            } else if !inDrive {
                completeRun(reason: .sessionEnded, at: now)
            } else {
                updateRunning(state: state, session: session, now: now)
            }
        case .completed, .cancelled:
            transition(to: inDrive ? .armed : .idle)
            resetArmingState()
        }

        publishSnapshot()
        pushDiagnostics(state: state)
    }

    // MARK: - Launch

    private func considerLaunch(
        state: DrivingState,
        session: DrivingEngineSnapshot,
        now: Date,
        gpsReady: Bool
    ) {
        guard gpsReady, let speed = state.filteredSpeedMetersPerSecond else {
            stoppedSince = nil
            snapshot.stopHoldSatisfied = false
            snapshot.launchDetected = false
            return
        }

        if speed <= configuration.stopSpeedMetersPerSecond {
            if stoppedSince == nil {
                stoppedSince = now
            }
            let held = now.timeIntervalSince(stoppedSince ?? now) >= configuration.stopHoldDuration
            snapshot.stopHoldSatisfied = held
            lastSpeedMetersPerSecond = speed
            lastSampleAt = now
            return
        }

        // Moving without a fresh stop — treat as rolling / cruise.
        guard snapshot.stopHoldSatisfied, let stoppedSince else {
            self.stoppedSince = nil
            snapshot.stopHoldSatisfied = false
            lastSpeedMetersPerSecond = speed
            lastSampleAt = now
            return
        }

        // Reject rolling starts that never truly stopped.
        if speed < configuration.launchTriggerSpeedMetersPerSecond {
            lastSpeedMetersPerSecond = speed
            lastSampleAt = now
            return
        }

        let dt = max(now.timeIntervalSince(lastSampleAt ?? stoppedSince), 0.05)
        let acceleration = (speed - lastSpeedMetersPerSecond) / dt
        lastSpeedMetersPerSecond = speed
        lastSampleAt = now

        guard acceleration >= configuration.minLaunchAcceleration else {
            // Not a clean launch pull — stay armed, clear stop hold so cruise cannot fake it.
            if speed >= configuration.rollingRejectSpeedMetersPerSecond {
                self.stoppedSince = nil
                snapshot.stopHoldSatisfied = false
            }
            return
        }

        beginRun(at: now, session: session, speed: speed)
    }

    private func beginRun(at date: Date, session: DrivingEngineSnapshot, speed: Double) {
        distanceBaselineMeters = session.liveTrip?.distanceMeters ?? 0
        liveRun = LivePerformanceRun(
            id: UUID(),
            launchedAt: date,
            driveTripID: session.liveTrip?.id,
            distanceMeters: 0,
            elapsedSeconds: 0,
            currentSpeedMetersPerSecond: speed,
            peakSpeedMetersPerSecond: max(speed, 0)
        )
        phase = .running
        snapshot.launchDetected = true
        snapshot.isCurrentRunValid = true
        snapshot.lastCancelReason = nil
        snapshot.lastCompletionReason = nil
        stoppedSince = nil
        slowdownSince = nil
        snapshot.stopHoldSatisfied = false
    }

    // MARK: - Running

    private func updateRunning(state: DrivingState, session: DrivingEngineSnapshot, now: Date) {
        guard var run = liveRun else { return }
        let speed = state.filteredSpeedMetersPerSecond ?? 0
        let tripDistance = session.liveTrip?.distanceMeters ?? distanceBaselineMeters
        let distance = max(0, tripDistance - distanceBaselineMeters)

        run.elapsedSeconds = max(0, now.timeIntervalSince(run.launchedAt))
        run.distanceMeters = distance
        run.currentSpeedMetersPerSecond = speed
        run.peakSpeedMetersPerSecond = max(run.peakSpeedMetersPerSecond, speed)

        captureMilestones(run: &run, speed: speed, distance: distance)

        liveRun = run

        if run.reachedQuarter {
            completeRun(reason: .quarterMile, at: now)
            return
        }

        if speed <= configuration.slowdownSpeedMetersPerSecond,
           run.peakSpeedMetersPerSecond >= configuration.minimumSaveSpeedMetersPerSecond {
            if slowdownSince == nil {
                slowdownSince = now
            } else if now.timeIntervalSince(slowdownSince!) >= configuration.slowdownHoldDuration {
                completeRun(reason: .significantSlowdown, at: now)
            }
        } else {
            slowdownSince = nil
        }

        lastSpeedMetersPerSecond = speed
        lastSampleAt = now
    }

    private func captureMilestones(run: inout LivePerformanceRun, speed: Double, distance: Double) {
        let elapsed = run.elapsedSeconds
        if run.zeroTo30Seconds == nil, speed >= configuration.thirtyMPHMetersPerSecond {
            run.zeroTo30Seconds = elapsed
        }
        if run.zeroTo40Seconds == nil, speed >= configuration.fortyMPHMetersPerSecond {
            run.zeroTo40Seconds = elapsed
        }
        if run.zeroTo60Seconds == nil, speed >= configuration.sixtyMPHMetersPerSecond {
            run.zeroTo60Seconds = elapsed
        }
        if run.eighthMileSeconds == nil, distance >= configuration.eighthMileMeters {
            run.eighthMileSeconds = elapsed
            run.eighthMileTopSpeedMetersPerSecond = run.peakSpeedMetersPerSecond
        }
        if run.quarterMileSeconds == nil, distance >= configuration.quarterMileMeters {
            run.quarterMileSeconds = elapsed
            run.quarterMileTopSpeedMetersPerSecond = run.peakSpeedMetersPerSecond
        }
    }

    // MARK: - Complete / Cancel

    private func completeRun(reason: PerformanceCompletionReason, at date: Date) {
        guard let run = liveRun else {
            transition(to: .armed)
            return
        }

        let hasUsefulData = run.reached30 || run.reachedEighth || run.peakSpeedMetersPerSecond >= configuration.minimumSaveSpeedMetersPerSecond
        guard hasUsefulData, snapshot.isCurrentRunValid else {
            cancelRun(reason: .discarded, at: date)
            return
        }

        let summary = makeSummary(from: run, completedAt: date, valid: true, completion: reason, cancel: nil)
        recentRuns.insert(summary, at: 0)
        bufferPending(summary)
        applyBests(from: summary)

        liveRun = nil
        phase = .completed
        snapshot.lastCompletedRun = summary
        snapshot.lastCompletionReason = reason
        snapshot.launchDetected = false
        cooldownUntil = date.addingTimeInterval(configuration.cooldownDuration)
        resetArmingState()
    }

    private func cancelRun(reason: PerformanceCancelReason, at date: Date) {
        if let run = liveRun {
            let summary = makeSummary(from: run, completedAt: date, valid: false, completion: nil, cancel: reason)
            // Cancelled runs are kept only for diagnostics / recent UI — not bests, not DriveRecord.
            snapshot.lastCompletedRun = summary
        }
        liveRun = nil
        phase = .cancelled
        snapshot.lastCancelReason = reason
        snapshot.isCurrentRunValid = false
        snapshot.launchDetected = false
        cooldownUntil = date.addingTimeInterval(configuration.cooldownDuration)
        resetArmingState()
    }

    private func makeSummary(
        from run: LivePerformanceRun,
        completedAt: Date,
        valid: Bool,
        completion: PerformanceCompletionReason?,
        cancel: PerformanceCancelReason?
    ) -> PerformanceRunSummary {
        PerformanceRunSummary(
            id: run.id,
            driveRecordID: run.driveTripID,
            vehicleID: activeVehicleID,
            vehicleName: activeVehicleName,
            launchedAt: run.launchedAt,
            completedAt: completedAt,
            isValid: valid,
            cancelReason: cancel,
            completionReason: completion,
            zeroTo30Seconds: run.zeroTo30Seconds,
            zeroTo40Seconds: run.zeroTo40Seconds,
            zeroTo60Seconds: run.zeroTo60Seconds,
            eighthMileSeconds: run.eighthMileSeconds,
            quarterMileSeconds: run.quarterMileSeconds,
            eighthMileTopSpeedMetersPerSecond: run.eighthMileTopSpeedMetersPerSecond,
            quarterMileTopSpeedMetersPerSecond: run.quarterMileTopSpeedMetersPerSecond,
            peakSpeedMetersPerSecond: run.peakSpeedMetersPerSecond,
            distanceMeters: run.distanceMeters,
            durationSeconds: run.elapsedSeconds,
            speedUnitRaw: preferredSpeedUnit.rawValue,
            distanceUnitRaw: preferredDistanceUnit.rawValue
        )
    }

    // MARK: - Persistence

    private func bufferPending(_ summary: PerformanceRunSummary) {
        guard let tripID = summary.driveRecordID else { return }
        pendingRunsByTripID[tripID, default: []].append(summary)
    }

    private func flushCompletedDriveAttachmentsIfNeeded() {
        guard let tripID = drivingEngine.snapshot.lastCompletedTripID,
              tripID != lastSeenCompletedTripID else { return }
        lastSeenCompletedTripID = tripID
        guard let runs = pendingRunsByTripID.removeValue(forKey: tripID), !runs.isEmpty else { return }
        attach(runs: runs, toDriveID: tripID)
    }

    private func attach(runs: [PerformanceRunSummary], toDriveID driveID: UUID) {
        guard let modelContext else { return }
        var descriptor = FetchDescriptor<DriveRecord>(predicate: #Predicate { $0.id == driveID })
        descriptor.fetchLimit = 1
        guard let record = try? modelContext.fetch(descriptor).first else { return }

        var existing = PerformanceAttachment.decode(from: record.performanceSummaryJSON)
        existing.append(contentsOf: runs)
        record.performanceSummaryJSON = PerformanceAttachment.encode(existing)
        try? modelContext.save()
    }

    private func applyBests(from run: PerformanceRunSummary) {
        let (next, improved) = bests.merging(run: run)
        guard improved else { return }
        bests = next
        persistBests()
    }

    private func persistBests() {
        guard let modelContext, let vehicleID = activeVehicleID else { return }
        var descriptor = FetchDescriptor<VehicleProfile>(predicate: #Predicate { $0.id == vehicleID })
        descriptor.fetchLimit = 1
        guard let vehicle = try? modelContext.fetch(descriptor).first else { return }
        vehicle.performanceBestsJSON = Self.encodeBests(bests)
        vehicle.modifiedAt = .now
        try? modelContext.save()
    }

    private static func encodeBests(_ bests: PerformanceBests) -> String? {
        guard let data = try? JSONEncoder().encode(bests),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    private static func decodeBests(_ json: String?) -> PerformanceBests {
        guard let json, let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(PerformanceBests.self, from: data) else {
            return .empty
        }
        return decoded
    }

    // MARK: - Helpers

    private func transition(to newPhase: PerformancePhase) {
        phase = newPhase
    }

    private func resetArmingState() {
        stoppedSince = nil
        slowdownSince = nil
        snapshot.stopHoldSatisfied = false
        if phase != .running {
            snapshot.launchDetected = false
        }
    }

    private func publishSnapshot() {
        snapshot.phase = phase
        snapshot.liveRun = liveRun
    }

    private func pushDiagnostics(state: DrivingState) {
        let run = liveRun
        telemetry.updatePerformanceDiagnostics(
            phase: phase,
            launchDetected: snapshot.launchDetected || phase == .running,
            distanceMeters: run?.distanceMeters,
            elapsedSeconds: run?.elapsedSeconds,
            reached30: run?.reached30 ?? false,
            reached40: run?.reached40 ?? false,
            reached60: run?.reached60 ?? false,
            reachedEighth: run?.reachedEighth ?? false,
            reachedQuarter: run?.reachedQuarter ?? false,
            gpsQualityReady: state.gpsStatus == .ready,
            isCurrentRunValid: snapshot.isCurrentRunValid && phase != .cancelled,
            cancelReason: snapshot.lastCancelReason
        )
    }
}
