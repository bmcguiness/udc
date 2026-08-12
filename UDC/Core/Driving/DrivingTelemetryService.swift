import Foundation
import Observation

/// Owns live GPS → `DrivingState` mapping. UI observes this; never Core Location.
@Observable
@MainActor
final class DrivingTelemetryService {
    private(set) var state: DrivingState = .idle
    private(set) var diagnostics: DrivingDiagnostics = .empty

    /// Downstream observers receive normalized state after each update (registration order).
    private var stateObservers: [(UUID, (DrivingState) -> Void)] = []

    private let locationProvider: any LocationProviding
    private var smoother = SpeedSmoother()
    private let filterConfiguration = GPSSpeedFilter.Configuration()
    private var gpsSampleCount = 0
    private var acceptedSampleCount = 0
    private var rejectedSampleCount = 0

    init(locationProvider: any LocationProviding) {
        self.locationProvider = locationProvider
        bindProvider()
        refreshAuthorizationSurface()
    }

    @discardableResult
    func addStateObserver(_ handler: @escaping (DrivingState) -> Void) -> UUID {
        let id = UUID()
        stateObservers.append((id, handler))
        return id
    }

    func removeStateObserver(_ id: UUID) {
        stateObservers.removeAll { $0.0 == id }
    }

    func start() {
        locationProvider.refreshAuthorizationStatus()
        refreshAuthorizationSurface()
        switch locationProvider.authorizationStatus {
        case .notDetermined:
            locationProvider.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationProvider.startUpdating()
        case .denied, .restricted:
            break
        }
    }

    func stop() {
        locationProvider.stopUpdating()
    }

    func requestPermission() {
        locationProvider.requestWhenInUseAuthorization()
    }

    func updateActiveVehicle(name: String?, speedUnit: SpeedUnit) {
        let unitChanged = state.preferredSpeedUnit != speedUnit
        state.activeVehicleName = name
        state.preferredSpeedUnit = speedUnit
        if unitChanged {
            // Re-express current smoothed speed in the new unit without resetting filter history.
            publishDisplayedSpeed()
        } else {
            // Keep name in sync for diagnostics even when unit unchanged.
            diagnostics.activeVehicleName = name
            diagnostics.preferredSpeedUnit = speedUnit
        }
        notifyStateObservers()
    }

    func updateSessionDiagnostics(
        phase: DriveSessionPhase,
        liveTrip: LiveTrip?,
        startReason: DriveSessionStartReason?,
        endReason: DriveSessionEndReason?,
        movementThresholdMetersPerSecond: Double,
        gpsSampleCount: Int,
        acceptedSampleCount: Int,
        rejectedSampleCount: Int
    ) {
        diagnostics.sessionPhase = phase
        diagnostics.tripID = liveTrip?.id
        diagnostics.sessionStartedAt = liveTrip?.startedAt
        diagnostics.sessionDistanceMeters = liveTrip?.distanceMeters
        diagnostics.sessionDurationSeconds = liveTrip.map { $0.duration() }
        diagnostics.sessionAverageSpeedMetersPerSecond = liveTrip.map { $0.averageSpeedMetersPerSecond() }
        diagnostics.sessionMaximumSpeedMetersPerSecond = liveTrip?.maximumSpeedMetersPerSecond
        diagnostics.sessionStartReason = startReason
        diagnostics.sessionEndReason = endReason
        diagnostics.movementThresholdMetersPerSecond = movementThresholdMetersPerSecond
        diagnostics.gpsSampleCount = gpsSampleCount
        diagnostics.acceptedSampleCount = acceptedSampleCount
        diagnostics.rejectedSampleCount = rejectedSampleCount
    }

