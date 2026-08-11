import Foundation
import Observation
import SwiftData

/// Observes `DrivingTelemetryService`, detects sessions, accumulates trip stats, and persists completed drives.
@Observable
@MainActor
final class DrivingEngine {
    private(set) var snapshot: DrivingEngineSnapshot = .idle

    private let telemetry: DrivingTelemetryService
    private let configuration: DriveSessionConfiguration
    private var modelContext: ModelContext?

    private var activeVehicleID: UUID?
    private var activeVehicleName: String = "Vehicle"
    private var preferredSpeedUnit: SpeedUnit = .milesPerHour
    private var preferredDistanceUnit: DistanceUnit = .miles

    private var preparingSince: Date?
    private var stoppedSince: Date?
    private var preparingDistanceMeters: Double = 0

    private var lastAcceptedCoordinate: (lat: Double, lon: Double)?
    private var lastAcceptedTimestamp: Date?

    private var liveTrip: LiveTrip?
    private var phase: DriveSessionPhase = .idle

    init(
        telemetry: DrivingTelemetryService,
        configuration: DriveSessionConfiguration = .init()
    ) {
        self.telemetry = telemetry
        self.configuration = configuration
        snapshot.movementThresholdMetersPerSecond = configuration.startSpeedMetersPerSecond
        bindTelemetry()
    }

    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
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

    // MARK: - Telemetry

    private func bindTelemetry() {
        telemetry.onStateUpdate = { [weak self] state in
            self?.handle(state: state)
        }
    }

    private func handle(state: DrivingState) {
        snapshot.gpsSampleCount += 1

        let filtered = state.filteredSpeedMetersPerSecond
        let accepted = filtered != nil && state.gpsStatus != .unavailable
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

        let speed = filtered ?? 0
        let now = state.timestamp ?? .now
        accumulateDistanceIfNeeded(state: state, now: now)

        switch phase {
        case .idle:
            considerPreparing(speed: speed, now: now)
        case .preparing:
            considerStart(speed: speed, now: now)
        case .driving:
            updateLiveTrip(speed: speed)
            if speed <= configuration.stopSpeedMetersPerSecond {
                phase = .stopped
                stoppedSince = now
            }
        case .stopped:
            updateLiveTrip(speed: speed)
            if speed > configuration.stopSpeedMetersPerSecond {
                phase = .driving
                stoppedSince = nil
            } else if let stoppedSince,
                      now.timeIntervalSince(stoppedSince) >= configuration.stopHoldDuration {
                completeTrip(at: now, reason: .extendedStop)
            }
        }

        publishSnapshot()
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
            // Fell back to near-stop before commitment — abort prepare.
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
        stoppedSince = nil
        preparingDistanceMeters = 0
        snapshot.startReason = reason
        snapshot.endReason = nil
        snapshot.lastCompletedTripID = nil
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

    private func completeTrip(at end: Date, reason: DriveSessionEndReason) {
        guard let trip = liveTrip else {
            resetToIdle(reason: reason)
            return
        }

        let duration = max(0, end.timeIntervalSince(trip.startedAt))
        let distance = trip.distanceMeters
        let meetsFloor = distance >= configuration.minimumPersistDistanceMeters
            && duration >= configuration.minimumPersistDuration

        if meetsFloor {
            persist(trip: trip, endedAt: end)
            snapshot.lastCompletedTripID = trip.id
            snapshot.endReason = reason
        } else {
            snapshot.endReason = .discardedTooShort
        }

        liveTrip = nil
        phase = .idle
        preparingSince = nil
        stoppedSince = nil
        preparingDistanceMeters = 0
        lastAcceptedCoordinate = nil
        lastAcceptedTimestamp = nil
        publishSnapshot()
    }

    private func resetToIdle(reason: DriveSessionEndReason?) {
        phase = .idle
        liveTrip = nil
        preparingSince = nil
        stoppedSince = nil
        preparingDistanceMeters = 0
        lastAcceptedCoordinate = nil
        lastAcceptedTimestamp = nil
        if let reason {
            snapshot.endReason = reason
        }
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
        // Only accumulate while preparing or actively recording.
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

    // MARK: - Persistence

    private func persist(trip: LiveTrip, endedAt: Date) {
        guard let modelContext else { return }
        let duration = max(0, endedAt.timeIntervalSince(trip.startedAt))
        let average = TripMath.averageSpeedMetersPerSecond(
            distanceMeters: trip.distanceMeters,
            durationSeconds: duration
        )
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
            speedSource: trip.speedSource
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    private func publishSnapshot() {
        let now = Date.now
        var next = snapshot
        next.phase = phase
        next.liveTrip = liveTrip
        next.movementThresholdMetersPerSecond = configuration.startSpeedMetersPerSecond
        if let trip = liveTrip {
            // Refresh computed view of live trip for observers.
            next.liveTrip = trip
            _ = trip.duration(at: now)
        }
        snapshot = next

        // Mirror into telemetry diagnostics for the Diagnostics screen.
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
    }
}
