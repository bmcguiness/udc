import SwiftUI

struct DashboardView: View {
    private let data = DashboardPreviewData.sample
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.medium) {
                    AppCard {
                        VStack { Text("\(data.speed)").font(.system(size: 72, weight: .semibold, design: .rounded)).monospacedDigit(); Text(data.speedUnit).font(.headline).foregroundStyle(.secondary) }
                            .frame(maxWidth: .infinity).accessibilityElement(children: .combine).accessibilityLabel("Current speed \(data.speed) \(data.speedUnit)")
                    }
                    AppCard { metric("Engine speed", value: data.rpmText, symbol: "tachometer") }
                    HStack(spacing: AppSpacing.medium) {
                        AppCard { metric("Trip", value: data.trip, symbol: "point.topleft.down.to.point.bottomright.curvepath") }
                        AppCard { metric("Duration", value: data.duration, symbol: "clock") }
                    }
                    AppCard { Label("Data source: \(data.source)", systemImage: "antenna.radiowaves.left.and.right"); Text("Ready to start a drive").font(.headline).padding(.top, AppSpacing.small); Button("Start Drive") { }.buttonStyle(.borderedProminent) }
                }.padding()
            }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Dashboard")
        }
    }
    private func metric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) { Label(title, systemImage: symbol).foregroundStyle(.secondary); Text(value).font(.title2.bold()).monospacedDigit() }.accessibilityElement(children: .combine)
    }
}

private struct DashboardPreviewData { let speed: Int; let speedUnit, rpmText, trip, duration, source: String; static let sample = Self(speed: 0, speedUnit: "mph", rpmText: "2,150 estimated", trip: "12.4 mi", duration: "00:24:18", source: "Manual driveline") }
