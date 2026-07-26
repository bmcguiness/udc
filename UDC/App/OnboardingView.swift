import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(Color.appAccent)
                        .accessibilityHidden(true)
                    Text("A driving companion that works with every car.")
                        .font(.largeTitle.bold())
                    Text("Start with the connection approach that fits your vehicle. You can change it later.")
                        .foregroundStyle(.secondary)
                    choice("Use GPS only", icon: "location", mode: .gpsOnly)
                    Button { notice = "OBD-II adapter support will be added during development." } label: {
                        choiceLabel("Connect an OBD-II adapter", icon: "cable.connector")
                    }
                    Button { beginManualVehicle() } label: {
                        choiceLabel("Configure a classic or non-OBD vehicle", icon: "wrench.and.screwdriver")
                    }
                    choice("Decide later", icon: "arrow.right.circle", mode: nil)
                    if let notice {
                        Text(notice).font(.callout).foregroundStyle(.secondary).accessibilityLabel(notice)
                    }
                }
                .padding(AppSpacing.large)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Skip") { isComplete = true } }
            }
        }
    }

    private func choice(_ title: String, icon: String, mode: VehicleDataSourceMode?) -> some View {
        Button {
            if let mode { modelContext.insert(VehicleProfile(name: "My Vehicle", dataSourceMode: mode)) }
            isComplete = true
        } label: { choiceLabel(title, icon: icon) }
    }

    private func choiceLabel(_ title: String, icon: String) -> some View {
        HStack { Image(systemName: icon).frame(width: 30); Text(title); Spacer(); Image(systemName: "chevron.right") }
            .font(.headline)
            .foregroundStyle(.primary)
            .padding()
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: AppCornerRadius.medium))
    }

    private func beginManualVehicle() {
        modelContext.insert(VehicleProfile(name: "My Classic", dataSourceMode: .manualDriveline))
        isComplete = true
    }
}
