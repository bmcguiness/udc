import SwiftData
import SwiftUI
import XCTest
@testable import UDC

final class DriveLifecyclePolicyTests: XCTestCase {
    func testIdleTimerDisabledOnlyWhileActive() {
        XCTAssertTrue(IdleTimerPolicy.shouldDisableIdleTimer(scenePhase: .active))
        XCTAssertFalse(IdleTimerPolicy.shouldDisableIdleTimer(scenePhase: .inactive))
        XCTAssertFalse(IdleTimerPolicy.shouldDisableIdleTimer(scenePhase: .background))
    }

    func testBackgroundLocationOnlyWhileRecording() {
        XCTAssertFalse(BackgroundLocationPolicy.shouldEnableBackgroundUpdates(phase: .idle))
        XCTAssertFalse(BackgroundLocationPolicy.shouldEnableBackgroundUpdates(phase: .preparing))
        XCTAssertTrue(BackgroundLocationPolicy.shouldEnableBackgroundUpdates(phase: .driving))
        XCTAssertTrue(BackgroundLocationPolicy.shouldEnableBackgroundUpdates(phase: .stopped))
    }
}

@MainActor
final class DriveDurabilityTests: XCTestCase {
    private var provider: NoOpLocationProvider!
    private var telemetry: DrivingTelemetryService!
    private var engine: DrivingEngine!
    private var container: ModelContainer!
    private var context: ModelContext!
    private var vehicleID: UUID!

    private let driveConfig = DriveSessionConfiguration(
        startSpeedMetersPerSecond: 4.5,
        startHoldDuration: 0.25,
        startMinimumDistanceMeters: 500,
        stopSpeedMetersPerSecond: 0.9,
        stopHoldDuration: 0.35,
        minimumPersistDistanceMeters: 20,
        minimumPersistDuration: 0.2,
        maxJumpMeters: 200,
        maxSampleGapSeconds: 15,
        minSegmentMeters: 1.0,
        maxHorizontalAccuracyMeters: 45
    )

    private let durability = DriveDurabilityConfiguration(
        checkpointMinimumInterval: 0.2,
        checkpointMinimumDistanceMeters: 25,
        resumeIfUpdatedWithin: 60 * 60
    )

    override func setUp() async throws {
        provider = NoOpLocationProvider()
        provider.setAuthorization(.authorizedWhenInUse)
        telemetry = DrivingTelemetryService(locationProvider: provider)
        engine = DrivingEngine(
            telemetry: telemetry,
            configuration: driveConfig,
            durability: durability
        )
        container = try ModelContainer(
            for: DriveRecord.self, VehicleProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        vehicleID = UUID()
        context.insert(VehicleProfile(id: vehicleID, name: "Road Car", isActive: true))
        try context.save()

        engine.attach(modelContext: context)
        engine.updateActiveVehicle(
            id: vehicleID,
            name: "Road Car",
            speedUnit: .milesPerHour,
            distanceUnit: .miles
        )
        telemetry.start()
        await settle()
    }

    override func tearDown() async throws {
        engine = nil
        telemetry = nil
        provider = nil
        context = nil
        container = nil
    }

    func testActiveDriveCreatesDurableInProgressRecord() async throws {
        await enterDrive()
        let tripID = try XCTUnwrap(engine.snapshot.liveTrip?.id)
        let records = try context.fetch(FetchDescriptor<DriveRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].id, tripID)
        XCTAssertTrue(records[0].isInProgress)
        XCTAssertFalse(records[0].isFinalized)
        XCTAssertEqual(records[0].vehicleID, vehicleID)
        XCTAssertTrue(engine.snapshot.activeRecordPersisted)
    }