    func updatePerformanceDiagnostics(
        phase: PerformancePhase,
        launchDetected: Bool,
        distanceMeters: Double?,
        elapsedSeconds: TimeInterval?,
        reached30: Bool,
        reached40: Bool,
        reached60: Bool,
        reachedEighth: Bool,
        reachedQuarter: Bool,
        gpsQualityReady: Bool,
        isCurrentRunValid: Bool,
        cancelReason: PerformanceCancelReason?
    ) {
        diagnostics.performancePhase = phase
        diagnostics.performanceLaunchDetected = launchDetected
        diagnostics.performanceDistanceMeters = distanceMeters
        diagnostics.performanceElapsedSeconds = elapsedSeconds
        diagnostics.performanceReached30 = reached30
        diagnostics.performanceReached40 = reached40
        diagnostics.performanceReached60 = reached60
        diagnostics.performanceReachedEighth = reachedEighth
        diagnostics.performanceReachedQuarter = reachedQuarter
        diagnostics.performanceGPSQualityReady = gpsQualityReady
        diagnostics.performanceRunValid = isCurrentRunValid
        diagnostics.performanceCancelReason = cancelReason
    }

    // MARK: - Private

    private func notifyStateObservers() {
        for (_, handler) in stateObservers {
            handler(state)
        }
    }

    private func bindProvider() {
        locationProvider.onAuthorizationChange = { [weak self] status in
            Task { @MainActor in
                self?.handleAuthorization(status)
            }
        }
        locationProvider.onSnapshot = { [weak self] snapshot in
            Task { @MainActor in
                self?.handleSnapshot(snapshot)
            }
        }
    }

    private func handleAuthorization(_ status: LocationAuthorizationStatus) {
        state.authorizationStatus = status
        state.isLocationServicesEnabled = locationProvider.isLocationServicesEnabled
        diagnostics.authorizationStatus = status
        diagnostics.isLocationServicesEnabled = locationProvider.isLocationServicesEnabled

        if status.allowsLocationUpdates {
            locationProvider.startUpdating()
            state.gpsStatus = .searching
        } else {
            locationProvider.stopUpdating()
            smoother.reset()
            state.rawSpeedMetersPerSecond = nil
            state.filteredSpeedMetersPerSecond = nil
            state.displayedSpeed = 0
            state.isMoving = false
            state.speedSource = .none
            state.gpsStatus = GPSStatusResolver.resolve(
                authorization: status,
                locationServicesEnabled: locationProvider.isLocationServicesEnabled,
                latestSnapshot: nil,
                filterResult: nil
            )
        }
        refreshDiagnosticsMetadata()
        notifyStateObservers()
    }

    private func handleSnapshot(_ snapshot: LocationSnapshot) {
        let now = Date.now
        gpsSampleCount += 1
        let filterResult = GPSSpeedFilter.evaluate(
            snapshot: snapshot,
            now: now,
            configuration: filterConfiguration
        )
        if filterResult.acceptedSpeedMetersPerSecond != nil {
            acceptedSampleCount += 1
        } else {
            rejectedSampleCount += 1
        }

        state.latitude = snapshot.latitude
        state.longitude = snapshot.longitude
        state.horizontalAccuracyMeters = snapshot.horizontalAccuracyMeters
        state.verticalAccuracyMeters = snapshot.verticalAccuracyMeters >= 0 ? snapshot.verticalAccuracyMeters : nil
        state.headingDegrees = snapshot.headingDegrees ?? snapshot.courseDegrees
        state.headingAccuracyDegrees = snapshot.headingAccuracyDegrees ?? snapshot.courseAccuracyDegrees
        state.courseDegrees = snapshot.courseDegrees
        state.timestamp = snapshot.timestamp
        state.locationAgeSeconds = now.timeIntervalSince(snapshot.timestamp)
        state.rawSpeedMetersPerSecond = snapshot.speedMetersPerSecond
        state.authorizationStatus = locationProvider.authorizationStatus
        state.isLocationServicesEnabled = locationProvider.isLocationServicesEnabled

        if let accepted = filterResult.acceptedSpeedMetersPerSecond {
            state.filteredSpeedMetersPerSecond = accepted
            state.isMoving = filterResult.isMoving
            let smoothed = smoother.push(filteredMetersPerSecond: accepted, isMoving: filterResult.isMoving)
            state.speedSource = .gps
            state.displayedSpeed = state.preferredSpeedUnit.value(fromMetersPerSecond: smoothed)
        } else {
            // Keep last smoothed value briefly while searching; zero if stale/poor.
            state.filteredSpeedMetersPerSecond = nil
            if filterResult.rejection == .stale || filterResult.rejection == .inaccurate {
                // Decay toward zero when samples are unusable.
                let smoothed = smoother.push(filteredMetersPerSecond: 0, isMoving: false)
                state.displayedSpeed = state.preferredSpeedUnit.value(fromMetersPerSecond: smoothed)
                state.isMoving = false
            }
        }

        state.gpsStatus = GPSStatusResolver.resolve(
            authorization: locationProvider.authorizationStatus,
            locationServicesEnabled: locationProvider.isLocationServicesEnabled,
            latestSnapshot: snapshot,
            filterResult: filterResult,
            now: now
        )

        updateDiagnostics(snapshot: snapshot, filterResult: filterResult, now: now)
        notifyStateObservers()
    }

