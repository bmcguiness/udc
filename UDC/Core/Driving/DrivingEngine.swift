import Foundation
import Observation
import SwiftData
import SwiftUI

/// Observes `DrivingTelemetryService`, detects sessions, checkpoints durable progress, and finalizes drives.
@Observable
@MainActor
final class DrivingEngine {
    private(set) var snapshot: DrivingEngineSnapshot = .idle

    private let telemetry: DrivingTelemetryService
    private let configuration: DriveSessionConfiguration
    private let durability: DriveDurabilityConfiguration
    private var modelContext: ModelContext?

    private var activeVehicleID: UUID?
    private var activeVehicleName: String = "Vehicle"
    private var preferredSpeedUnit: SpeedUnit = .milesPerHour
    private var preferredDistanceUnit: DistanceUnit = .miles

    private var preparingSince: Date?
    private var stoppedSince: Date?
    /// Accumulated duration from consecutive valid stopped samples only.
    private var validStoppedAccumulatedSeconds: TimeInterval = 0
    /// Last sample that contributed valid stopped evidence. Cleared on unknown speed.
    private var lastValidStoppedSampleAt: Date?
    private var lastValidMotionSampleAt: Date?
    private var preparingDistanceMeters: Double = 0

    private var lastAcceptedCoordinate: (lat: Double, lon: Double)?
    private var lastAcceptedTimestamp: Date?

    private var liveTrip: LiveTrip?
    private var phase: DriveSessionPhase = .idle

    private var lastCheckpointAt: Date?
    private var distanceAtLastCheckpoint: Double = 0
    private var lastCheckpointReason: DriveCheckpointReason?
    private var activeRecordPersisted: Bool = false
    private var recoveredSession: Bool = false
    private var recoveryReason: DriveRecoveryReason = .none
    private var didRunRecovery: Bool = false

    init(
        telemetry: DrivingTelemetryService,
        configuration: DriveSessionConfiguration = .init(),
        durability: DriveDurabilityConfiguration = .init()
    ) {
        self.telemetry = telemetry
        self.configuration = configuration
        self.durability = durability
        snapshot.movementThresholdMetersPerSecond = configuration.startSpeedMetersPerSecond
        bindTelemetry()
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
        if !didRunRecovery {
            didRunRecovery = true
            recoverInProgressDrivesIfNeeded()
        }
        syncBackgroundLocationPolicy()
        publishSnapshot()
    }

    func updateActiveVehicle(
        id: UUID?,
        name: String?,
        speedUnit: SpeedUnit,
        distanceUnit: DistanceUnit
    ) {
        activeVehicleID = id
        activeVehicleName = name ?? "Vehicle"
        preferredSpeedUnit = speedUnit
        preferredDistanceUnit = distanceUnit
        if var trip = liveTrip {
            trip.vehicleID = id
            trip.vehicleName = activeVehicleName
            trip.preferredSpeedUnit = speedUnit
            trip.preferredDistanceUnit = distanceUnit
            liveTrip = trip
        }
        publishSnapshot()
    }

    /// Whether a durable in-progress drive exists that the user can explicitly finalize.
    var canEndDriveManually: Bool {
        phase.isActivelyRecording && liveTrip != nil && activeRecordPersisted
    }

    /// User-confirmed end. Always preserves an already-durable in-progress DriveRecord
    /// (even if automatic minimum distance/duration floors are unmet). Automatic floors unchanged.
    @discardableResult
    func endCurrentDriveManually() -> Bool {
        guard canEndDriveManually else { return false }
        let end = lastAcceptedTimestamp ?? .now
        completeTrip(at: end, reason: .manualUserEnd, forcePersist: true)
        return true
    }

