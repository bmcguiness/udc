import Foundation

/// Explicit Performance Mode lifecycle.
enum PerformancePhase: Equatable, Sendable {
    case idle
    case armed
    case running
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .idle: "Idle"
        case .armed: "Armed"
        case .running: "Running"
        case .completed: "Completed"
        case .cancelled: "Cancelled"
        }
    }

    var isActivelyTiming: Bool {
        self == .running
    }
}

enum PerformanceCancelReason: String, Equatable, Sendable, Codable {
    case poorGPS = "Poor GPS"
    case invalidLaunch = "Invalid launch"
    case discarded = "Discarded"
}

enum PerformanceCompletionReason: String, Equatable, Sendable, Codable {
    case quarterMile = "1/4 mile reached"
    case significantSlowdown = "Significant slowdown"
    case sessionEnded = "Drive session ended"
}

/// Tunable launch / milestone thresholds. Internal for now.
struct PerformanceConfiguration: Equatable, Sendable {
    /// Essentially stopped before a launch (~1.5 mph).
    var stopSpeedMetersPerSecond: Double = 0.7
    /// Must remain stopped this long before a launch is eligible.
    var stopHoldDuration: TimeInterval = 1.2
    /// Crossing this speed after a valid stop starts the run (~5.5 mph).
    var launchTriggerSpeedMetersPerSecond: Double = 2.5
    /// Rolling-start rejection: never launch if speed was already above this without a fresh stop.
    var rollingRejectSpeedMetersPerSecond: Double = 2.2
    /// After launch, require this acceleration (m/s²) between samples to confirm a clean pull.
    var minLaunchAcceleration: Double = 1.2
    /// Complete when filtered speed stays below this after having moved (~4.5 mph).
    var slowdownSpeedMetersPerSecond: Double = 2.0
    var slowdownHoldDuration: TimeInterval = 2.5
    /// Minimum progress before a slowdown/session-end completion is kept.
    var minimumSaveSpeedMetersPerSecond: Double = 8.0 // ~18 mph
    var cooldownDuration: TimeInterval = 2.0

    /// Industry-standard targets in SI (always 30/40/60 mph and statute 1/8 & 1/4 mile).
    var thirtyMPHMetersPerSecond: Double = 13.4112
    var fortyMPHMetersPerSecond: Double = 17.8816
    var sixtyMPHMetersPerSecond: Double = 26.8224
    var eighthMileMeters: Double = 201.168
    var quarterMileMeters: Double = 402.336
}

/// One completed (or cancelled) performance measurement.
struct PerformanceRunSummary: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var driveRecordID: UUID?
    var vehicleID: UUID?
    var vehicleName: String
    var launchedAt: Date
    var completedAt: Date?
    var isValid: Bool
    var cancelReason: PerformanceCancelReason?
    var completionReason: PerformanceCompletionReason?

    var zeroTo30Seconds: Double?
    var zeroTo40Seconds: Double?
    var zeroTo60Seconds: Double?
    var eighthMileSeconds: Double?
    var quarterMileSeconds: Double?

    var eighthMileTopSpeedMetersPerSecond: Double?
    var quarterMileTopSpeedMetersPerSecond: Double?
    var peakSpeedMetersPerSecond: Double

    var distanceMeters: Double
    var durationSeconds: Double
    var speedUnitRaw: String
    var distanceUnitRaw: String

    var speedUnit: SpeedUnit {
        SpeedUnit(rawValue: speedUnitRaw) ?? .milesPerHour
    }

    var distanceUnit: DistanceUnit {
        DistanceUnit(rawValue: distanceUnitRaw) ?? .miles
    }

    var displayPeakSpeed: Double {
        speedUnit.value(fromMetersPerSecond: peakSpeedMetersPerSecond)
    }

    var displayEighthTopSpeed: Double? {
        eighthMileTopSpeedMetersPerSecond.map { speedUnit.value(fromMetersPerSecond: $0) }
    }

    var displayQuarterTopSpeed: Double? {
        quarterMileTopSpeedMetersPerSecond.map { speedUnit.value(fromMetersPerSecond: $0) }
    }
}

/// Best-known times / trap speeds for a vehicle. Lower times win; higher trap speeds win.
struct PerformanceBests: Codable, Equatable, Sendable {
    var zeroTo30Seconds: Double?
    var zeroTo40Seconds: Double?
    var zeroTo60Seconds: Double?
    var eighthMileSeconds: Double?
    var quarterMileSeconds: Double?
    var eighthMileTopSpeedMetersPerSecond: Double?
    var quarterMileTopSpeedMetersPerSecond: Double?
    var updatedAt: Date?

