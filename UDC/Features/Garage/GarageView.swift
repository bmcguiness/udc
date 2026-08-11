import SwiftData
import SwiftUI

struct GarageView: View {
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddVehicle = false
    @State private var path = NavigationPath()

    private var activeVehicle: VehicleProfile? {
        vehicles.first(where: \.isActive) ?? vehicles.first
    }

    private var otherVehicles: [VehicleProfile] {
        vehicles.filter { $0.id != activeVehicle?.id }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if vehicles.isEmpty {
                    EmptyStateView(
                        symbol: "car.side.fill",
                        title: "Your garage is empty",
                        message: "Add a vehicle to personalize dashboards, data sources, and performance context.",
                        actionTitle: "Add Vehicle",
                        action: { showingAddVehicle = true }
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            if let active = activeVehicle {
                                SectionHeader(title: "Active", subtitle: "Tap to edit")
                                Button {
                                    path.append(active.id)
                                } label: {
                                    activeVehicleHero(active)
                                }
                                .buttonStyle(.plain)
                                .appearAnimation(delay: 0.04)
                            }

                            if !otherVehicles.isEmpty {
                                SectionHeader(title: "Collection", subtitle: "Tap to open")
                                VStack(spacing: AppSpacing.md) {
                                    ForEach(Array(otherVehicles.enumerated()), id: \.element.id) { index, vehicle in
                                        VehicleCard(
                                            name: vehicle.name,
                                            detail: vehicleDetail(vehicle),
                                            dataSource: vehicle.dataSourceMode.displayName,
                                            isActive: false,
                                            symbol: symbol(for: vehicle.category),
                                            action: { path.append(vehicle.id) }
                                        )
                                        .appearAnimation(delay: 0.1 + Double(index) * 0.05)
                                    }
                                }
                            }

                            SecondaryButton(title: "Add Vehicle", symbol: "plus") {
                                showingAddVehicle = true
                            }
                            .appearAnimation(delay: 0.2)
                            .padding(.top, AppSpacing.xs)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.xl)
                    }
                }
            }
            .appScreenBackground()
            .navigationTitle("Garage")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddVehicle = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.appAccentMuted)
                    }
                    .accessibilityLabel("Add Vehicle")
                }
            }
            .navigationDestination(for: UUID.self) { vehicleID in
                if let vehicle = vehicles.first(where: { $0.id == vehicleID }) {
                    VehicleEditorView(mode: .edit(vehicle))
                } else {
                    Text("Vehicle unavailable")
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                AddVehicleView()
            }
            .onAppear {
                seedGarageIfNeeded()
                if ProcessInfo.processInfo.environment["UDC_EDIT_VEHICLE"] == "1",
                   let vehicle = activeVehicle ?? vehicles.first {
                    path.append(vehicle.id)
                }
            }
        }
        .tint(Color.appAccent)
    }

    private func seedGarageIfNeeded() {
        guard ProcessInfo.processInfo.environment["UDC_SEED_GARAGE"] == "1" else { return }
        guard vehicles.isEmpty else { return }
        let mustang = VehicleProfile(
            name: "1967 Mustang",
            year: 1967,
            make: "Ford",
            model: "Mustang",
            isActive: true,
            dataSourceMode: .manualDriveline
        )
        let gt3 = VehicleProfile(
            name: "GT3 Touring",
            year: 2022,
            make: "Porsche",
            model: "911",
            dataSourceMode: .obdEnhanced
        )
        modelContext.insert(mustang)
        modelContext.insert(gt3)
        try? modelContext.save()
    }

    private func activeVehicleHero(_ vehicle: VehicleProfile) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                        .fill(Color.appAccentMuted.opacity(0.16))
                        .frame(width: 72, height: 72)
                    Image(systemName: symbol(for: vehicle.category))
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Color.appAccentMuted)
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityHidden(true)

                Spacer()
                StatusBadge(title: "Active", icon: "checkmark", style: .success)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(vehicle.name)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appTextTertiary)
                        .accessibilityHidden(true)
                }
                if !vehicleDetail(vehicle).isEmpty {
                    Text(vehicleDetail(vehicle))
                        .font(AppTypography.secondary())
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

            HStack(spacing: AppSpacing.sm) {
                metaChip(title: "Source", value: vehicle.dataSourceMode.displayName)
                metaChip(title: "Units", value: vehicle.preferredSpeedUnit.rawValue)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: AppCornerRadius.xl, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: AppShadow.elevated.color, radius: AppShadow.elevated.radius, y: AppShadow.elevated.y)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.xl, style: .continuous)
                .strokeBorder(Color.appAccentMuted.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(vehicle.name), active vehicle, \(vehicle.dataSourceMode.displayName). Double tap to edit.")
        .accessibilityAddTraits(.isButton)
    }

    private func metaChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.micro())
                .foregroundStyle(Color.appTextTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(value)
                .font(AppTypography.label())
                .foregroundStyle(Color.appTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
                .fill(Color.appSurfaceInset)
        }
    }

    private func vehicleDetail(_ vehicle: VehicleProfile) -> String {
        [vehicle.year.map(String.init), vehicle.make, vehicle.model]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private func symbol(for category: VehicleCategory) -> String {
        switch category {
        case .car: "car.side.fill"
        case .truck: "truck.box.fill"
        case .motorcycle: "bicycle"
        case .other: "car.fill"
        }
    }
}

#Preview {
    GarageView()
        .modelContainer(for: VehicleProfile.self, inMemory: true)
        .preferredColorScheme(.dark)
}
