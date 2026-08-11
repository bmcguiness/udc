import SwiftUI

struct DrivesView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                symbol: "road.lanes",
                title: "No drives yet",
                message: "Completed drives will appear here with distance, duration, speed statistics, and route summaries."
            )
            .appScreenBackground()
            .navigationTitle("Drives")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
        }
        .tint(Color.appAccent)
    }
}

#Preview {
    DrivesView()
        .preferredColorScheme(.dark)
}
