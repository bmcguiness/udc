import XCTest
@testable import UDC

final class VehicleProfileTests: XCTestCase {
    func testNewVehicleDefaults() { let vehicle = VehicleProfile(name: "Roadster"); XCTAssertEqual(vehicle.name, "Roadster"); XCTAssertEqual(vehicle.category, .car); XCTAssertEqual(vehicle.preferredSpeedUnit, .milesPerHour); XCTAssertEqual(vehicle.preferredDistanceUnit, .miles); XCTAssertEqual(vehicle.dataSourceMode, .gpsOnly); XCTAssertFalse(vehicle.isActive) }
    func testSelectingActiveVehicleMakesSelectionExclusive() { let first = VehicleProfile(name: "First", isActive: true); let second = VehicleProfile(name: "Second"); VehicleProfile.selectActive(second, among: [first, second]); XCTAssertFalse(first.isActive); XCTAssertTrue(second.isActive) }
    func testDataSourceModes() { XCTAssertEqual(Set(VehicleDataSourceMode.allCases.map(\.rawValue)), ["gpsOnly", "obdEnhanced", "manualDriveline"]) }
    func testRPMSources() { XCTAssertEqual(Set(RPMSource.allCases.map(\.rawValue)), ["obdII", "estimated", "hidden"]) }
}
