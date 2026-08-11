import SwiftData
import SwiftUI

@main
struct UDCApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.dark.rawValue

    @State private var telemetry = DrivingTelemetryService(
        locationProvider: CoreLocationProvider()
    )

    private var preferredScheme: ColorScheme? {
        (AppAppearance(rawValue: appearanceRaw) ?? .dark).preferredColorScheme
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
            .tint(Color.appAccent)
            .preferredColorScheme(preferredScheme)
        }
        .modelContainer(for: VehicleProfile.self)
    }
}
