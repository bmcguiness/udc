import Foundation

/// Pure GPS sample filtering — rejects invalid, stale, and inaccurate fixes.
enum GPSSpeedFilter {
    struct Configuration: Equatable, Sendable {
        /// Reject fixes looser than this horizontal accuracy.
        var maxHorizontalAccuracyMeters: Double = 65
        /// Reject samples older than this.
        var maxSampleAgeSeconds: TimeInterval = 5
        /// Below this ground speed, treat as stopped to reduce jitter.
        var stopThresholdMetersPerSecond: Double = 0.45
    }

    enum RejectionReason: Equatable, Sendable {
        case invalidAccuracy
        case inaccurate
        case stale
        case missingSpeed
        case invalidSpeed
    }

    struct Result: Equatable, Sendable {
        var acceptedSpeedMetersPerSecond: Double?
        var isMoving: Bool
        var rejection: RejectionReason?
    }

    static func evaluate(
        snapshot: LocationSnapshot,
        now: Date = .now,
        configuration: Configuration = .init()
    ) -> Result {
        guard snapshot.horizontalAccuracyMeters >= 0 else {
            return Result(acceptedSpeedMetersPerSecond: nil, isMoving: false, rejection: .invalidAccuracy)
        }
        guard snapshot.horizontalAccuracyMeters <= configuration.maxHorizontalAccuracyMeters else {
            return Result(acceptedSpeedMetersPerSecond: nil, isMoving: false, rejection: .inaccurate)
        }

        let age = now.timeIntervalSince(snapshot.timestamp)
        guard age >= 0, age <= configuration.maxSampleAgeSeconds else {
            return Result(acceptedSpeedMetersPerSecond: nil, isMoving: false, rejection: .stale)
        }

        guard let speed = snapshot.speedMetersPerSecond else {
            return Result(acceptedSpeedMetersPerSecond: nil, isMoving: false, rejection: .missingSpeed)
        }
        guard speed.isFinite, speed >= 0 else {
            return Result(acceptedSpeedMetersPerSecond: nil, isMoving: false, rejection: .invalidSpeed)
        }

        if speed < configuration.stopThresholdMetersPerSecond {
            return Result(acceptedSpeedMetersPerSecond: 0, isMoving: false, rejection: nil)
        }

        return Result(acceptedSpeedMetersPerSecond: speed, isMoving: true, rejection: nil)
    }
}

/// Light exponential smoothing for stable dashboard readout without heavy lag.
struct SpeedSmoother: Equatable, Sendable {
    private(set) var metersPerSecond: Double = 0
    var hasSeed: Bool = false

    /// Blend factor toward the newest sample (higher = more responsive).
    var alphaMoving: Double = 0.38
    /// Snap toward zero more aggressively when stopped.
    var alphaStopped: Double = 0.72

    init(alphaMoving: Double = 0.38, alphaStopped: Double = 0.72) {
        self.alphaMoving = alphaMoving
        self.alphaStopped = alphaStopped
    }

    mutating func reset() {
        metersPerSecond = 0
        hasSeed = false
    }

    mutating func push(filteredMetersPerSecond: Double, isMoving: Bool) -> Double {
        guard hasSeed else {
            metersPerSecond = filteredMetersPerSecond
            hasSeed = true
            return metersPerSecond
        }

        let alpha = isMoving ? alphaMoving : alphaStopped
        metersPerSecond += alpha * (filteredMetersPerSecond - metersPerSecond)

        if !isMoving, metersPerSecond < 0.15 {
            metersPerSecond = 0
        }

        return metersPerSecond
    }
}

enum GPSStatusResolver {
    static func resolve(
        authorization: LocationAuthorizationStatus,
        locationServicesEnabled: Bool,
        latestSnapshot: LocationSnapshot?,
        filterResult: GPSSpeedFilter.Result?,
        now: Date = .now
    ) -> GPSStatus {
        guard locationServicesEnabled else { return .locationDisabled }

        switch authorization {
        case .notDetermined:
            return .permissionNeeded
        case .denied, .restricted:
            return .permissionNeeded
        case .authorizedWhenInUse, .authorizedAlways:
            break
        }

        guard let snapshot = latestSnapshot else {
            return .searching
        }

        let age = now.timeIntervalSince(snapshot.timestamp)
        if age > GPSSpeedFilter.Configuration().maxSampleAgeSeconds {
            return .searching
        }

        if snapshot.horizontalAccuracyMeters < 0 {
            return .unavailable
        }

        if snapshot.horizontalAccuracyMeters > 45 {
            return .poorSignal
        }

        if let rejection = filterResult?.rejection {
            switch rejection {
            case .inaccurate, .invalidAccuracy:
                return .poorSignal
            case .stale, .missingSpeed:
                return .searching
            case .invalidSpeed:
                return .unavailable
            }
        }

        return .ready
    }
}