    /// App-wide scene lifecycle hook (idle timer is owned by the app; this handles durability + GPS).
    func handleScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            telemetry.noteForegroundTransition()
            syncBackgroundLocationPolicy()
            if phase.isActivelyRecording {
                telemetry.ensureUpdating()
            }
        case .inactive:
            break
        case .background:
            telemetry.noteBackgroundTransition()
            if phase.isActivelyRecording {
                checkpoint(reason: .enteredBackground, force: true)
                syncBackgroundLocationPolicy()
            } else {
                syncBackgroundLocationPolicy()
            }
        @unknown default:
            break
        }
        publishSnapshot()
    }

    // MARK: - Telemetry

    private func bindTelemetry() {
        telemetry.addStateObserver { [weak self] state in
            self?.handle(state: state)
        }
    }

    private func handle(state: DrivingState) {
        snapshot.gpsSampleCount += 1

        let filtered = state.filteredSpeedMetersPerSecond
        let hasValidSpeed = filtered != nil
        let accepted = hasValidSpeed && state.gpsStatus != .unavailable
        if accepted {
            snapshot.acceptedSampleCount += 1
        } else {
            snapshot.rejectedSampleCount += 1
        }

        guard state.authorizationStatus.allowsLocationUpdates else {
            if phase.isActivelyRecording {
                completeTrip(at: .now, reason: .authorizationLost)
            } else {
                resetToIdle(reason: nil)
            }
            return
        }

        let now = state.timestamp ?? .now
        let previousPhase = phase
        accumulateDistanceIfNeeded(state: state, now: now)

        // Missing/rejected filtered speed is unknown — not zero. Do not infer stop/move.
        if let speed = filtered {
            applyValidSpeed(speed, at: now)
        } else {
            applyUnknownSpeed()
        }

        if phase != previousPhase, phase.isActivelyRecording || previousPhase.isActivelyRecording {
            if phase.isActivelyRecording {
                checkpoint(reason: .phaseTransition, force: true)
            }
            syncBackgroundLocationPolicy()
        } else if phase.isActivelyRecording {
            maybeCheckpoint(now: now)
        }

        publishSnapshot()
    }

    /// Applies a validated filtered speed sample to the session phase machine.
    private func applyValidSpeed(_ speed: Double, at now: Date) {
        switch phase {
        case .idle:
            considerPreparing(speed: speed, now: now)
        case .preparing:
            considerStart(speed: speed, now: now)
        case .driving:
            updateLiveTrip(speed: speed)
            lastValidMotionSampleAt = now
            if speed <= configuration.stopSpeedMetersPerSecond {
                phase = .stopped
                stoppedSince = now
                validStoppedAccumulatedSeconds = 0
                lastValidStoppedSampleAt = now
            }
        case .stopped:
            updateLiveTrip(speed: speed)
            if speed > configuration.stopSpeedMetersPerSecond {
                phase = .driving
                clearStoppedTiming()
                lastValidMotionSampleAt = now
            } else {
                if let lastValidStoppedSampleAt {
                    let delta = max(0, now.timeIntervalSince(lastValidStoppedSampleAt))
                    validStoppedAccumulatedSeconds += delta
                }
                lastValidStoppedSampleAt = now
                if validStoppedAccumulatedSeconds >= configuration.stopHoldDuration {
                    completeTrip(at: now, reason: .extendedStop)
                }
            }
        }
    }

    /// Unknown/unavailable speed: freeze stopped-interval chain; do not change phase.
    private func applyUnknownSpeed() {
        // Break the consecutive valid-stopped chain so GPS outages do not count as stopped time.
        lastValidStoppedSampleAt = nil
    }

    private func clearStoppedTiming() {
        stoppedSince = nil
        validStoppedAccumulatedSeconds = 0
        lastValidStoppedSampleAt = nil
    }

    private func considerPreparing(speed: Double, now: Date) {
        if speed >= configuration.startSpeedMetersPerSecond {
            phase = .preparing
            preparingSince = now
            preparingDistanceMeters = 0
            seedCoordinateTrackingFromTelemetry()
        }
    }

    private func considerStart(speed: Double, now: Date) {
        if speed < configuration.startSpeedMetersPerSecond * 0.6 {
            resetToIdle(reason: nil)
            return
        }

        let heldLongEnough: Bool = {
            guard let preparingSince else { return false }
            return now.timeIntervalSince(preparingSince) >= configuration.startHoldDuration
        }()

        let coveredEnough = preparingDistanceMeters >= configuration.startMinimumDistanceMeters

        if heldLongEnough || coveredEnough {
            let reason: DriveSessionStartReason = heldLongEnough ? .sustainedSpeed : .sustainedDistance
            beginTrip(at: preparingSince ?? now, reason: reason)
        }
    }

    private func beginTrip(at start: Date, reason: DriveSessionStartReason) {
        let trip = LiveTrip(
            id: UUID(),
            vehicleID: activeVehicleID,
            vehicleName: activeVehicleName,
            startedAt: start,
            distanceMeters: max(preparingDistanceMeters, 0),
            maximumSpeedMetersPerSecond: max(telemetry.state.filteredSpeedMetersPerSecond ?? 0, 0),
            preferredSpeedUnit: preferredSpeedUnit,
            preferredDistanceUnit: preferredDistanceUnit,
            speedSource: telemetry.state.speedSource == .none ? .gps : telemetry.state.speedSource
        )
        liveTrip = trip
        phase = .driving
        preparingSince = nil
        clearStoppedTiming()
        preparingDistanceMeters = 0
        recoveredSession = false
        recoveryReason = .none
        snapshot.startReason = reason
        snapshot.endReason = nil
        snapshot.lastCompletedTripID = nil
        distanceAtLastCheckpoint = trip.distanceMeters
        checkpoint(reason: .sessionStarted, force: true)
        syncBackgroundLocationPolicy()
    }

    private func updateLiveTrip(speed: Double) {
        guard var trip = liveTrip else { return }
        if speed > trip.maximumSpeedMetersPerSecond {
            trip.maximumSpeedMetersPerSecond = speed
        }
        if telemetry.state.speedSource != .none {
            trip.speedSource = telemetry.state.speedSource
        }
        liveTrip = trip
    }

    private func completeTrip(at end: Date, reason: DriveSessionEndReason, forcePersist: Bool = false) {
        guard let trip = liveTrip else {
            resetToIdle(reason: reason)
            return
        }

        let duration = max(0, end.timeIntervalSince(trip.startedAt))
        let distance = trip.distanceMeters
        let meetsFloor = distance >= configuration.minimumPersistDistanceMeters
            && duration >= configuration.minimumPersistDuration

        // Manual End Drive always keeps a durable in-progress record. Automatic floors unchanged.
        if forcePersist || meetsFloor {
            finalizeActiveRecord(trip: trip, endedAt: end, reason: reason)
            snapshot.lastCompletedTripID = trip.id
            snapshot.endReason = reason
            snapshot.lastFinalizationAt = end
        } else {
            discardActiveRecord(id: trip.id)
            snapshot.endReason = .discardedTooShort
            snapshot.lastFinalizationAt = end
        }

        liveTrip = nil
        phase = .idle
        preparingSince = nil
        clearStoppedTiming()
        preparingDistanceMeters = 0
        lastAcceptedCoordinate = nil
        lastAcceptedTimestamp = nil
        lastCheckpointAt = nil
        activeRecordPersisted = false
        recoveredSession = false
        syncBackgroundLocationPolicy()
        publishSnapshot()
    }

    private func resetToIdle(reason: DriveSessionEndReason?) {
        phase = .idle
        liveTrip = nil
        preparingSince = nil
        clearStoppedTiming()
        preparingDistanceMeters = 0
        lastAcceptedCoordinate = nil
        lastAcceptedTimestamp = nil
        lastCheckpointAt = nil
        activeRecordPersisted = false
        if let reason {
            snapshot.endReason = reason
        }
        syncBackgroundLocationPolicy()
        publishSnapshot()
    }

    // MARK: - Distance

    private func seedCoordinateTrackingFromTelemetry() {
        let state = telemetry.state
        if let lat = state.latitude, let lon = state.longitude {
            lastAcceptedCoordinate = (lat, lon)
            lastAcceptedTimestamp = state.timestamp ?? .now
        }
    }

    private func accumulateDistanceIfNeeded(state: DrivingState, now: Date) {
        guard let lat = state.latitude, let lon = state.longitude else { return }
        guard let accuracy = state.horizontalAccuracyMeters,
              accuracy >= 0,
              accuracy <= configuration.maxHorizontalAccuracyMeters else {
            return
        }
        guard phase == .preparing || phase.isActivelyRecording else {
            lastAcceptedCoordinate = (lat, lon)
            lastAcceptedTimestamp = now
            return
        }

        guard let previous = lastAcceptedCoordinate,
              let previousTime = lastAcceptedTimestamp else {
            lastAcceptedCoordinate = (lat, lon)
            lastAcceptedTimestamp = now
            return
        }

        let interval = now.timeIntervalSince(previousTime)
        let segment = TripMath.haversineMeters(
            lat1: previous.lat, lon1: previous.lon,
            lat2: lat, lon2: lon
        )

        lastAcceptedCoordinate = (lat, lon)
        lastAcceptedTimestamp = now

        guard TripMath.shouldAcceptDistanceSegment(
            distanceMeters: segment,
            intervalSeconds: interval,
            configuration: configuration
        ) else {
            return
        }

        switch phase {
        case .preparing:
            preparingDistanceMeters += segment
        case .driving, .stopped:
            if var trip = liveTrip {
                trip.distanceMeters += segment
                liveTrip = trip
            }
        case .idle:
            break
        }
    }

    // MARK: - Durability

    private func maybeCheckpoint(now: Date) {
        guard let trip = liveTrip else { return }
        let timed = lastCheckpointAt.map { now.timeIntervalSince($0) >= durability.checkpointMinimumInterval } ?? true
        let distanceDelta = trip.distanceMeters - distanceAtLastCheckpoint
        let movedEnough = distanceDelta >= durability.checkpointMinimumDistanceMeters
        if timed {
            checkpoint(reason: .timedInterval, force: false)
        } else if movedEnough {
            checkpoint(reason: .distanceInterval, force: false)
        }
    }

    private func checkpoint(reason: DriveCheckpointReason, force: Bool) {
        guard let trip = liveTrip, let modelContext else { return }
        let now = lastAcceptedTimestamp ?? Date.now
        if !force, let lastCheckpointAt,
           now.timeIntervalSince(lastCheckpointAt) < durability.checkpointMinimumInterval,
           reason == .timedInterval {
            return
        }

        let duration = max(0, now.timeIntervalSince(trip.startedAt))
        let average = TripMath.averageSpeedMetersPerSecond(
            distanceMeters: trip.distanceMeters,
            durationSeconds: duration
        )

        if let record = fetchRecord(id: trip.id) {
            applyTrip(trip, to: record, endedAt: now, finalized: false, reason: reason)
            record.averageSpeedMetersPerSecond = average
        } else {
            let record = DriveRecord(
                id: trip.id,
                vehicleID: trip.vehicleID,
                vehicleName: trip.vehicleName,
                startedAt: trip.startedAt,
                endedAt: now,
                distanceMeters: trip.distanceMeters,
                durationSeconds: duration,
                averageSpeedMetersPerSecond: average,
                maximumSpeedMetersPerSecond: trip.maximumSpeedMetersPerSecond,
                speedUnit: trip.preferredSpeedUnit,
                distanceUnit: trip.preferredDistanceUnit,
                speedSource: trip.speedSource,
                isFinalized: false,
                sessionPhase: phase,
                lastValidLatitude: lastAcceptedCoordinate?.lat,
                lastValidLongitude: lastAcceptedCoordinate?.lon,
                lastValidLocationAt: lastAcceptedTimestamp,
                lastCheckpointAt: now,
                checkpointReason: reason,
                recoveredFromInterruption: recoveredSession
            )
            modelContext.insert(record)
        }

        try? modelContext.save()
        lastCheckpointAt = now
        distanceAtLastCheckpoint = trip.distanceMeters
        lastCheckpointReason = reason
        activeRecordPersisted = true
    }

    private func finalizeActiveRecord(trip: LiveTrip, endedAt: Date, reason: DriveSessionEndReason) {
        guard let modelContext else { return }
        let duration = max(0, endedAt.timeIntervalSince(trip.startedAt))
        let average = TripMath.averageSpeedMetersPerSecond(
            distanceMeters: trip.distanceMeters,
            durationSeconds: duration
        )

        if let record = fetchRecord(id: trip.id) {
            applyTrip(trip, to: record, endedAt: endedAt, finalized: true, reason: .finalized)
            record.averageSpeedMetersPerSecond = average
            record.durationSeconds = duration
        } else {
            let record = DriveRecord(
                id: trip.id,
                vehicleID: trip.vehicleID,
                vehicleName: trip.vehicleName,
                startedAt: trip.startedAt,
                endedAt: endedAt,
                distanceMeters: trip.distanceMeters,
                durationSeconds: duration,
                averageSpeedMetersPerSecond: average,
                maximumSpeedMetersPerSecond: trip.maximumSpeedMetersPerSecond,
                speedUnit: trip.preferredSpeedUnit,
                distanceUnit: trip.preferredDistanceUnit,
                speedSource: trip.speedSource,
                isFinalized: true,
                sessionPhase: .idle,
                lastValidLatitude: lastAcceptedCoordinate?.lat,
                lastValidLongitude: lastAcceptedCoordinate?.lon,
                lastValidLocationAt: lastAcceptedTimestamp ?? endedAt,
                lastCheckpointAt: endedAt,
                checkpointReason: .finalized,
                recoveredFromInterruption: recoveredSession
            )
            modelContext.insert(record)
        }
        try? modelContext.save()
        lastCheckpointReason = .finalized
        activeRecordPersisted = true
        snapshot.endReason = reason
    }

    private func discardActiveRecord(id: UUID) {
        guard let modelContext, let record = fetchRecord(id: id), !record.isFinalized else { return }
        modelContext.delete(record)
        try? modelContext.save()
        activeRecordPersisted = false
    }

    private func applyTrip(
        _ trip: LiveTrip,
        to record: DriveRecord,
        endedAt: Date,
        finalized: Bool,
        reason: DriveCheckpointReason
    ) {
        record.vehicleID = trip.vehicleID
        record.vehicleName = trip.vehicleName
        record.startedAt = trip.startedAt
        record.endedAt = endedAt
        record.distanceMeters = trip.distanceMeters
        record.durationSeconds = max(0, endedAt.timeIntervalSince(trip.startedAt))
        record.maximumSpeedMetersPerSecond = trip.maximumSpeedMetersPerSecond
        record.speedUnitRaw = trip.preferredSpeedUnit.rawValue
        record.distanceUnitRaw = trip.preferredDistanceUnit.rawValue
        record.speedSourceRaw = trip.speedSource.rawValue
        record.isFinalized = finalized
        record.sessionPhaseRaw = DriveRecord.phaseRaw(from: finalized ? .idle : phase)
        record.lastValidLatitude = lastAcceptedCoordinate?.lat
        record.lastValidLongitude = lastAcceptedCoordinate?.lon
        record.lastValidLocationAt = lastAcceptedTimestamp ?? endedAt
        record.lastCheckpointAt = Date.now
        record.checkpointReasonRaw = reason.rawValue
        if recoveredSession {
            record.recoveredFromInterruption = true
        }
    }

    private func fetchRecord(id: UUID) -> DriveRecord? {
        guard let modelContext else { return nil }
        var descriptor = FetchDescriptor<DriveRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func recoverInProgressDrivesIfNeeded() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<DriveRecord>(
            predicate: #Predicate { $0.isInProgress == true },
            sortBy: [SortDescriptor(\.lastCheckpointAt, order: .reverse)]
        )
        guard let open = try? modelContext.fetch(descriptor), !open.isEmpty else {
            recoveryReason = .none
            return
        }

        // Keep only the newest open drive; discard/finalize older orphans.
        let newest = open[0]
        for orphan in open.dropFirst() {
            finalizeOrDiscardStale(orphan, now: .now)
        }

        let reference = newest.lastValidLocationAt ?? newest.lastCheckpointAt ?? newest.endedAt
        let age = Date.now.timeIntervalSince(reference)
        if age <= durability.resumeIfUpdatedWithin {
            resume(from: newest)
            recoveryReason = .resumedRecent
            recoveredSession = true
        } else {
            finalizeOrDiscardStale(newest, now: .now)
        }
    }

    private func resume(from record: DriveRecord) {
        let trip = LiveTrip(
            id: record.id,
            vehicleID: record.vehicleID,
            vehicleName: record.vehicleName,
            startedAt: record.startedAt,
            distanceMeters: record.distanceMeters,
            maximumSpeedMetersPerSecond: record.maximumSpeedMetersPerSecond,
            preferredSpeedUnit: record.speedUnit,
            preferredDistanceUnit: record.distanceUnit,
            speedSource: record.speedSource
        )
        liveTrip = trip
        if let saved = record.persistedSessionPhase, saved.isActivelyRecording {
            phase = saved
        } else {
            phase = .driving
        }
        if phase == .stopped {
            stoppedSince = record.lastValidLocationAt
            // Fresh valid-stopped chain after recovery — do not inherit wall-clock outage.
            validStoppedAccumulatedSeconds = 0
            lastValidStoppedSampleAt = nil
        } else {
            clearStoppedTiming()
        }
        if let lat = record.lastValidLatitude, let lon = record.lastValidLongitude {
            lastAcceptedCoordinate = (lat, lon)
            lastAcceptedTimestamp = record.lastValidLocationAt
        }
        activeVehicleID = record.vehicleID ?? activeVehicleID
        activeVehicleName = record.vehicleName
        preferredSpeedUnit = record.speedUnit
        preferredDistanceUnit = record.distanceUnit
        lastCheckpointAt = record.lastCheckpointAt
        distanceAtLastCheckpoint = record.distanceMeters
        lastCheckpointReason = .recovery
        activeRecordPersisted = true
        recoveredSession = true
        checkpoint(reason: .recovery, force: true)
        syncBackgroundLocationPolicy()
        telemetry.ensureUpdating()
    }

    private func finalizeOrDiscardStale(_ record: DriveRecord, now: Date) {
        var end = record.lastValidLocationAt ?? record.lastCheckpointAt ?? record.endedAt
        if end < record.startedAt {
            end = record.startedAt
        }
        let duration = max(0, end.timeIntervalSince(record.startedAt))
        let meetsFloor = record.distanceMeters >= configuration.minimumPersistDistanceMeters
            && duration >= configuration.minimumPersistDuration
        guard let modelContext else { return }

        if meetsFloor {
            record.isFinalized = true
            record.endedAt = end
            record.durationSeconds = duration
            record.averageSpeedMetersPerSecond = TripMath.averageSpeedMetersPerSecond(
                distanceMeters: record.distanceMeters,
                durationSeconds: duration
            )
            record.sessionPhaseRaw = DriveRecord.phaseRaw(from: .idle)
            record.lastCheckpointAt = now
            record.checkpointReasonRaw = DriveCheckpointReason.staleFinalization.rawValue
            record.recoveredFromInterruption = true
            try? modelContext.save()
            snapshot.lastCompletedTripID = record.id
            snapshot.endReason = .staleRecovery
            snapshot.lastFinalizationAt = now
            recoveryReason = .finalizedStale
            lastCheckpointReason = .staleFinalization
        } else {
            modelContext.delete(record)
            try? modelContext.save()
            recoveryReason = .discardedStaleTooShort
            snapshot.lastFinalizationAt = now
        }
    }

    private func syncBackgroundLocationPolicy() {
        let enabled = BackgroundLocationPolicy.shouldEnableBackgroundUpdates(phase: phase)
        telemetry.setBackgroundLocationUpdatesEnabled(enabled)
    }

    // MARK: - Snapshot / diagnostics

    private func publishSnapshot() {
        let now = Date.now
        var next = snapshot
        next.phase = phase
        next.liveTrip = liveTrip
        next.movementThresholdMetersPerSecond = configuration.startSpeedMetersPerSecond
        next.activeDriveRecordID = liveTrip?.id
        next.activeRecordPersisted = activeRecordPersisted
        next.isFinalized = liveTrip == nil
        next.lastCheckpointAt = lastCheckpointAt
        next.lastCheckpointReason = lastCheckpointReason
        next.lastValidLocationAt = lastAcceptedTimestamp
        next.lastValidLatitude = lastAcceptedCoordinate?.lat
        next.lastValidLongitude = lastAcceptedCoordinate?.lon
        next.recoveredSession = recoveredSession
        next.recoveryReason = recoveryReason
        next.backgroundLocationEnabled = telemetry.isBackgroundLocationUpdatesEnabled
        next.canEndDriveManually = phase.isActivelyRecording && liveTrip != nil && activeRecordPersisted
        next.stopHoldDurationSeconds = configuration.stopHoldDuration
        next.stopSpeedMetersPerSecond = configuration.stopSpeedMetersPerSecond
        next.isFilteredSpeedValid = telemetry.state.filteredSpeedMetersPerSecond != nil
        next.lastValidMotionSampleAt = lastValidMotionSampleAt
        next.lastValidStoppedSampleAt = lastValidStoppedSampleAt
        if phase == .stopped {
            next.stoppedElapsedSeconds = validStoppedAccumulatedSeconds
        } else {
            next.stoppedElapsedSeconds = nil
        }
        if let trip = liveTrip {
            next.liveTrip = trip
            _ = trip.duration(at: now)
        }
        snapshot = next

        telemetry.updateSessionDiagnostics(
            phase: phase,
            liveTrip: liveTrip,
            startReason: snapshot.startReason,
            endReason: snapshot.endReason,
            movementThresholdMetersPerSecond: configuration.startSpeedMetersPerSecond,
            gpsSampleCount: snapshot.gpsSampleCount,
            acceptedSampleCount: snapshot.acceptedSampleCount,
            rejectedSampleCount: snapshot.rejectedSampleCount
        )
        telemetry.updateReliabilityDiagnostics(
            backgroundLocationEnabled: snapshot.backgroundLocationEnabled,
            idleTimerDisabled: IdleTimerController.isIdleTimerDisabled,
            activeDriveRecordID: snapshot.activeDriveRecordID,
            activeRecordPersisted: snapshot.activeRecordPersisted,
            finalized: liveTrip == nil ? true : false,
            lastCheckpointAt: snapshot.lastCheckpointAt,
            checkpointReason: snapshot.lastCheckpointReason,
            lastValidLocationAt: snapshot.lastValidLocationAt,
            lastValidLatitude: snapshot.lastValidLatitude,
            lastValidLongitude: snapshot.lastValidLongitude,
            recoveredSession: snapshot.recoveredSession,
            recoveryReason: snapshot.recoveryReason,
            finalizationReason: snapshot.endReason,
            canEndDriveManually: snapshot.canEndDriveManually,
            lastFinalizationAt: snapshot.lastFinalizationAt,
            stoppedElapsedSeconds: snapshot.stoppedElapsedSeconds,
            stopHoldDurationSeconds: snapshot.stopHoldDurationSeconds,
            stopSpeedMetersPerSecond: snapshot.stopSpeedMetersPerSecond,
            isFilteredSpeedValid: snapshot.isFilteredSpeedValid,
            lastValidMotionSampleAt: snapshot.lastValidMotionSampleAt,
            lastValidStoppedSampleAt: snapshot.lastValidStoppedSampleAt
        )
    }
}