    static let empty = PerformanceBests()

    /// Returns updated bests and whether anything improved.
    func merging(run: PerformanceRunSummary) -> (PerformanceBests, Bool) {
        guard run.isValid else { return (self, false) }
        var next = self
        var improved = false

        func takeFaster(_ slot: inout Double?, _ candidate: Double?) {
            guard let candidate else { return }
            if let existing = slot {
                if candidate < existing {
                    slot = candidate
                    improved = true
                }
            } else {
                slot = candidate
                improved = true
            }
        }

        func takeHigherSpeed(_ slot: inout Double?, _ candidate: Double?) {
            guard let candidate else { return }
            if let existing = slot {
                if candidate > existing {
                    slot = candidate
                    improved = true
                }
            } else {
                slot = candidate
                improved = true
            }
        }

        takeFaster(&next.zeroTo30Seconds, run.zeroTo30Seconds)
        takeFaster(&next.zeroTo40Seconds, run.zeroTo40Seconds)
        takeFaster(&next.zeroTo60Seconds, run.zeroTo60Seconds)
        takeFaster(&next.eighthMileSeconds, run.eighthMileSeconds)
        takeFaster(&next.quarterMileSeconds, run.quarterMileSeconds)
        takeHigherSpeed(&next.eighthMileTopSpeedMetersPerSecond, run.eighthMileTopSpeedMetersPerSecond)
        takeHigherSpeed(&next.quarterMileTopSpeedMetersPerSecond, run.quarterMileTopSpeedMetersPerSecond)

        if improved {
            next.updatedAt = run.completedAt ?? .now
        }
        return (next, improved)
    }
}

struct PerformanceAttachment: Codable, Equatable, Sendable {
    var schemaVersion: Int = 1
    var runs: [PerformanceRunSummary]

    static func encode(_ runs: [PerformanceRunSummary]) -> String? {
        guard let data = try? JSONEncoder().encode(PerformanceAttachment(runs: runs)),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    static func decode(from json: String?) -> [PerformanceRunSummary] {
        guard let json, let data = json.data(using: .utf8),
              let attachment = try? JSONDecoder().decode(PerformanceAttachment.self, from: data) else {
            return []
        }
        return attachment.runs
    }
}

/// Live timing surface for UI / diagnostics.
struct LivePerformanceRun: Equatable, Sendable {
    var id: UUID
    var launchedAt: Date
    var driveTripID: UUID?
    var distanceMeters: Double = 0
    var elapsedSeconds: TimeInterval = 0
    var currentSpeedMetersPerSecond: Double = 0
    var peakSpeedMetersPerSecond: Double = 0

    var zeroTo30Seconds: Double?
    var zeroTo40Seconds: Double?
    var zeroTo60Seconds: Double?
    var eighthMileSeconds: Double?
    var quarterMileSeconds: Double?

    var eighthMileTopSpeedMetersPerSecond: Double?
    var quarterMileTopSpeedMetersPerSecond: Double?

    var reached30: Bool { zeroTo30Seconds != nil }
    var reached40: Bool { zeroTo40Seconds != nil }
    var reached60: Bool { zeroTo60Seconds != nil }
    var reachedEighth: Bool { eighthMileSeconds != nil }
    var reachedQuarter: Bool { quarterMileSeconds != nil }
}

struct PerformanceEngineSnapshot: Equatable, Sendable {
    var phase: PerformancePhase = .idle
    var liveRun: LivePerformanceRun?
    var lastCompletedRun: PerformanceRunSummary?
    var lastCancelReason: PerformanceCancelReason?
    var lastCompletionReason: PerformanceCompletionReason?
    var launchDetected: Bool = false
    var isCurrentRunValid: Bool = true
    var gpsQualityReady: Bool = false
    var stopHoldSatisfied: Bool = false

    static let idle = PerformanceEngineSnapshot()
}

enum PerformanceLabels {
    static func accelerationTitle(mphTarget: Int, unit: SpeedUnit) -> String {
        switch unit {
        case .milesPerHour:
            return "0–\(mphTarget)"
        case .kilometersPerHour:
            let kph = Int((Double(mphTarget) * 1.609_344).rounded())
            return "0–\(kph)"
        }
    }

    static func eighthTitle(unit: DistanceUnit) -> String {
        switch unit {
        case .miles: "1/8 Mile"
        case .kilometers: "201 m"
        }
    }

    static func quarterTitle(unit: DistanceUnit) -> String {
        switch unit {
        case .miles: "1/4 Mile"
        case .kilometers: "402 m"
        }
    }
}
