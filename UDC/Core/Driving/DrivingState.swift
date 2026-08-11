import Foundation

enum SpeedSource: Equatable, Sendable {
    case none
    case gps
    case estimated
    case obd

    var displayName: String {
        switch self {
        case .none: "None"
        case .gps: "GPS"
        case .estimated: "Estimated"
        case .obd: "OBD-II"
        }
    }
}

enum GPSStatus: Equatable, Sendable {
    case permissionNeeded
    case locationDisabled
    case searching
    case poorSignal
    case ready
    case unavailable

    var badgeTitle: String {
        switch self {
        case .permissionNeeded: "Permission Needed"
        case .locationDisabled: "Location Disabled"
        case .searching: "Searching"
        case .poorSignal: "Poor GPS"
        case .ready: "GPS Ready"
        case .unavailable: "Unavailable"
        }
    }
}

/// Single normalized driving telemetry surface for Dashboard and future features.
struct DrivingState: Equatable, Sendable {
    var authorizationStatus: LocationAuthorizationStatus = .notDetermined
    var isLocationServicesEnabled: Bool = true
    var gpsStatus: GPSStatus = .permissionNeeded
    var speedSource: SpeedSource = .none

    /// Preferred display unit from the active vehicle.
    var preferredSpeedUnit: SpeedUnit = .milesPerHour
    var activeVehicleName: String?

    var rawSpeedMetersPerSecond: Double?
    var filteredSpeedMetersPerSecond: Double?
    /// Smoothed speed already converted into `preferredSpeedUnit`.
    var displayedSpeed: Double = 0

    var isMoving: Bool = false

    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracyMeters: Double?
    var verticalAccuracyMeters: Double?
    var headingDegrees: Double?
    var headingAccuracyDegrees: Double?
    var courseDegrees: Double?
    var timestamp: Date?
    var locationAgeSeconds: TimeInterval?

    static let idle = DrivingState()
}

extension SpeedUnit {
    /// Convert meters/second into this unit.
    func value(fromMetersPerSecond metersPerSecond: Double) -> Double {
        switch self {
        case .milesPerHour:
            metersPerSecond * 2.236_936_292_054_4
        case .kilometersPerHour:
            metersPerSecond * 3.6
        }
    }

    func metersPerSecond(fromDisplayValue value: Double) -> Double {
        switch self {
        case .milesPerHour:
            value / 2.236_936_292_054_4
        case .kilometersPerHour:
            value / 3.6
        }
    }

    /// Reasonable SpeedBand ceiling for this unit.
    var speedBandMaximum: Double {
        switch self {
        case .milesPerHour: 120
        case .kilometersPerHour: 200
        }
    }
}
