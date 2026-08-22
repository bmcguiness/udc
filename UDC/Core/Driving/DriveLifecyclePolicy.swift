import Foundation
import SwiftUI
import UIKit

/// Pure policy: keep the display awake only while UDC is foreground-active.
enum IdleTimerPolicy {
    static func shouldDisableIdleTimer(scenePhase: ScenePhase) -> Bool {
        scenePhase == .active
    }
}

/// Applies idle-timer policy to the shared application.
@MainActor
enum IdleTimerController {
    private(set) static var isIdleTimerDisabled: Bool = false

    static func apply(scenePhase: ScenePhase) {
        let disable = IdleTimerPolicy.shouldDisableIdleTimer(scenePhase: scenePhase)
        guard UIApplication.shared.isIdleTimerDisabled != disable else {
            isIdleTimerDisabled = disable
            return
        }
        UIApplication.shared.isIdleTimerDisabled = disable
        isIdleTimerDisabled = disable
    }
}

/// Pure policy: background GPS only while a drive is actively recording (or recoverable).
enum BackgroundLocationPolicy {
    static func shouldEnableBackgroundUpdates(phase: DriveSessionPhase) -> Bool {
        phase.isActivelyRecording
    }
}

/// Tunable durability / recovery knobs for active drives.
struct DriveDurabilityConfiguration: Equatable, Sendable {
    /// Minimum wall-clock gap between SwiftData checkpoints.
    var checkpointMinimumInterval: TimeInterval = 15
    /// Checkpoint after accumulating this much additional distance.
    var checkpointMinimumDistanceMeters: Double = 200
    /// Resume an in-progress drive if its last update is newer than this.
    var resumeIfUpdatedWithin: TimeInterval = 30 * 60
}

enum DriveCheckpointReason: String, Equatable, Sendable {
    case sessionStarted = "Session started"
    case timedInterval = "Timed interval"
    case distanceInterval = "Distance interval"
    case phaseTransition = "Phase transition"
    case enteredBackground = "Entered background"
    case finalized = "Finalized"
    case recovery = "Recovery"
    case staleFinalization = "Stale finalization"
}

enum DriveRecoveryReason: String, Equatable, Sendable {
    case resumedRecent = "Resumed recent in-progress drive"
    case finalizedStale = "Finalized stale in-progress drive"
    case discardedStaleTooShort = "Discarded stale short drive"
    case none = "None"
}
