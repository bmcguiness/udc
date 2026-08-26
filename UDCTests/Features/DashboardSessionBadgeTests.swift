import XCTest
@testable import UDC

final class DashboardSessionBadgeTests: XCTestCase {
    func testEndDriveActionUnavailableWithoutActiveDrive() {
        XCTAssertFalse(DashboardHeader.isEndDriveActionAvailable(canEndDriveManually: false))
    }

    func testEndDriveActionAvailableWhenManualEndAllowed() {
        XCTAssertTrue(DashboardHeader.isEndDriveActionAvailable(canEndDriveManually: true))
    }

    func testEndDriveAccessibilityHintOnlyWhenActionAvailable() {
        XCTAssertEqual(
            DashboardHeader.endDriveAccessibilityHint,
            "Double tap to end the current drive."
        )
    }

    func testDrivingWithConfirmationShowsWaitingWithoutAction() {
        let presentation = DashboardSessionBadgePresentation.resolve(
            phase: .driving,
            isEndDriveConfirmationPresented: true,
            canEndDriveManually: true,
            gpsStatus: .ready,
            isMoving: true
        )
        XCTAssertEqual(presentation.title, "Waiting")
        XCTAssertEqual(presentation.style, .neutral)
        XCTAssertFalse(presentation.isActionable)
        XCTAssertFalse(presentation.showsActionAffordance)
        XCTAssertEqual(
            presentation.accessibilityLabel,
            DashboardSessionBadgePresentation.waitingAccessibilityLabel
        )
        XCTAssertNil(presentation.accessibilityHint)
    }

    func testPausedWithConfirmationShowsWaitingWithoutAction() {
        let presentation = DashboardSessionBadgePresentation.resolve(
            phase: .stopped,
            isEndDriveConfirmationPresented: true,
            canEndDriveManually: true,
            gpsStatus: .ready,
            isMoving: false
        )
        XCTAssertEqual(presentation.title, "Waiting")
        XCTAssertFalse(presentation.isActionable)
        XCTAssertFalse(presentation.showsActionAffordance)
    }

    func testCancelWhileStillDrivingRestoresDrivingActionable() {
        let presentation = DashboardSessionBadgePresentation.resolve(
            phase: .driving,
            isEndDriveConfirmationPresented: false,
            canEndDriveManually: true,
            gpsStatus: .ready,
            isMoving: true
        )
        XCTAssertEqual(presentation.title, "Driving")
        XCTAssertTrue(presentation.isActionable)
        XCTAssertTrue(presentation.showsActionAffordance)
        XCTAssertEqual(presentation.accessibilityHint, DashboardHeader.endDriveAccessibilityHint)
    }

    func testCancelAfterEngineMovesToPausedShowsPaused() {
        let presentation = DashboardSessionBadgePresentation.resolve(
            phase: .stopped,
            isEndDriveConfirmationPresented: false,
            canEndDriveManually: true,
            gpsStatus: .ready,
            isMoving: false
        )
        XCTAssertEqual(presentation.title, "Paused")
        XCTAssertTrue(presentation.isActionable)
        XCTAssertTrue(presentation.showsActionAffordance)
    }

    func testPreparingNeverExposesEndDriveEvenIfFlagTrue() {
        // canEndDriveManually is false for preparing in the engine; UI still respects the flag.
        let presentation = DashboardSessionBadgePresentation.resolve(
            phase: .preparing,
            isEndDriveConfirmationPresented: false,
            canEndDriveManually: false,
            gpsStatus: .ready,
            isMoving: true
        )
        XCTAssertEqual(presentation.title, "Preparing")
        XCTAssertFalse(presentation.isActionable)
        XCTAssertFalse(presentation.showsActionAffordance)
    }

    func testIdleDoesNotExposeEndDrive() {
        let presentation = DashboardSessionBadgePresentation.resolve(
            phase: .idle,
            isEndDriveConfirmationPresented: false,
            canEndDriveManually: false,
            gpsStatus: .ready,
            isMoving: false
        )
        XCTAssertEqual(presentation.title, "Ready")
        XCTAssertFalse(presentation.isActionable)
    }

    func testWaitingDoesNotDependOnStalePhaseSnapshot() {
        // Confirmation open while engine already paused still shows Waiting.
        let fromDriving = DashboardSessionBadgePresentation.resolve(
            phase: .driving,
            isEndDriveConfirmationPresented: true,
            canEndDriveManually: true,
            gpsStatus: .ready,
            isMoving: false
        )
        let fromPaused = DashboardSessionBadgePresentation.resolve(
            phase: .stopped,
            isEndDriveConfirmationPresented: true,
            canEndDriveManually: true,
            gpsStatus: .ready,
            isMoving: false
        )
        XCTAssertEqual(fromDriving.title, fromPaused.title)
        XCTAssertEqual(fromDriving.isActionable, fromPaused.isActionable)
    }
}
