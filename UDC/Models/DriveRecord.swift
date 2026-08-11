import Foundation
import SwiftData

/// Persisted completed drive. Future route/performance/fuel payloads can attach without reshaping core stats.
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
        createdAt: Date = .now
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
