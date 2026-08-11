import SwiftData
import SwiftUI

/// Shared add / edit form for `VehicleProfile`.
struct VehicleEditorView: View {
    enum Mode {
        case add
        case edit(VehicleProfile)
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]

    @State private var name = ""
    @State private var year = ""
    @State private var make = ""
    @State private var model = ""
    @State private var dataSourceMode = VehicleDataSourceMode.gpsOnly

    private var editingVehicle: VehicleProfile? {
        if case .edit(let vehicle) = mode { return vehicle }
        return nil
    }

    private var isEditing: Bool { editingVehicle != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var navigationTitle: String {
        isEditing ? "Edit Vehicle" : "Add Vehicle"
    }

    private var primaryTitle: String {
        isEditing ? "Save Changes" : "Add to Garage"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                    .appearAnimation(delay: 0.02)

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeader(title: "Identity")
                        field(title: "Name", text: $name, prompt: "1967 Mustang", contentType: .name)
                        field(title: "Year", text: $year, prompt: "1967", keyboard: .numberPad)
                        field(title: "Make", text: $make, prompt: "Ford")
                        field(title: "Model", text: $model, prompt: "Mustang", showsDivider: false)
                    }
                }
                .appearAnimation(delay: 0.08)

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeader(title: "Data Source", subtitle: "How this vehicle will supply data")
                        ForEach(VehicleDataSourceMode.allCases) { option in
                            modeRow(option)
                        }
                    }
                }
                .appearAnimation(delay: 0.14)

                if let vehicle = editingVehicle, !vehicle.isActive {
                    SecondaryButton(title: "Set Active", symbol: "checkmark.circle") {
                        setActive(vehicle)
                    }
                    .appearAnimation(delay: 0.18)
                }

                PrimaryButton(title: primaryTitle, symbol: isEditing ? "checkmark" : "plus", isEnabled: canSave) {
                    save()
                }
                .appearAnimation(delay: 0.22)
                .padding(.top, AppSpacing.xs)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .appScreenBackground()
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbar {
            if !isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .tint(Color.appAccent)
        .onAppear(perform: loadIfNeeded)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(isEditing ? "Refine this vehicle" : "Build your collection")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)
            Text(isEditing
                 ? "Changes update this vehicle in place. Active status is preserved unless you set another vehicle active."
                 : "Every vehicle gets its own data mode, units, and performance context.")
                .font(AppTypography.secondary())
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func field(
        title: String,
        text: Binding<String>,
        prompt: String,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        showsDivider: Bool = true
    ) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(AppTypography.micro())
                    .foregroundStyle(Color.appTextTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                TextField(prompt, text: text)
                    .font(.body)
                    .foregroundStyle(Color.appTextPrimary)
                    .keyboardType(keyboard)
                    .textContentType(contentType)
                    .autocorrectionDisabled()
            }
            .padding(.vertical, AppSpacing.xs)
            if showsDivider {
                Divider().overlay(Color.appHairline)
            }
        }
    }

    private func modeRow(_ option: VehicleDataSourceMode) -> some View {
        let selected = dataSourceMode == option
        return Button {
            withAnimation(AppMotion.quick) { dataSourceMode = option }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? Color.appAccentMuted : Color.appTextTertiary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                    Text(option.detail)
                        .font(AppTypography.footnote())
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.sm)
            .background {
                RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
                    .fill(selected ? Color.appAccentMuted.opacity(0.12) : Color.appSurfaceInset)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
                    .strokeBorder(selected ? Color.appAccentMuted.opacity(0.4) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.displayName)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func loadIfNeeded() {
        guard let vehicle = editingVehicle else { return }
        name = vehicle.name
        year = vehicle.year.map(String.init) ?? ""
        make = vehicle.make ?? ""
        model = vehicle.model ?? ""
        dataSourceMode = vehicle.dataSourceMode
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let yearValue = Int(year)
        let makeValue = make.nilIfBlank
        let modelValue = model.nilIfBlank

        if let vehicle = editingVehicle {
            vehicle.applyEdits(
                name: trimmedName,
                year: yearValue,
                make: makeValue,
                model: modelValue,
                dataSourceMode: dataSourceMode
            )
            try? modelContext.save()
            dismiss()
            return
        }

        let profile = VehicleProfile(
            name: trimmedName,
            year: yearValue,
            make: makeValue,
            model: modelValue,
            dataSourceMode: dataSourceMode
        )
        if vehicles.isEmpty {
            profile.isActive = true
        }
        modelContext.insert(profile)
        try? modelContext.save()
        dismiss()
    }

    private func setActive(_ vehicle: VehicleProfile) {
        withAnimation(AppMotion.standard) {
            VehicleProfile.selectActive(vehicle, among: vehicles)
            try? modelContext.save()
        }
    }
}

struct AddVehicleView: View {
    var body: some View {
        NavigationStack {
            VehicleEditorView(mode: .add)
        }
    }
}

private extension VehicleDataSourceMode {
    var detail: String {
        switch self {
        case .gpsOnly:
            "Speed and trip from location — works with every car."
        case .obdEnhanced:
            "Live engine data when an adapter is connected."
        case .manualDriveline:
            "Estimated RPM from tire, axle, and gear ratios."
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

#Preview("Add") {
    AddVehicleView()
        .modelContainer(for: VehicleProfile.self, inMemory: true)
        .preferredColorScheme(.dark)
}
