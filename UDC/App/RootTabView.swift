import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.50percent") }
            DrivesView()
                .tabItem { Label("Drives", systemImage: "road.lanes") }
            PerformanceView()
                .tabItem { Label("Performance", systemImage: "stopwatch") }
            GarageView()
                .tabItem { Label("Garage", systemImage: "car.side") }
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
    }
}

private struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink { FuelView() } label: { Label("Fuel", systemImage: "fuelpump") }
                NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gearshape") }
            }
            .navigationTitle("More")
        }
    }
}
