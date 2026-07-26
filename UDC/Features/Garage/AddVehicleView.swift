import SwiftData
import SwiftUI

struct AddVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""; @State private var year = ""; @State private var make = ""; @State private var model = ""; @State private var mode = VehicleDataSourceMode.gpsOnly
    var body: some View {
        NavigationStack { Form { TextField("Vehicle name", text: $name); TextField("Year (optional)", text: $year).keyboardType(.numberPad); TextField("Make (optional)", text: $make); TextField("Model (optional)", text: $model); Picker("Data source", selection: $mode) { ForEach(VehicleDataSourceMode.allCases) { Text($0.displayName).tag($0) } } }
            .navigationTitle("Add Vehicle").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Add") { modelContext.insert(VehicleProfile(name: name.trimmingCharacters(in: .whitespacesAndNewlines), year: Int(year), make: make.nilIfBlank, model: model.nilIfBlank, dataSourceMode: mode)); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
        }
    }
}

private extension String { var nilIfBlank: String? { let value = trimmingCharacters(in: .whitespacesAndNewlines); return value.isEmpty ? nil : value } }
