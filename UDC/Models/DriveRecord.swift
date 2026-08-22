import Foundation
import SwiftData

/// Persisted drive. In-progress rows (`isFinalized == false`) are durable checkpoints; history shows finalized only.
@Model
final class DriveRecord {
    @Attribute(.unique) var id: UUID
    var vehicleID: UUID?
    var vehicleName: String
    var startedAt: Date
    var endedAt: Date
    var distanceMeters: Double
    var durationSeconds: Double
    var averageSpeedMetersPerSecond: Double
    var maximumSpeedMetersPerSecond: Double
    var speedUnitRaw: String
    var distanceUnitRaw: String
    var speedSourceRaw: String
    var createdAt: Date

    /// `true` while the drive is active / recoverable; `false` for Drive History entries.
    /// Defaults to `false` so legacy completed rows remain visible after schema migration.
    var isInProgress: Bool = false
    var sessionPhaseRaw: String?
    var lastValidLatitude: Double?
    var lastValidLongitude: Double?
    var lastValidLocationAt: Date?
    var lastCheckpointAt: Date?
    var checkpointReasonRaw: String?
    var recoveredFromInterruption: Bool = false

    /// Reserved for future polyline / waypoint summaries.
    var routeSummaryJSON: String?
    /// Reserved for future performance attachments.
    var performanceSummaryJSON: String?
    /// Reserved for future fuel economy attachments.
    var fuelSummaryJSON: String?
    var notes: String?

    init(
        id: UUID = UUID(),
        vehicleID: UUID? = nil,
        vehicleName: String,
        startedAt: Date,
        endedAt: Date,
        distanceMeters: Double,
        durationSeconds: Double,
        averageSpeedMetersPerSecond: Double,
        maximumSpeedMetersPerSecond: Double,
        speedUnit: SpeedUnit,
        distanceUnit: DistanceUnit,
        speedSource: SpeedSource,
        createdAt: Date = .now,
        isFinalized: Bool = true,
        sessionPhase: DriveSessionPhase? = nil,
        lastValidLatitude: Double? = nil,
        lastValidLongitude: Double? = nil,
        lastValidLocationAt: Date? = nil,
        lastCheckpointAt: Date? = nil,
        checkpointReason: DriveCheckpointReason? = nil,
        recoveredFromInterruption: Bool = false
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.vehicleName = vehicleName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.averageSpeedMetersPerSecond = averageSpeedMetersPerSecond
        self.maximumSpeedMetersPerSecond = maximumSpeedMetersPerSecond
        self.speedUnitRaw = speedUnit.rawValue
        self.distanceUnitRaw = distanceUnit.rawValue
        self.speedSourceRaw = speedSource.rawValue
        self.createdAt = createdAt
        self.isInProgress = !isFinalized
        self.sessionPhaseRaw = sessionPhase.map(Self.phaseRaw(from:))
        self.lastValidLatitude = lastValidLatitude
        self.lastValidLongitude = lastValidLongitude
        self.lastValidLocationAt = lastValidLocationAt
        self.lastCheckpointAt = lastCheckpointAt
        self.checkpointReasonRaw = checkpointReason?.rawValue
        self.recoveredFromInterruption = recoveredFromInterruption
    }

    var isFinalized: Bool {
        get { !isInProgress }
        set { isInProgress = !newValue }
    }

    var speedUnit: SpeedUnit {
        SpeedUnit(rawValue: speedUnitRaw) ?? .milesPerHour
    }

    var distanceUnit: DistanceUnit {
        DistanceUnit(rawValue: distanceUnitRaw) ?? .miles
    }

    var speedSource: SpeedSource {
        SpeedSource(rawValue: speedSourceRaw) ?? .gps
    }

    var displayDistance: Double {
        distanceUnit.value(fromMeters: distanceMeters)
    }

    var displayAverageSpeed: Double {
        speedUnit.value(fromMetersPerSecond: averageSpeedMetersPerSecond)
    }

    var displayMaximumSpeed: Double {
        speedUnit.value(fromMetersPerSecond: maximumSpeedMetersPerSecond)
    }

    var performanceRuns: [PerformanceRunSummary] {
        PerformanceAttachment.decode(from: performanceSummaryJSON)
    }

    var persistedSessionPhase: DriveSessionPhase? {
        guard let sessionPhaseRaw else { return nil }
        return Self.phase(fromRaw: sessionPhaseRaw)
    }

    static func phaseRaw(from phase: DriveSessionPhase) -> String {
        switch phase {
        case .idle: "idle"
        case .preparing: "preparing"
        case .driving: "driving"
        case .stopped: "stopped"
        }
    }

    static func phase(fromRaw raw: String) -> DriveSessionPhase? {
        switch raw {
        case "idle": .idle
        case "preparing": .preparing
        case "driving": .driving
        case "stopped": .stopped
        default: nil
        }
    }
}

extension SpeedSource: RawRepresentable {
    public typealias RawValue = String

    public init?(rawValue: String) {
        switch rawValue {
        case "none": self = .none
        case "gps": self = .gps
        case "estimated": self = .estimated
        case "obd": self = .obd
        default: return nil
        }
    }

    public var rawValue: String {
        switch self {
        case .none: "none"
        case .gps: "gps"
        case .estimated: "estimated"
        case .obd: "obd"
        }
    }
}

extension DistanceUnit {
    func value(fromMeters meters: Double) -> Double {
        switch self {
        case .miles: meters / 1609.344
        case .kilometers: meters / 1000
        }
    }

    func meters(fromDisplayValue value: Double) -> Double {
        switch self {
        case .miles: value * 1609.344
        case .kilometers: value * 1000
        }
    }
}
