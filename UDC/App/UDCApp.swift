import SwiftData
import SwiftUI

@main
struct UDCApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RootTabView()
            } else {
                OnboardingView(isComplete: $hasCompletedOnboarding)
            }
        }
        .modelContainer(for: VehicleProfile.self)
    }
}
