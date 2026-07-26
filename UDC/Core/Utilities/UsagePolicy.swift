struct UsageEntitlement: Equatable {
    var freeMilesUsed: Double = 0
    var freePerformanceRunsUsed: Int = 0
    var isFullyUnlocked: Bool = false
}

enum ProvisionalUsagePolicy {
    static let freeMilesAllowance: Double = 25
    static let freePerformanceRunsAllowance = 10
    static func canRecordDrive(_ entitlement: UsageEntitlement) -> Bool {
        entitlement.isFullyUnlocked || entitlement.freeMilesUsed < freeMilesAllowance
    }
    static func canStartPerformanceRun(_ entitlement: UsageEntitlement) -> Bool {
        entitlement.isFullyUnlocked || entitlement.freePerformanceRunsUsed < freePerformanceRunsAllowance
    }
}
