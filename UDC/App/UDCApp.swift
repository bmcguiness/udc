import SwiftData
import SwiftUI

@main
struct UDCApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.dark.rawValue
    @Environment(\.scenePhase) private var scenePhase

    @State private var telemetry: DrivingTelemetryService
    @State private var drivingEngine: DrivingEngine
    @State private var performanceEngine: PerformanceEngine

    private var preferredScheme: ColorScheme? {
        (AppAppearance(rawValue: appearanceRaw) ?? .dark).preferredColorScheme
    }

    init() {
        let telemetry = DrivingTelemetryService(locationProvider: CoreLocationProvider())
        // Register DrivingEngine before PerformanceEngine so session state is current.
        let engine = DrivingEngine(telemetry: telemetry)
        let performance = PerformanceEngine(telemetry: telemetry, drivingEngine: engine)
        _telemetry = State(initialValue: telemetry)
        _drivingEngine = State(initialValue: engine)
        _performanceEngine = State(initialValue: performance)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootTabView()
                } else {
                    OnboardingView(isComplete: $hasCompletedOnboarding)
                }
            }
            .environment(telemetry)
            .environment(drivingEngine)
            .environment(performanceEngine)
            .tint(Color.appAccent)
            .preferredColorScheme(preferredScheme)
            .onAppear {
                IdleTimerController.apply(scenePhase: scenePhase)
                telemetry.updateLifecycleDiagnostics(
                    scenePhaseLabel: scenePhaseLabel(scenePhase),
                    idleTimerDisabled: IdleTimerController.isIdleTimerDisabled
                )
            }
            .onChange(of: scenePhase) { _, newPhase in
                IdleTimerController.apply(scenePhase: newPhase)
                telemetry.updateLifecycleDiagnostics(
                    scenePhaseLabel: scenePhaseLabel(newPhase),
                    idleTimerDisabled: IdleTimerController.isIdleTimerDisabled
                )
                drivingEngine.handleScenePhase(newPhase)
                performanceEngine.handleScenePhase(newPhase)
            }
        }
        .modelContainer(for: [VehicleProfile.self, DriveRecord.self])
    }

    private func scenePhaseLabel(_ phase: ScenePhase) -> String {
        switch phase {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown"
        }
    }
}
