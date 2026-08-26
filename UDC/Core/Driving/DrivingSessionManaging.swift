import Foundation

/// Explicit drive-session lifecycle. Prefer this over boolean flags.
enum DriveSessionPhase: Equatable, Sendable {
    case idle
    case preparing
    case driving
    case stopped

    var displayName: String {
        switch self {
        case .idle: "Not Driving"
        case .preparing: "Preparing"
        case .driving: "Driving"
        case .stopped: "Paused"
        }
    }

    var isActivelyRecording: Bool {
        switch self {
        case .driving, .stopped: true
        case .idle, .preparing: false
        }
    }
}

enum DriveSessionStartReason: String, Equatable, Sendable {
    case sustainedSpeed = "Sustained speed"
    case sustainedDistance = "Sustained distance"
    case manual = "Manual"
}

enum DriveSessionEndReason: String, Equatable, Sendable {
    case extendedStop = "Extended stop"
    case discardedTooShort = "Discarded (too short)"
    case manualUserEnd = "Manual user end"
    case authorizationLost = "Authorization lost"
    case interrupted = "Interrupted"
    case staleRecovery = "Stale recovery finalize"
}

/// Tunable session / distance thresholds. Internal for now — not user-facing settings.
struct DriveSessionConfiguration: Equatable, Sendable {
    /// ~10 mph — above typical walking / GPS crawl.
    var startSpeedMetersPerSecond: Double = 4.5
    /// Must stay above start speed this long before committing a drive.
    var startHoldDuration: TimeInterval = 8
    /// Alternate start path: accumulate this much distance while preparing.
    var startMinimumDistanceMeters: Double = 45

    /// Below this, treat as stopped for pause / end detection (~2 mph).
    var stopSpeedMetersPerSecond: Double = 0.9
    /// End drive after remaining stopped this long (traffic lights / fuel stops).
    var stopHoldDuration: TimeInterval = 180

    /// Persist only if the trip clears both floors.
    var minimumPersistDistanceMeters: Double = 120
    var minimumPersistDuration: TimeInterval = 45

    /// Distance segment guards.
    var maxJumpMeters: Double = 75
    var maxSampleGapSeconds: TimeInterval = 10
    var minSegmentMeters: Double = 1.5
    var maxHorizontalAccuracyMeters: Double = 45
}

/// In-memory trip while recording. Persisted as `DriveRecord` on completion.
struct LiveTrip: Equatable, Sendable {
    var id: UUID
    var vehicleID: UUID?
    var vehicleName: String
    var startedAt: Date
    var distanceMeters: Double
    var maximumSpeedMetersPerSecond: Double
    var preferredSpeedUnit: SpeedUnit
    var preferredDistanceUnit: DistanceUnit
    var speedSource: SpeedSource

    func duration(at date: Date = .now) -> TimeInterval {
        max(0, date.timeIntervalSince(startedAt))
    }

    func averageSpeedMetersPerSecond(at date: Date = .now) -> Double {
        let duration = duration(at: date)
        guard duration > 0.5 else { return 0 }
        return distanceMeters / duration
    }
}

struct DrivingEngineSnapshot: Equatable, Sendable {
    var phase: DriveSessionPhase = .idle
    var liveTrip: LiveTrip?
    var startReason: DriveSessionStartReason?
    var endReason: DriveSessionEndReason?
    var movementThresholdMetersPerSecond: Double = DriveSessionConfiguration().startSpeedMetersPerSecond
    var gpsSampleCount: Int = 0
    var acceptedSampleCount: Int = 0
    var rejectedSampleCount: Int = 0
    var lastCompletedTripID: UUID?

    // Durability / lifecycle diagnostics surfaces
    var activeDriveRecordID: UUID?
    var activeRecordPersisted: Bool = false
    var isFinalized: Bool = true
    var lastCheckpointAt: Date?
    var lastCheckpointReason: DriveCheckpointReason?
    var lastValidLocationAt: Date?
    var lastValidLatitude: Double?
    var lastValidLongitude: Double?
    var recoveredSession: Bool = false
    var recoveryReason: DriveRecoveryReason = .none
    var backgroundLocationEnabled: Bool = false
    var lastFinalizationAt: Date?
    /// True when a durable in-progress drive can be manually finalized.
    var canEndDriveManually: Bool = false
    /// Elapsed time in `.stopped` (Paused) from valid stopped observations only.
    var stoppedElapsedSeconds: TimeInterval?
    /// Configured automatic-end hold while stopped.
    var stopHoldDurationSeconds: TimeInterval = DriveSessionConfiguration().stopHoldDuration
    /// Configured stop-speed threshold (filtered m/s).
    var stopSpeedMetersPerSecond: Double = DriveSessionConfiguration().stopSpeedMetersPerSecond
    /// Whether the latest telemetry sample had a usable filtered speed.
    var isFilteredSpeedValid: Bool = false
    var lastValidMotionSampleAt: Date?
    var lastValidStoppedSampleAt: Date?

    var currentDistanceMeters: Double { liveTrip?.distanceMeters ?? 0 }
    var currentMaxSpeedMetersPerSecond: Double { liveTrip?.maximumSpeedMetersPerSecond ?? 0 }

    static let idle = DrivingEngineSnapshot()
}

/// Pure helpers for haversine distance and trip statistic math (unit-testable).
enum TripMath {
    static func haversineMeters(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ) -> Double {
        let earthRadius = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180)
            * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }

    static func averageSpeedMetersPerSecond(distanceMeters: Double, durationSeconds: TimeInterval) -> Double {
        guard durationSeconds > 0.5, distanceMeters >= 0 else { return 0 }
        return distanceMeters / durationSeconds
    }

    static func shouldAcceptDistanceSegment(
        distanceMeters: Double,
        intervalSeconds: TimeInterval,
        configuration: DriveSessionConfiguration
    ) -> Bool {
        guard intervalSeconds > 0, intervalSeconds <= configuration.maxSampleGapSeconds else { return false }
        guard distanceMeters >= configuration.minSegmentMeters else { return false }
        guard distanceMeters <= configuration.maxJumpMeters else { return false }
        // Reject impossible implied speeds (~200 mph).
        let implied = distanceMeters / intervalSeconds
        return implied <= 90
    }
}

/// Legacy no-op session manager retained for protocol compatibility during transition.
enum DrivingSessionState: Equatable {
    case idle
    case driving(startedAt: Date)
}

protocol DrivingSessionManaging {
    var state: DrivingSessionState { get }
    func start()
    func stop()
}

final class NoOpDrivingSessionManager: DrivingSessionManaging {
    private(set) var state: DrivingSessionState = .idle
    func start() { state = .driving(startedAt: .now) }
    func stop() { state = .idle }
}
