import XCTest
@testable import UDC

final class UsagePolicyTests: XCTestCase {
    func testFreeAllowance() { XCTAssertTrue(ProvisionalUsagePolicy.canRecordDrive(.init(freeMilesUsed: 24.9))); XCTAssertFalse(ProvisionalUsagePolicy.canRecordDrive(.init(freeMilesUsed: 25))); XCTAssertTrue(ProvisionalUsagePolicy.canStartPerformanceRun(.init(freePerformanceRunsUsed: 9))); XCTAssertFalse(ProvisionalUsagePolicy.canStartPerformanceRun(.init(freePerformanceRunsUsed: 10))) }
    func testUnlockBypassesAllowances() { let unlocked = UsageEntitlement(freeMilesUsed: 100, freePerformanceRunsUsed: 100, isFullyUnlocked: true); XCTAssertTrue(ProvisionalUsagePolicy.canRecordDrive(unlocked)); XCTAssertTrue(ProvisionalUsagePolicy.canStartPerformanceRun(unlocked)) }
}
