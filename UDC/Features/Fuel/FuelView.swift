import SwiftUI

struct FuelView: View {
    let areas = [("Fill-up history", "list.bullet.rectangle"), ("Fuel economy", "chart.line.uptrend.xyaxis"), ("Fuel cost", "dollarsign.circle"), ("Gas911", "fuelpump.exclamationmark")]
    var body: some View { List(areas, id: \.0) { Label($0.0, systemImage: $0.1); Text("Future feature").font(.caption).foregroundStyle(.secondary) }.navigationTitle("Fuel") }
}