    func testCheckpointUpdatesSameRecordNotDuplicate() async throws {
        await enterDrive()
        let tripID = try XCTUnwrap(engine.snapshot.liveTrip?.id)
        await advance(0.25)
        await publish(speed: 16, lat: 37.33040, lon: -122.0100)
        await advance(0.25)
        await publish(speed: 16, lat: 37.33080, lon: -122.0100)

        let records = try context.fetch(FetchDescriptor<DriveRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].id, tripID)
        XCTAssertTrue(records[0].isInProgress)
        XCTAssertGreaterThan(records[0].distanceMeters, 0)
    }

    func testActiveDriveFinalizesCorrectly() async throws {
        await enterDrive()
        let tripID = try XCTUnwrap(engine.snapshot.liveTrip?.id)
        await advance(0.3)
        await publish(speed: 16, lat: 37.33050, lon: -122.0100)
        await advance(0.3)
        await publish(speed: 16, lat: 37.33100, lon: -122.0100)

        await advance(0.2)
        await publish(speed: 0.2, lat: 37.33100, lon: -122.0100)
        await advance(0.4)
        await publish(speed: 0.1, lat: 37.33100, lon: -122.0100)

        XCTAssertEqual(engine.snapshot.phase, .idle)
        let records = try context.fetch(FetchDescriptor<DriveRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].id, tripID)
        XCTAssertFalse(records[0].isInProgress)
        XCTAssertTrue(records[0].isFinalized)
        XCTAssertEqual(engine.snapshot.lastCompletedTripID, tripID)
    }

    func testRecoveredDrivePreservesIdentityDistanceMaxAndVehicle() async throws {
        await enterDrive()
        let tripID = try XCTUnwrap(engine.snapshot.liveTrip?.id)
        await advance(0.4)
        await publish(speed: 20, lat: 37.33060, lon: -122.0100)
        await advance(0.4)
        await publish(speed: 22, lat: 37.33120, lon: -122.0100)

        let before = try XCTUnwrap(try context.fetch(FetchDescriptor<DriveRecord>()).first)
        let distance = before.distanceMeters
        let maxSpeed = before.maximumSpeedMetersPerSecond
        XCTAssertGreaterThan(distance, 0)

        // Simulate relaunch with a fresh engine attached to the same store.
        let freshTelemetry = DrivingTelemetryService(locationProvider: provider)
        let freshEngine = DrivingEngine(
            telemetry: freshTelemetry,
            configuration: driveConfig,
            durability: durability
        )
        freshEngine.updateActiveVehicle(
            id: vehicleID,
            name: "Road Car",
            speedUnit: .milesPerHour,
            distanceUnit: .miles
        )
        freshEngine.attach(modelContext: context)
        await settle()

        XCTAssertEqual(freshEngine.snapshot.phase.isActivelyRecording, true)
        XCTAssertEqual(freshEngine.snapshot.liveTrip?.id, tripID)
        XCTAssertEqual(freshEngine.snapshot.liveTrip?.vehicleID, vehicleID)
        XCTAssertEqual(freshEngine.snapshot.liveTrip?.distanceMeters ?? 0, distance, accuracy: 0.01)
        XCTAssertEqual(freshEngine.snapshot.liveTrip?.maximumSpeedMetersPerSecond ?? 0, maxSpeed, accuracy: 0.01)
        XCTAssertTrue(freshEngine.snapshot.recoveredSession)
        XCTAssertEqual(freshEngine.snapshot.recoveryReason, .resumedRecent)

        let records = try context.fetch(FetchDescriptor<DriveRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].id, tripID)
        XCTAssertTrue(records[0].isInProgress)
    }

    func testStaleActiveDriveFinalizesRatherThanResuming() async throws {
        let staleDurability = DriveDurabilityConfiguration(
            checkpointMinimumInterval: 0.2,
            checkpointMinimumDistanceMeters: 25,
            resumeIfUpdatedWithin: 1
        )
        await enterDrive()
        let tripID = try XCTUnwrap(engine.snapshot.liveTrip?.id)
        await advance(0.5)
        await publish(speed: 18, lat: 37.33040, lon: -122.0100)
        await advance(0.5)
        await publish(speed: 18, lat: 37.33090, lon: -122.0100)
        await advance(0.5)
        await publish(speed: 18, lat: 37.33140, lon: -122.0100)

        // Make the checkpoint old, while keeping end >= start for a valid duration.
        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<DriveRecord>()).first)
        XCTAssertGreaterThanOrEqual(record.distanceMeters, driveConfig.minimumPersistDistanceMeters)
        record.startedAt = Date().addingTimeInterval(-180)
        record.lastCheckpointAt = Date().addingTimeInterval(-120)
        record.lastValidLocationAt = Date().addingTimeInterval(-120)
        try context.save()

        let freshTelemetry = DrivingTelemetryService(locationProvider: provider)
        let freshEngine = DrivingEngine(
            telemetry: freshTelemetry,
            configuration: driveConfig,
            durability: staleDurability
        )
        freshEngine.attach(modelContext: context)
        await settle()

        XCTAssertEqual(freshEngine.snapshot.phase, .idle)
        let records = try context.fetch(FetchDescriptor<DriveRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].id, tripID)
        XCTAssertFalse(records[0].isInProgress)
        XCTAssertEqual(freshEngine.snapshot.recoveryReason, .finalizedStale)
    }

    func testCompletedDriveAppearsInHistoryQuery() async throws {
        await enterDrive()
        await advance(0.4)
        await publish(speed: 16, lat: 37.33080, lon: -122.0100)
        await advance(0.2)
        await publish(speed: 0.2, lat: 37.33080, lon: -122.0100)
        await advance(0.4)
        await publish(speed: 0.1, lat: 37.33080, lon: -122.0100)

        let history = try context.fetch(
            FetchDescriptor<DriveRecord>(
                predicate: #Predicate { $0.isInProgress == false },
                sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
            )
        )
        XCTAssertEqual(history.count, 1)
        XCTAssertTrue(history[0].isFinalized)
    }

    func testBackgroundCheckpointForceWrites() async throws {
        await enterDrive()
        let tripID = try XCTUnwrap(engine.snapshot.liveTrip?.id)
        await advance(0.3)
        await publish(speed: 15, lat: 37.33040, lon: -122.0100)

        engine.handleScenePhase(.background)
        XCTAssertTrue(provider.isBackgroundLocationUpdatesEnabled)

        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<DriveRecord>()).first)
        XCTAssertEqual(record.id, tripID)
        XCTAssertEqual(record.checkpointReasonRaw, DriveCheckpointReason.enteredBackground.rawValue)

        engine.handleScenePhase(.active)
    }

    func testPerformanceAttachmentNotDuplicatedOnFlush() async throws {
        await enterDrive()
        let tripID = try XCTUnwrap(engine.snapshot.liveTrip?.id)
        let run = PerformanceRunSummary(
            id: UUID(),
            driveRecordID: tripID,
            vehicleID: vehicleID,
            vehicleName: "Road Car",
            launchedAt: .now,
            completedAt: .now,
            isValid: true,
            cancelReason: nil,
            completionReason: .significantSlowdown,
            zeroTo30Seconds: 2,
            zeroTo40Seconds: 3,
            zeroTo60Seconds: 5,
            eighthMileSeconds: nil,
            quarterMileSeconds: nil,
            eighthMileTopSpeedMetersPerSecond: nil,
            quarterMileTopSpeedMetersPerSecond: nil,
            peakSpeedMetersPerSecond: 30,
            distanceMeters: 80,
            durationSeconds: 6,
            speedUnitRaw: "mph",
            distanceUnitRaw: "mi"
        )

        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<DriveRecord>()).first)
        record.performanceSummaryJSON = PerformanceAttachment.encode([run])
        try context.save()

        // Re-encode same run through attachment helper path used by PerformanceEngine.
        var existing = PerformanceAttachment.decode(from: record.performanceSummaryJSON)
        let existingIDs = Set(existing.map(\.id))
        let fresh = [run].filter { !existingIDs.contains($0.id) }
        existing.append(contentsOf: fresh)
        record.performanceSummaryJSON = PerformanceAttachment.encode(existing)
        try context.save()

        XCTAssertEqual(record.performanceRuns.count, 1)
    }

    // MARK: - Helpers

    private func enterDrive() async {
        await publish(speed: 12, lat: 37.3290, lon: -122.0100)
        await advance(0.3)
        await publish(speed: 12, lat: 37.3292, lon: -122.0100)
        XCTAssertEqual(engine.snapshot.phase, .driving)
    }

    private func advance(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(max(seconds, 0.05) * 1_000_000_000))
    }

    private func publish(speed: Double, lat: Double, lon: Double, accuracy: Double = 8) async {
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
                timestamp: Date().addingTimeInterval(-0.1)
            )
        )
        await settle()
    }

    private func settle() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 40_000_000)
    }
}
