import SwiftData
import XCTest
@testable import UDC

final class TripMathTests: XCTestCase {
    func testHaversineKnownShortSegment() {
        let meters = TripMath.haversineMeters(
            lat1: 37.330000, lon1: -122.010000,
            lat2: 37.330450, lon2: -122.010000
        )
        XCTAssertEqual(meters, 50, accuracy: 5)
    }

    func testAverageSpeedUsesDrivingDuration() {
        let avg = TripMath.averageSpeedMetersPerSecond(distanceMeters: 100, durationSeconds: 10)
        XCTAssertEqual(avg, 10, accuracy: 0.0001)
        XCTAssertEqual(TripMath.averageSpeedMetersPerSecond(distanceMeters: 100, durationSeconds: 0), 0)
    }

    func testRejectsNoisyDistanceSegments() {
        let config = DriveSessionConfiguration()
        XCTAssertFalse(
            TripMath.shouldAcceptDistanceSegment(
                distanceMeters: 0.5,
                intervalSeconds: 1,
                configuration: config
            )
        )
        XCTAssertFalse(
            TripMath.shouldAcceptDistanceSegment(
                distanceMeters: 200,
                intervalSeconds: 1,
                configuration: config
            )
        )
        XCTAssertFalse(
            TripMath.shouldAcceptDistanceSegment(
                distanceMeters: 20,
                intervalSeconds: 20,
                configuration: config
            )
        )
        XCTAssertTrue(
            TripMath.shouldAcceptDistanceSegment(
                distanceMeters: 20,
                intervalSeconds: 2,
                configuration: config
            )
        )
    }
}

@MainActor
final class DrivingEngineTests: XCTestCase {
    private var provider: NoOpLocationProvider!
    private var telemetry: DrivingTelemetryService!
    private var engine: DrivingEngine!
    private var container: ModelContainer!
    private var context: ModelContext!
    /// Anchor near "now" so GPS age filtering accepts samples.
    private var clock: Date = .now

    private let testConfig = DriveSessionConfiguration(
        startSpeedMetersPerSecond: 4.5,
        startHoldDuration: 0.4,
        startMinimumDistanceMeters: 500,
        stopSpeedMetersPerSecond: 0.9,
        stopHoldDuration: 0.4,
        minimumPersistDistanceMeters: 30,
        minimumPersistDuration: 0.3,
        maxJumpMeters: 120,
        maxSampleGapSeconds: 15,
        minSegmentMeters: 1.0,
        maxHorizontalAccuracyMeters: 45
    )