    private func publishDisplayedSpeed() {
        let mps = smoother.hasSeed ? smoother.metersPerSecond : (state.filteredSpeedMetersPerSecond ?? 0)
        state.displayedSpeed = state.preferredSpeedUnit.value(fromMetersPerSecond: mps)
        diagnostics.displayedSpeed = state.displayedSpeed
        diagnostics.preferredSpeedUnit = state.preferredSpeedUnit
        diagnostics.activeVehicleName = state.activeVehicleName
    }

    private func refreshAuthorizationSurface() {
        state.authorizationStatus = locationProvider.authorizationStatus
        state.isLocationServicesEnabled = locationProvider.isLocationServicesEnabled
        state.gpsStatus = GPSStatusResolver.resolve(
            authorization: locationProvider.authorizationStatus,
            locationServicesEnabled: locationProvider.isLocationServicesEnabled,
            latestSnapshot: locationProvider.latestSnapshot,
            filterResult: nil
        )
        refreshDiagnosticsMetadata()
    }

    private func refreshDiagnosticsMetadata() {
        diagnostics.authorizationStatus = state.authorizationStatus
        diagnostics.isLocationServicesEnabled = state.isLocationServicesEnabled
        diagnostics.gpsStatus = state.gpsStatus
        diagnostics.preferredSpeedUnit = state.preferredSpeedUnit
        diagnostics.activeVehicleName = state.activeVehicleName
        diagnostics.speedSource = state.speedSource
    }

