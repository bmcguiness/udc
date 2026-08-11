import XCTest
@testable import UDC

final class GPSSpeedProcessingTests: XCTestCase {
    private func snapshot(
        speed: Double?,
        accuracy: Double = 10,
        age: TimeInterval = 0.2
    ) -> LocationSnapshot {
        LocationSnapshot(
            latitude: 37.33,
            longitude: -122.01,
            altitudeMeters: 20,
            speedMetersPerSecond: speed,
            courseDegrees: 90,
            courseAccuracyDegrees: 5,
            headingDegrees: 90,
            headingAccuracyDegrees: 5,
            horizontalAccuracyMeters: accuracy,
            verticalAccuracyMeters: 8,
            timestamp: Date().addingTimeInterval(-age)
        )
    }

    func testSpeedConversionMPHAndKPH() {
        let mps = 10.0
        XCTAssertEqual(SpeedUnit.milesPerHour.value(fromMetersPerSecond: mps), mps * 2.2369362920544, accuracy: 0.0001)
        XCTAssertEqual(SpeedUnit.kilometersPerHour.value(fromMetersPerSecond: mps), 36.0, accuracy: 0.0001)
    }

    func testRejectsNegativeSpeed() {
        let result = GPSSpeedFilter.evaluate(snapshot: snapshot(speed: -1))
        XCTAssertNil(result.acceptedSpeedMetersPerSecond)
        XCTAssertEqual(result.rejection, .invalidSpeed)
    }

    func testRejectsStaleSamples() {
        let result = GPSSpeedFilter.evaluate(snapshot: snapshot(speed: 12, age: 12))
        XCTAssertNil(result.acceptedSpeedMetersPerSecond)
        XCTAssertEqual(result.rejection, .stale)
    }

    func testRejectsInaccurateFixes() {
        let result = GPSSpeedFilter.evaluate(snapshot: snapshot(speed: 12, accuracy: 120))
        XCTAssertNil(result.acceptedSpeedMetersPerSecond)
        XCTAssertEqual(result.rejection, .inaccurate)
    }

    func testRejectsInvalidAccuracy() {
        let result = GPSSpeedFilter.evaluate(snapshot: snapshot(speed: 12, accuracy: -1))
        XCTAssertEqual(result.rejection, .invalidAccuracy)
    }

    func testStopThresholdZeroesJitter() {
        let result = GPSSpeedFilter.evaluate(snapshot: snapshot(speed: 0.2))
        XCTAssertEqual(result.acceptedSpeedMetersPerSecond, 0)
        XCTAssertFalse(result.isMoving)
    }

    func testAcceptsValidMovingSpeed() {
        let result = GPSSpeedFilter.evaluate(snapshot: snapshot(speed: 15))
        XCTAssertEqual(result.acceptedSpeedMetersPerSecond, 15)
        XCTAssertTrue(result.isMoving)
    }

    func testSmootherReducesStepChange() {
        var smoother = SpeedSmoother(alphaMoving: 0.4, alphaStopped: 0.7)
        let first = smoother.push(filteredMetersPerSecond: 10, isMoving: true)
        XCTAssertEqual(first, 10, accuracy: 0.0001)
        let second = smoother.push(filteredMetersPerSecond: 20, isMoving: true)
        XCTAssertEqual(second, 14, accuracy: 0.0001)
    }

    func testSmootherSnapsTowardZeroWhenStopped() {
        var smoother = SpeedSmoother()
        _ = smoother.push(filteredMetersPerSecond: 8, isMoving: true)
        let stopped = smoother.push(filteredMetersPerSecond: 0, isMoving: false)
        XCTAssertLessThan(stopped, 8)
    }

    func testGPSStatusPermissionNeeded() {
        let status = GPSStatusResolver.resolve(
            authorization: .notDetermined,
            locationServicesEnabled: true,
            latestSnapshot: nil,
            filterResult: nil
        )
        XCTAssertEqual(status, .permissionNeeded)
    }

    func testGPSStatusReadyForGoodFix() {
        let snap = snapshot(speed: 12, accuracy: 8)
        let filter = GPSSpeedFilter.evaluate(snapshot: snap)
        let status = GPSStatusResolver.resolve(
            authorization: .authorizedWhenInUse,
            locationServicesEnabled: true,
            latestSnapshot: snap,
            filterResult: filter
        )
        XCTAssertEqual(status, .ready)
    }

    func testSpeedBandNormalizationUsesConvertedSpeed() {
        let mph = SpeedUnit.milesPerHour.value(fromMetersPerSecond: 26.8224) // ~60 mph
        let progress = SpeedBandNormalizer.progress(speed: mph, maximum: 120)
        XCTAssertEqual(progress, 0.5, accuracy: 0.02)
    }
}

@MainActor
final class DrivingTelemetryServiceTests: XCTestCase {
    func testTelemetryMapsAuthorizedSnapshotIntoDisplayedSpeed() async {
        let provider = NoOpLocationProvider()
        provider.setAuthorization(.authorizedWhenInUse)
        let service = DrivingTelemetryService(locationProvider: provider)
        service.updateActiveVehicle(name: "Test Car", speedUnit: .milesPerHour)
        service.start()

        let mps = 13.4112 // ~30 mph
        provider.publish(
            LocationSnapshot(
                latitude: 37.33,
                longitude: -122.01,
                altitudeMeters: 10,
                speedMetersPerSecond: mps,
                courseDegrees: 10,
                courseAccuracyDegrees: 3,
                headingDegrees: 10,
                headingAccuracyDegrees: 3,
                horizontalAccuracyMeters: 6,
                verticalAccuracyMeters: 8,
                timestamp: .now
            )
        )

        // Allow MainActor callback hop.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(service.state.gpsStatus, .ready)
        XCTAssertEqual(service.state.speedSource, .gps)
        XCTAssertEqual(service.state.activeVehicleName, "Test Car")
        XCTAssertGreaterThan(service.state.displayedSpeed, 25)
        XCTAssertLessThan(service.state.displayedSpeed, 35)
        XCTAssertNotNil(service.diagnostics.latitude)
    }

    func testDeniedAuthorizationClearsLiveSpeed() async {
        let provider = NoOpLocationProvider()
        let service = DrivingTelemetryService(locationProvider: provider)
        provider.setAuthorization(.denied)
        await Task.yield()
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(service.state.gpsStatus, .permissionNeeded)
        XCTAssertEqual(service.state.displayedSpeed, 0)
        XCTAssertEqual(service.state.speedSource, .none)
    }
}