    override func setUp() async throws {
        provider = NoOpLocationProvider()
        provider.setAuthorization(.authorizedWhenInUse)
        telemetry = DrivingTelemetryService(locationProvider: provider)
        engine = DrivingEngine(telemetry: telemetry, configuration: testConfig)
        container = try ModelContainer(
            for: DriveRecord.self, VehicleProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        engine.attach(modelContext: context)
        engine.updateActiveVehicle(
            id: UUID(),
            name: "Test Vehicle",
            speedUnit: .milesPerHour,
            distanceUnit: .miles
        )
        telemetry.start()
        clock = Date().addingTimeInterval(-0.15)
        await settle()
    }

    override func tearDown() async throws {
        engine = nil
        telemetry = nil
        provider = nil
        context = nil
        container = nil
    }

    func testSessionStartsAfterSustainedSpeed() async {
        XCTAssertEqual(engine.snapshot.phase, .idle)

        await publishMoving(speed: 12, lat: 37.3300, lon: -122.0100)
        XCTAssertEqual(engine.snapshot.phase, .preparing)

        await advance(0.5)
        await publishMoving(speed: 12, lat: 37.3301, lon: -122.0100)
        XCTAssertEqual(engine.snapshot.phase, .driving)
        XCTAssertNotNil(engine.snapshot.liveTrip)
        XCTAssertEqual(engine.snapshot.startReason, .sustainedSpeed)
    }

    func testWalkingSpeedDoesNotStartSession() async {
        await publishMoving(speed: 1.2, lat: 37.3300, lon: -122.0100)
        await advance(1)
        await publishMoving(speed: 1.3, lat: 37.3301, lon: -122.0100)
        XCTAssertEqual(engine.snapshot.phase, .idle)
        XCTAssertNil(engine.snapshot.liveTrip)
    }

    func testDistanceAccumulatesAndAverageMaxUpdate() async throws {
        await publishMoving(speed: 15, lat: 37.33000, lon: -122.0100)
        await advance(0.5)
        await publishMoving(speed: 18, lat: 37.33020, lon: -122.0100)
        XCTAssertEqual(engine.snapshot.phase, .driving)

        await advance(1)
        await publishMoving(speed: 22, lat: 37.33060, lon: -122.0100)
        await advance(1)
        await publishMoving(speed: 20, lat: 37.33100, lon: -122.0100)

        let trip = try XCTUnwrap(engine.snapshot.liveTrip)
        XCTAssertGreaterThan(trip.distanceMeters, 40)
        XCTAssertGreaterThanOrEqual(trip.maximumSpeedMetersPerSecond, 20)
        XCTAssertGreaterThan(trip.averageSpeedMetersPerSecond(), 0)
        XCTAssertLessThan(trip.averageSpeedMetersPerSecond(), 40)
    }

    func testSessionEndsAfterExtendedStopAndPersists() async throws {
        await publishMoving(speed: 16, lat: 37.33000, lon: -122.0100)
        await advance(0.5)
        await publishMoving(speed: 16, lat: 37.33040, lon: -122.0100)
        await advance(1)
        await publishMoving(speed: 16, lat: 37.33080, lon: -122.0100)
        await advance(1)
        await publishMoving(speed: 16, lat: 37.33120, lon: -122.0100)
        XCTAssertEqual(engine.snapshot.phase, .driving)

        let tripID = try XCTUnwrap(engine.snapshot.liveTrip?.id)

        await advance(0.5)
        await publishMoving(speed: 0.2, lat: 37.33120, lon: -122.0100)
        XCTAssertEqual(engine.snapshot.phase, .stopped)

        await advance(0.6)
        await publishMoving(speed: 0.1, lat: 37.33120, lon: -122.0100)
        XCTAssertEqual(engine.snapshot.phase, .idle)
        XCTAssertEqual(engine.snapshot.endReason, .extendedStop)
        XCTAssertEqual(engine.snapshot.lastCompletedTripID, tripID)

        let descriptor = FetchDescriptor<DriveRecord>(sortBy: [SortDescriptor(\.endedAt, order: .reverse)])
        let records = try context.fetch(descriptor)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].id, tripID)
        XCTAssertEqual(records[0].vehicleName, "Test Vehicle")
        XCTAssertGreaterThan(records[0].distanceMeters, 30)
        XCTAssertGreaterThan(records[0].maximumSpeedMetersPerSecond, 10)
        XCTAssertGreaterThan(records[0].averageSpeedMetersPerSecond, 0)
    }

    func testShortTripIsDiscarded() async throws {
        let shortConfig = DriveSessionConfiguration(
            startSpeedMetersPerSecond: 4.5,
            startHoldDuration: 0.2,
            startMinimumDistanceMeters: 500,
            stopSpeedMetersPerSecond: 0.9,
            stopHoldDuration: 0.2,
            minimumPersistDistanceMeters: 5_000,
            minimumPersistDuration: 600,
            maxJumpMeters: 120,
            maxSampleGapSeconds: 15,
            minSegmentMeters: 1.0,
            maxHorizontalAccuracyMeters: 45
        )
        engine = DrivingEngine(telemetry: telemetry, configuration: shortConfig)
        engine.attach(modelContext: context)
        engine.updateActiveVehicle(id: UUID(), name: "Short", speedUnit: .milesPerHour, distanceUnit: .miles)

        await publishMoving(speed: 12, lat: 37.33, lon: -122.01)
        await advance(0.3)
        await publishMoving(speed: 12, lat: 37.3301, lon: -122.01)
        XCTAssertEqual(engine.snapshot.phase, .driving)

        await advance(0.2)
        await publishMoving(speed: 0, lat: 37.3301, lon: -122.01)
        await advance(0.3)
        await publishMoving(speed: 0, lat: 37.3301, lon: -122.01)
        XCTAssertEqual(engine.snapshot.phase, .idle)
        XCTAssertEqual(engine.snapshot.endReason, .discardedTooShort)

        let records = try context.fetch(FetchDescriptor<DriveRecord>())
        XCTAssertTrue(records.isEmpty)
    }

    func testRejectedGPSSamplesIncrementCounter() async {
        let before = engine.snapshot.rejectedSampleCount
        await publish(speed: 12, lat: 37.33, lon: -122.01, accuracy: 200)
        XCTAssertGreaterThan(engine.snapshot.rejectedSampleCount, before)
        XCTAssertEqual(engine.snapshot.phase, .idle)
    }

    func testTripOrderingNewestFirst() throws {
        let older = DriveRecord(
            vehicleName: "A",
            startedAt: Date().addingTimeInterval(-3600),
            endedAt: Date().addingTimeInterval(-3500),
            distanceMeters: 1000,
            durationSeconds: 100,
            averageSpeedMetersPerSecond: 10,
            maximumSpeedMetersPerSecond: 20,
            speedUnit: .milesPerHour,
            distanceUnit: .miles,
            speedSource: .gps
        )
        let newer = DriveRecord(
            vehicleName: "B",
            startedAt: Date().addingTimeInterval(-600),
            endedAt: Date().addingTimeInterval(-500),
            distanceMeters: 2000,
            durationSeconds: 100,
            averageSpeedMetersPerSecond: 12,
            maximumSpeedMetersPerSecond: 25,
            speedUnit: .milesPerHour,
            distanceUnit: .miles,
            speedSource: .gps
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        let descriptor = FetchDescriptor<DriveRecord>(sortBy: [SortDescriptor(\.endedAt, order: .reverse)])
        let records = try context.fetch(descriptor)
        XCTAssertEqual(records.map(\.vehicleName), ["B", "A"])
    }

    func testSessionStartsViaSustainedDistance() async {
        let distanceConfig = DriveSessionConfiguration(
            startSpeedMetersPerSecond: 4.5,
            startHoldDuration: 60,
            startMinimumDistanceMeters: 25,
            stopSpeedMetersPerSecond: 0.9,
            stopHoldDuration: 180,
            minimumPersistDistanceMeters: 120,
            minimumPersistDuration: 45,
            maxJumpMeters: 120,
            maxSampleGapSeconds: 15,
            minSegmentMeters: 1.0,
            maxHorizontalAccuracyMeters: 45
        )
        engine = DrivingEngine(telemetry: telemetry, configuration: distanceConfig)
        engine.attach(modelContext: context)

        await publishMoving(speed: 10, lat: 37.33000, lon: -122.0100)
        XCTAssertEqual(engine.snapshot.phase, .preparing)
        await advance(1)
        await publishMoving(speed: 10, lat: 37.33030, lon: -122.0100)
        XCTAssertEqual(engine.snapshot.phase, .driving)
        XCTAssertEqual(engine.snapshot.startReason, .sustainedDistance)
    }

    // MARK: - Helpers

    /// Advances session time using wall-clock sleep so GPS age stays valid while hold timers elapse.
    private func advance(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(max(seconds, 0.05) * 1_000_000_000))
        clock = Date().addingTimeInterval(-0.1)
    }

    private func publishMoving(speed: Double, lat: Double, lon: Double) async {
        await publish(speed: speed, lat: lat, lon: lon, accuracy: 8)
    }

    private func publish(speed: Double, lat: Double, lon: Double, accuracy: Double) async {
        clock = Date().addingTimeInterval(-0.1)
        provider.publish(
            LocationSnapshot(
                latitude: lat,
                longitude: lon,
                altitudeMeters: 20,
                speedMetersPerSecond: speed,
                courseDegrees: 90,
                courseAccuracyDegrees: 5,
                headingDegrees: 90,
                headingAccuracyDegrees: 5,
                horizontalAccuracyMeters: accuracy,
                verticalAccuracyMeters: 8,
                timestamp: clock
            )
        )
        await settle()
    }

    private func settle() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 40_000_000)
    }
}
