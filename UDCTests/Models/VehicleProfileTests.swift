import XCTest
@testable import UDC
import SwiftData

final class VehicleProfileTests: XCTestCase {
    func testNewVehicleDefaults() {
        let vehicle = VehicleProfile(name: "Roadster")
        XCTAssertEqual(vehicle.name, "Roadster")
        XCTAssertEqual(vehicle.category, .car)
        XCTAssertEqual(vehicle.preferredSpeedUnit, .milesPerHour)
        XCTAssertEqual(vehicle.preferredDistanceUnit, .miles)
        XCTAssertEqual(vehicle.dataSourceMode, .gpsOnly)
        XCTAssertFalse(vehicle.isActive)
    }

    func testSelectingActiveVehicleMakesSelectionExclusive() {
        let first = VehicleProfile(name: "First", isActive: true)
        let second = VehicleProfile(name: "Second")
        VehicleProfile.selectActive(second, among: [first, second])
        XCTAssertFalse(first.isActive)
        XCTAssertTrue(second.isActive)
    }

    func testDataSourceModes() {
        XCTAssertEqual(Set(VehicleDataSourceMode.allCases.map(\.rawValue)), ["gpsOnly", "obdEnhanced", "manualDriveline"])
    }

    func testRPMSources() {
        XCTAssertEqual(Set(RPMSource.allCases.map(\.rawValue)), ["obdII", "estimated", "hidden"])
    }

    func testApplyEditsUpdatesExistingRecordWithoutChangingIdentity() {
        let vehicle = VehicleProfile(
            name: "Original",
            year: 1965,
            make: "Ford",
            model: "Mustang",
            isActive: true,
            dataSourceMode: .gpsOnly
        )
        let originalID = vehicle.id

        vehicle.applyEdits(
            name: "Updated GT",
            year: 1967,
            make: "Ford",
            model: "Mustang Fastback",
            dataSourceMode: .manualDriveline
        )

        XCTAssertEqual(vehicle.id, originalID)
        XCTAssertEqual(vehicle.name, "Updated GT")
        XCTAssertEqual(vehicle.year, 1967)
        XCTAssertEqual(vehicle.make, "Ford")
        XCTAssertEqual(vehicle.model, "Mustang Fastback")
        XCTAssertEqual(vehicle.dataSourceMode, .manualDriveline)
        XCTAssertTrue(vehicle.isActive, "Active state should survive identity edits")
    }

    @MainActor
    func testEditingPersistedVehicleDoesNotCreateDuplicate() throws {
        let container = try ModelContainer(
            for: VehicleProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let vehicle = VehicleProfile(name: "One", isActive: true, dataSourceMode: .gpsOnly)
        context.insert(vehicle)
        try context.save()

        vehicle.applyEdits(
            name: "Still One",
            year: 2020,
            make: "Porsche",
            model: "911",
            dataSourceMode: .obdEnhanced
        )
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<VehicleProfile>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Still One")
        XCTAssertTrue(fetched.first?.isActive == true)
        XCTAssertEqual(fetched.first?.dataSourceMode, .obdEnhanced)
    }

    @MainActor
    func testUnitPreferencesPersistOnVehicleProfile() throws {
        let container = try ModelContainer(
            for: VehicleProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let vehicle = VehicleProfile(name: "Touring", isActive: true)
        context.insert(vehicle)
        try context.save()

        vehicle.preferredSpeedUnit = .kilometersPerHour
        vehicle.preferredDistanceUnit = .kilometers
        vehicle.modifiedAt = .now
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<VehicleProfile>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.preferredSpeedUnit, .kilometersPerHour)
        XCTAssertEqual(fetched.first?.preferredDistanceUnit, .kilometers)
    }

    func testPerformanceDistanceResultsIncludeTopSpeed() {
        let eighth = PerformanceRunResult(
            title: "1/8 Mile",
            subtitle: "Short strip",
            elapsedTime: "9.84",
            topSpeed: "72.4",
            topSpeedUnit: "mph",
            symbol: "road.lanes"
        )
        let sixty = PerformanceRunResult(
            title: "0–60",
            subtitle: "Benchmark",
            elapsedTime: "5.92",
            symbol: "flag.checkered"
        )

        XCTAssertTrue(eighth.includesTopSpeed)
        XCTAssertFalse(sixty.includesTopSpeed)
    }
}

final class SpeedBandNormalizerTests: XCTestCase {
    func testProgressClampsToUnitInterval() {
        XCTAssertEqual(SpeedBandNormalizer.progress(speed: 0, maximum: 120), 0, accuracy: 0.0001)
        XCTAssertEqual(SpeedBandNormalizer.progress(speed: 60, maximum: 120), 0.5, accuracy: 0.0001)
        XCTAssertEqual(SpeedBandNormalizer.progress(speed: 120, maximum: 120), 1, accuracy: 0.0001)
        XCTAssertEqual(SpeedBandNormalizer.progress(speed: 200, maximum: 120), 1, accuracy: 0.0001)
        XCTAssertEqual(SpeedBandNormalizer.progress(speed: -10, maximum: 120), 0, accuracy: 0.0001)
    }

    func testProgressHandlesNonPositiveMaximum() {
        XCTAssertEqual(SpeedBandNormalizer.progress(speed: 40, maximum: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(SpeedBandNormalizer.progress(speed: 40, maximum: -20), 0, accuracy: 0.0001)
    }
}
