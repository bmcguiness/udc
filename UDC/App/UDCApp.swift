import SwiftData
import SwiftUI

@main
struct UDCApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.dark.rawValue

    @State private var telemetry: DrivingTelemetryService
    @State private var drivingEngine: DrivingEngine

    private var preferredScheme: ColorScheme? {
        (AppAppearance(rawValue: appearanceRaw) ?? .dark).preferredColorScheme
    }

    init() {
        let telemetry = DrivingTelemetryService(locationProvider: CoreLocationProvider())
        let engine = DrivingEngine(telemetry: telemetry)
        _telemetry = State(initialValue: telemetry)
        _drivingEngine = State(initialValue: engine)
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
            .tint(Color.appAccent)
            .preferredColorScheme(preferredScheme)
        }
        .modelContainer(for: [VehicleProfile.self, DriveRecord.self])
    }
}
