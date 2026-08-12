import Foundation
import SwiftData

@Model
final class VehicleProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var year: Int?
    var make: String?
    var model: String?
    var category: VehicleCategory
    var preferredSpeedUnit: SpeedUnit
    var preferredDistanceUnit: DistanceUnit
    var isActive: Bool
    var dataSourceMode: VehicleDataSourceMode
    var createdAt: Date
    var modifiedAt: Date
    /// JSON-encoded `PerformanceBests` for this vehicle.
    var performanceBestsJSON: String?

    init(id: UUID = UUID(), name: String, year: Int? = nil, make: String? = nil, model: String? = nil,
         category: VehicleCategory = .car, preferredSpeedUnit: SpeedUnit = .milesPerHour,
         preferredDistanceUnit: DistanceUnit = .miles, isActive: Bool = false,
         dataSourceMode: VehicleDataSourceMode = .gpsOnly, createdAt: Date = .now, modifiedAt: Date = .now,
         performanceBestsJSON: String? = nil) {
        self.id = id; self.name = name; self.year = year; self.make = make; self.model = model
        self.category = category; self.preferredSpeedUnit = preferredSpeedUnit
        self.preferredDistanceUnit = preferredDistanceUnit; self.isActive = isActive
        self.dataSourceMode = dataSourceMode; self.createdAt = createdAt; self.modifiedAt = modifiedAt
        self.performanceBestsJSON = performanceBestsJSON
    }

    static func selectActive(_ selected: VehicleProfile, among vehicles: [VehicleProfile]) {
        vehicles.forEach { $0.isActive = ($0.id == selected.id); $0.modifiedAt = .now }
    }

    /// Updates identity fields on the existing record. Does not insert a new vehicle.
    func applyEdits(
        name: String,
        year: Int?,
        make: String?,
        model: String?,
        dataSourceMode: VehicleDataSourceMode
    ) {
        self.name = name
        self.year = year
        self.make = make
        self.model = model
        self.dataSourceMode = dataSourceMode
        self.modifiedAt = .now
    }
}

enum VehicleCategory: String, Codable, CaseIterable { case car, truck, motorcycle, other }

enum SpeedUnit: String, Codable, CaseIterable {
    case milesPerHour = "mph"
    case kilometersPerHour = "km/h"

    var settingsLabel: String {
        switch self {
        case .milesPerHour: "MPH"
        case .kilometersPerHour: "km/h"
        }
    }

    var settingsDetail: String {
        switch self {
        case .milesPerHour: "Miles per hour"
        case .kilometersPerHour: "Kilometers per hour"
        }
    }
}

enum DistanceUnit: String, Codable, CaseIterable {
    case miles = "mi"
    case kilometers = "km"

    var settingsLabel: String {
        switch self {
        case .miles: "Miles"
        case .kilometers: "Kilometers"
        }
    }

    var settingsDetail: String {
        switch self {
        case .miles: "Distance in miles"
        case .kilometers: "Distance in kilometers"
        }
    }
}

enum VehicleDataSourceMode: String, Codable, CaseIterable, Identifiable {
    case gpsOnly, obdEnhanced, manualDriveline
    var id: Self { self }
    var displayName: String {
        switch self {
        case .gpsOnly: "GPS Only"
        case .obdEnhanced: "OBD-II Enhanced"
        case .manualDriveline: "Manual Driveline"
        }
    }
}

enum RPMSource: String, Codable, CaseIterable { case obdII, estimated, hidden }