    private func updateDiagnostics(
        snapshot: LocationSnapshot,
        filterResult: GPSSpeedFilter.Result,
        now: Date
    ) {
        let previous = diagnostics
        diagnostics = DrivingDiagnostics(
            authorizationStatus: locationProvider.authorizationStatus,
            isLocationServicesEnabled: locationProvider.isLocationServicesEnabled,
            latitude: snapshot.latitude,
            longitude: snapshot.longitude,
            horizontalAccuracyMeters: snapshot.horizontalAccuracyMeters,
            verticalAccuracyMeters: snapshot.verticalAccuracyMeters,
            headingDegrees: snapshot.headingDegrees ?? snapshot.courseDegrees,
            headingAccuracyDegrees: snapshot.headingAccuracyDegrees ?? snapshot.courseAccuracyDegrees,
            rawSpeedMetersPerSecond: snapshot.speedMetersPerSecond,
            filteredSpeedMetersPerSecond: filterResult.acceptedSpeedMetersPerSecond,
            displayedSpeed: state.displayedSpeed,
            timestamp: snapshot.timestamp,
            locationAgeSeconds: now.timeIntervalSince(snapshot.timestamp),
            speedSource: state.speedSource,
            isMoving: state.isMoving,
            gpsStatus: state.gpsStatus,
            preferredSpeedUnit: state.preferredSpeedUnit,
            activeVehicleName: state.activeVehicleName,
            filterRejection: filterResult.rejection.map(String.init(describing:)),
            sessionPhase: previous.sessionPhase,
            tripID: previous.tripID,
            sessionStartedAt: previous.sessionStartedAt,
            sessionDistanceMeters: previous.sessionDistanceMeters,
            sessionDurationSeconds: previous.sessionDurationSeconds,
            sessionAverageSpeedMetersPerSecond: previous.sessionAverageSpeedMetersPerSecond,
            sessionMaximumSpeedMetersPerSecond: previous.sessionMaximumSpeedMetersPerSecond,
            sessionStartReason: previous.sessionStartReason,
            sessionEndReason: previous.sessionEndReason,
            movementThresholdMetersPerSecond: previous.movementThresholdMetersPerSecond,
            gpsSampleCount: gpsSampleCount,
            acceptedSampleCount: acceptedSampleCount,
            rejectedSampleCount: rejectedSampleCount,
            performancePhase: previous.performancePhase,
            performanceLaunchDetected: previous.performanceLaunchDetected,
            performanceDistanceMeters: previous.performanceDistanceMeters,
            performanceElapsedSeconds: previous.performanceElapsedSeconds,
            performanceReached30: previous.performanceReached30,
            performanceReached40: previous.performanceReached40,
            performanceReached60: previous.performanceReached60,
            performanceReachedEighth: previous.performanceReachedEighth,
            performanceReachedQuarter: previous.performanceReachedQuarter,
            performanceGPSQualityReady: previous.performanceGPSQualityReady,
            performanceRunValid: previous.performanceRunValid,
            performanceCancelReason: previous.performanceCancelReason
        )
    }
}

struct DrivingDiagnostics: Equatable, Sendable {
    var authorizationStatus: LocationAuthorizationStatus = .notDetermined
    var isLocationServicesEnabled: Bool = true
    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracyMeters: Double?
    var verticalAccuracyMeters: Double?
    var headingDegrees: Double?
    var headingAccuracyDegrees: Double?
    var rawSpeedMetersPerSecond: Double?
    var filteredSpeedMetersPerSecond: Double?
    var displayedSpeed: Double = 0
    var timestamp: Date?
    var locationAgeSeconds: TimeInterval?
    var speedSource: SpeedSource = .none
    var isMoving: Bool = false
    var gpsStatus: GPSStatus = .permissionNeeded
    var preferredSpeedUnit: SpeedUnit = .milesPerHour
    var activeVehicleName: String?
    var filterRejection: String?

    // Session / trip diagnostics
    var sessionPhase: DriveSessionPhase = .idle
    var tripID: UUID?
    var sessionStartedAt: Date?
    var sessionDistanceMeters: Double?
    var sessionDurationSeconds: TimeInterval?
    var sessionAverageSpeedMetersPerSecond: Double?
    var sessionMaximumSpeedMetersPerSecond: Double?
    var sessionStartReason: DriveSessionStartReason?
    var sessionEndReason: DriveSessionEndReason?
    var movementThresholdMetersPerSecond: Double = DriveSessionConfiguration().startSpeedMetersPerSecond
    var gpsSampleCount: Int = 0
    var acceptedSampleCount: Int = 0
    var rejectedSampleCount: Int = 0

    // Performance diagnostics
    var performancePhase: PerformancePhase = .idle
    var performanceLaunchDetected: Bool = false
    var performanceDistanceMeters: Double?
    var performanceElapsedSeconds: TimeInterval?
    var performanceReached30: Bool = false
    var performanceReached40: Bool = false
    var performanceReached60: Bool = false
    var performanceReachedEighth: Bool = false
    var performanceReachedQuarter: Bool = false
    var performanceGPSQualityReady: Bool = false
    var performanceRunValid: Bool = true
    var performanceCancelReason: PerformanceCancelReason?

    static let empty = DrivingDiagnostics()
}
