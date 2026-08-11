import Foundation
import Observation

/// Owns live GPS → `DrivingState` mapping. UI observes this; never Core Location.
@Observable
@MainActor
final class DrivingTelemetryService {
    private(set) var state: DrivingState = .idle
    private(set) var diagnostics: DrivingDiagnostics = .empty

    private let locationProvider: any LocationProviding
    private var smoother = SpeedSmoother()
    private let filterConfiguration = GPSSpeedFilter.Configuration()

    init(locationProvider: any LocationProviding) {
        self.locationProvider = locationProvider
        bindProvider()
        refreshAuthorizationSurface()
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
    }

    // MARK: - Private

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
    }

    private func handleSnapshot(_ snapshot: LocationSnapshot) {
        let now = Date.now
        let filterResult = GPSSpeedFilter.evaluate(
            snapshot: snapshot,
            now: now,
            configuration: filterConfiguration
        )

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
            filterRejection: filterResult.rejection.map(String.init(describing:))
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

    static let empty = DrivingDiagnostics()
}
