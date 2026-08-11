import CoreLocation
import Foundation

/// Normalized authorization for UI and telemetry (never expose `CLAuthorizationStatus` to views).
enum LocationAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case restricted
    case authorizedWhenInUse
    case authorizedAlways

    var allowsLocationUpdates: Bool {
        switch self {
        case .authorizedWhenInUse, .authorizedAlways: true
        case .notDetermined, .denied, .restricted: false
        }
    }

    var displayName: String {
        switch self {
        case .notDetermined: "Not Determined"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .authorizedWhenInUse: "When In Use"
        case .authorizedAlways: "Always"
        }
    }
}

/// Location sample consumed by driving telemetry — no `CLLocation` leakage to UI.
struct LocationSnapshot: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var altitudeMeters: Double?
    var speedMetersPerSecond: Double?
    var courseDegrees: Double?
    var courseAccuracyDegrees: Double?
    var headingDegrees: Double?
    var headingAccuracyDegrees: Double?
    var horizontalAccuracyMeters: Double
    var verticalAccuracyMeters: Double
    var timestamp: Date
}

protocol LocationProviding: AnyObject {
    var authorizationStatus: LocationAuthorizationStatus { get }
    var isLocationServicesEnabled: Bool { get }
    var latestSnapshot: LocationSnapshot? { get }

    var onAuthorizationChange: ((LocationAuthorizationStatus) -> Void)? { get set }
    var onSnapshot: ((LocationSnapshot) -> Void)? { get set }

    func requestWhenInUseAuthorization()
    func startUpdating()
    func stopUpdating()
    /// Refresh cached authorization from the system (e.g. after TCC changes).
    func refreshAuthorizationStatus()
}

final class NoOpLocationProvider: LocationProviding {
    private(set) var authorizationStatus: LocationAuthorizationStatus = .notDetermined
    var isLocationServicesEnabled: Bool = true
    private(set) var latestSnapshot: LocationSnapshot?

    var onAuthorizationChange: ((LocationAuthorizationStatus) -> Void)?
    var onSnapshot: ((LocationSnapshot) -> Void)?

    func requestWhenInUseAuthorization() {
        authorizationStatus = .authorizedWhenInUse
        onAuthorizationChange?(authorizationStatus)
    }

    func startUpdating() {}
    func stopUpdating() {}

    func refreshAuthorizationStatus() {
        onAuthorizationChange?(authorizationStatus)
    }

    /// Test helper to inject a sample.
    func publish(_ snapshot: LocationSnapshot) {
        latestSnapshot = snapshot
        onSnapshot?(snapshot)
    }

    func setAuthorization(_ status: LocationAuthorizationStatus) {
        authorizationStatus = status
        onAuthorizationChange?(status)
    }
}

// MARK: - Core Location

final class CoreLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager: CLLocationManager

    private(set) var authorizationStatus: LocationAuthorizationStatus
    private(set) var latestSnapshot: LocationSnapshot?

    var onAuthorizationChange: ((LocationAuthorizationStatus) -> Void)?
    var onSnapshot: ((LocationSnapshot) -> Void)?

    private var latestHeading: CLHeading?
    private var cachedLocationServicesEnabled: Bool = true

    var isLocationServicesEnabled: Bool {
        cachedLocationServicesEnabled
    }

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = Self.map(managerAuthorization: manager.authorizationStatus)
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        refreshLocationServicesEnabledCache()
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        refreshAuthorizationStatus()
        guard authorizationStatus.allowsLocationUpdates else { return }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func refreshAuthorizationStatus() {
        refreshLocationServicesEnabledCache()
        let status = Self.map(managerAuthorization: manager.authorizationStatus)
        let changed = status != authorizationStatus
        authorizationStatus = status
        if changed {
            onAuthorizationChange?(status)
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = Self.map(managerAuthorization: manager.authorizationStatus)
        authorizationStatus = status
        onAuthorizationChange?(status)
        if status.allowsLocationUpdates {
            startUpdating()
        } else {
            stopUpdating()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let snapshot = makeSnapshot(from: location, heading: latestHeading)
        latestSnapshot = snapshot
        onSnapshot?(snapshot)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        latestHeading = newHeading
        guard let location = manager.location else { return }
        let snapshot = makeSnapshot(from: location, heading: newHeading)
        latestSnapshot = snapshot
        onSnapshot?(snapshot)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        _ = error
    }

    private func makeSnapshot(from location: CLLocation, heading: CLHeading?) -> LocationSnapshot {
        let speed: Double? = location.speed >= 0 ? location.speed : nil
        let course: Double? = location.course >= 0 ? location.course : nil
        let courseAccuracy: Double? = location.courseAccuracy >= 0 ? location.courseAccuracy : nil

        var headingDegrees: Double?
        var headingAccuracy: Double?
        if let heading, heading.headingAccuracy >= 0 {
            headingDegrees = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
            headingAccuracy = heading.headingAccuracy
        }

        return LocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil,
            speedMetersPerSecond: speed,
            courseDegrees: course,
            courseAccuracyDegrees: courseAccuracy,
            headingDegrees: headingDegrees,
            headingAccuracyDegrees: headingAccuracy,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            verticalAccuracyMeters: location.verticalAccuracy,
            timestamp: location.timestamp
        )
    }

    private static func map(managerAuthorization status: CLAuthorizationStatus) -> LocationAuthorizationStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        case .authorizedWhenInUse: .authorizedWhenInUse
        case .authorizedAlways: .authorizedAlways
        @unknown default: .denied
        }
    }

    private func refreshLocationServicesEnabledCache() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let enabled = CLLocationManager.locationServicesEnabled()
            DispatchQueue.main.async {
                self?.cachedLocationServicesEnabled = enabled
            }
        }
    }
}
