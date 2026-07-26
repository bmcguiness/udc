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

    init(id: UUID = UUID(), name: String, year: Int? = nil, make: String? = nil, model: String? = nil,
         category: VehicleCategory = .car, preferredSpeedUnit: SpeedUnit = .milesPerHour,
         preferredDistanceUnit: DistanceUnit = .miles, isActive: Bool = false,
         dataSourceMode: VehicleDataSourceMode = .gpsOnly, createdAt: Date = .now, modifiedAt: Date = .now) {
        self.id = id; self.name = name; self.year = year; self.make = make; self.model = model
        self.category = category; self.preferredSpeedUnit = preferredSpeedUnit
        self.preferredDistanceUnit = preferredDistanceUnit; self.isActive = isActive
        self.dataSourceMode = dataSourceMode; self.createdAt = createdAt; self.modifiedAt = modifiedAt
    }

    static func selectActive(_ selected: VehicleProfile, among vehicles: [VehicleProfile]) {
        vehicles.forEach { $0.isActive = ($0.id == selected.id); $0.modifiedAt = .now }
    }
}

enum VehicleCategory: String, Codable, CaseIterable { case car, truck, motorcycle, other }
enum SpeedUnit: String, Codable, CaseIterable { case milesPerHour = "mph"; case kilometersPerHour = "km/h" }
enum DistanceUnit: String, Codable, CaseIterable { case miles = "mi"; case kilometers = "km" }

enum VehicleDataSourceMode: String, Codable, CaseIterable, Identifiable {
    case gpsOnly, obdEnhanced, manualDriveline
    var id: Self { self }
    var displayName: String {
        switch self { case .gpsOnly: "GPS only"; case .obdEnhanced: "OBD-II enhanced"; case .manualDriveline: "Manual driveline" }
    }
}

enum RPMSource: String, Codable, CaseIterable { case obdII, estimated, hidden }
