import SwiftData
import SwiftUI

struct GarageView: View {
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddVehicle = false
    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty { ContentUnavailableView("No Vehicles", systemImage: "car.side", description: Text("Add a vehicle to personalize UDC.")) }
                else { List(vehicles) { vehicle in Button { VehicleProfile.selectActive(vehicle, among: vehicles); try? modelContext.save() } label: { HStack { VStack(alignment: .leading) { Text(vehicle.name).font(.headline); Text([vehicle.year.map(String.init), vehicle.make, vehicle.model].compactMap { $0 }.joined(separator: " ")).font(.subheadline).foregroundStyle(.secondary); Text(vehicle.dataSourceMode.displayName).font(.caption).foregroundStyle(.secondary) }; Spacer(); if vehicle.isActive { Label("Active", systemImage: "checkmark.circle.fill").labelStyle(.iconOnly).foregroundStyle(.tint).accessibilityLabel("Active vehicle") } } }.foregroundStyle(.primary) } }
            }.navigationTitle("Garage").toolbar { Button { showingAddVehicle = true } label: { Label("Add Vehicle", systemImage: "plus") } }.sheet(isPresented: $showingAddVehicle) { AddVehicleView() }
        }
    }
}
