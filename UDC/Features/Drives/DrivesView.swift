import SwiftUI

struct DrivesView: View {
    var body: some View { NavigationStack { ContentUnavailableView("No Drives Yet", systemImage: "road.lanes", description: Text("Completed drives will show date and time, distance, duration, route, speed statistics, and fuel statistics when available.")) .navigationTitle("Drives") } }
}
