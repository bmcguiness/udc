import SwiftData
import SwiftUI

struct SettingsView: View {
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.dark.rawValue
    @State private var pendingDestination: SettingsDestination?

    private var activeVehicle: VehicleProfile? {
        vehicles.first(where: \.isActive) ?? vehicles.first
    }

    private var unitsSummary: String {
        guard let vehicle = activeVehicle else { return "—" }
        return "\(vehicle.preferredSpeedUnit.settingsLabel) · \(vehicle.preferredDistanceUnit.settingsLabel)"
    }

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? .dark
    }

    private var aboutVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                    .appearAnimation(delay: 0.02)

                settingsGroup(title: "Preferences") {
                    NavigationLink {
                        UnitsSettingsView()
                    } label: {
                        settingsRowLabel(symbol: "ruler", title: "Units", value: unitsSummary)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        settingsRowLabel(symbol: "circle.lefthalf.filled", title: "Appearance", value: appearance.title)
                    }
                    .buttonStyle(.plain)

                    settingsRowLabel(symbol: "textformat.size", title: "Display Density", value: "Comfortable", showsDivider: false, showsChevron: false)
                        .opacity(0.55)
                        .accessibilityHint("Coming later")
                }
                .appearAnimation(delay: 0.08)

                settingsGroup(title: "Connections") {
                    NavigationLink {
                        OBDAdaptersInfoView()
                    } label: {
                        settingsRowLabel(symbol: "dot.radiowaves.left.and.right", title: "OBD-II Adapters", value: "Not configured")
                    }
                    .buttonStyle(.plain)

                    settingsRowLabel(symbol: "location.circle", title: "Location Services", value: "Ready", showsDivider: false, showsChevron: false)
                        .opacity(0.55)
                        .accessibilityHint("Coming later")
                }
                .appearAnimation(delay: 0.14)

                settingsGroup(title: "Privacy") {
                    NavigationLink {
                        PrivacySettingsView()
                    } label: {
                        settingsRowLabel(symbol: "hand.raised.fill", title: "Data & Privacy", value: "On Device", showsDivider: false)
                    }
                    .buttonStyle(.plain)
                }
                .appearAnimation(delay: 0.2)

                settingsGroup(title: "About") {
                    NavigationLink {
                        AboutSettingsView()
                    } label: {
                        settingsRowLabel(symbol: "info.circle.fill", title: "About UDC", value: aboutVersion, showsDivider: false)
                    }
                    .buttonStyle(.plain)
                }
                .appearAnimation(delay: 0.26)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .appScreenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .tint(Color.appAccent)
        .navigationDestination(item: $pendingDestination) { destination in
            switch destination {
            case .units: UnitsSettingsView()
            case .appearance: AppearanceSettingsView()
            case .obd: OBDAdaptersInfoView()
            case .privacy: PrivacySettingsView()
            case .about: AboutSettingsView()
            }
        }
        .onAppear {
            if let raw = ProcessInfo.processInfo.environment["UDC_SETTINGS_DEST"],
               let destination = SettingsDestination(rawValue: raw) {
                pendingDestination = destination
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Cabin preferences")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)
            Text("Configure units, connections, and privacy with the same restraint as the rest of UDC.")
                .font(AppTypography.secondary())
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeader(title: title)
            AppCard {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    private func settingsRowLabel(
        symbol: String,
        title: String,
        value: String,
        showsDivider: Bool = true,
        showsChevron: Bool = true
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.appSurfaceInset)
                        .frame(width: 32, height: 32)
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appAccentMuted)
                }
                .accessibilityHidden(true)

                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()

                if !value.isEmpty {
                    Text(value)
                        .font(AppTypography.secondary())
                        .foregroundStyle(Color.appTextSecondary)
                }

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.appTextTertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(value.isEmpty ? title : "\(title), \(value)")

            if showsDivider {
                Divider().overlay(Color.appHairline)
            }
        }
    }
}

// MARK: - Appearance preference

enum AppAppearance: String, CaseIterable, Identifiable {
    case dark
    case system

    static let storageKey = "appAppearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: "Dark"
        case .system: "System"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .system: nil
        }
    }
}

// MARK: - Units

struct UnitsSettingsView: View {
    @Query(sort: \VehicleProfile.createdAt) private var vehicles: [VehicleProfile]
    @Environment(\.modelContext) private var modelContext

    private var activeVehicle: VehicleProfile? {
        vehicles.first(where: \.isActive) ?? vehicles.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Units follow the active vehicle and stay on device with the rest of your garage.")
                    .font(AppTypography.secondary())
                    .foregroundStyle(Color.appTextSecondary)

                if let vehicle = activeVehicle {
                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "Speed", subtitle: vehicle.name)
                            ForEach(SpeedUnit.allCases, id: \.self) { unit in
                                selectionRow(
                                    title: unit.settingsLabel,
                                    subtitle: unit.settingsDetail,
                                    selected: vehicle.preferredSpeedUnit == unit
                                ) {
                                    updateSpeed(unit, on: vehicle)
                                }
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: "Distance")
                            ForEach(DistanceUnit.allCases, id: \.self) { unit in
                                selectionRow(
                                    title: unit.settingsLabel,
                                    subtitle: unit.settingsDetail,
                                    selected: vehicle.preferredDistanceUnit == unit,
                                    showsDivider: unit != DistanceUnit.allCases.last
                                ) {
                                    updateDistance(unit, on: vehicle)
                                }
                            }
                        }
                    }
                } else {
                    EmptyStateView(
                        symbol: "car.side",
                        title: "No active vehicle",
                        message: "Add a vehicle in Garage to configure speed and distance units."
                    )
                    .frame(minHeight: 280)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .appScreenBackground()
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
    }

    private func selectionRow(
        title: String,
        subtitle: String,
        selected: Bool,
        showsDivider: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                    Text(subtitle)
                        .font(AppTypography.footnote())
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? Color.appAccentMuted : Color.appTextTertiary)
            }
            .padding(.vertical, AppSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .overlay(alignment: .bottom) {
            if showsDivider {
                Divider().overlay(Color.appHairline)
            }
        }
    }

    private func updateSpeed(_ unit: SpeedUnit, on vehicle: VehicleProfile) {
        withAnimation(AppMotion.quick) {
            vehicle.preferredSpeedUnit = unit
            vehicle.modifiedAt = .now
            try? modelContext.save()
        }
    }

    private func updateDistance(_ unit: DistanceUnit, on vehicle: VehicleProfile) {
        withAnimation(AppMotion.quick) {
            vehicle.preferredDistanceUnit = unit
            vehicle.modifiedAt = .now
            try? modelContext.save()
        }
    }
}

// MARK: - Appearance

struct AppearanceSettingsView: View {
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.dark.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("UDC is designed as a dark digital cockpit. System follows your iPhone appearance setting.")
                    .font(AppTypography.secondary())
                    .foregroundStyle(Color.appTextSecondary)

                AppCard {
                    VStack(spacing: 0) {
                        ForEach(AppAppearance.allCases) { option in
                            Button {
                                withAnimation(AppMotion.quick) {
                                    appearanceRaw = option.rawValue
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(Color.appTextPrimary)
                                        Text(option == .dark
                                             ? "Premium graphite cockpit (recommended)"
                                             : "Match Light or Dark from iOS Settings")
                                            .font(AppTypography.footnote())
                                            .foregroundStyle(Color.appTextSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: appearanceRaw == option.rawValue ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(appearanceRaw == option.rawValue ? Color.appAccentMuted : Color.appTextTertiary)
                                }
                                .padding(.vertical, AppSpacing.sm)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(appearanceRaw == option.rawValue ? .isSelected : [])

                            if option != AppAppearance.allCases.last {
                                Divider().overlay(Color.appHairline)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .appScreenBackground()
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
    }
}

// MARK: - OBD placeholder

struct OBDAdaptersInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                AppCard(elevated: true) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        StatusBadge(title: "Planned", icon: "antenna.radiowaves.left.and.right", style: .accent)
                        Text("Bluetooth OBD-II")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.appTextPrimary)
                        Text("Adapter support is planned so UDC can read live engine data when you choose. Until then, the app remains fully usable with GPS or manual driveline configuration.")
                            .font(AppTypography.secondary())
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        SectionHeader(title: "What this means")
                        InfoRow(title: "No adapter required", value: "Always", symbol: "checkmark.circle")
                        InfoRow(title: "Bluetooth pairing", value: "Coming later", symbol: "cable.connector")
                        InfoRow(title: "Live RPM & sensors", value: "Optional", symbol: "gauge.with.needle", showsDivider: false)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .appScreenBackground()
        .navigationTitle("OBD-II Adapters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
    }
}

// MARK: - Privacy

struct PrivacySettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                AppCard(elevated: true) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        StatusBadge(title: "On Device", icon: "lock.fill", style: .success)
                        Text("Your drives stay with you")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.appTextPrimary)
                        Text("UDC is built so driving data remains on your iPhone by default.")
                            .font(AppTypography.secondary())
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        SectionHeader(title: "Current posture")
                        InfoRow(title: "On-device by default", value: "Yes", symbol: "iphone")
                        InfoRow(title: "Account required", value: "No", symbol: "person.crop.circle")
                        InfoRow(title: "Analytics / tracking", value: "Not implemented", symbol: "chart.bar")
                        InfoRow(title: "Cloud or sharing", value: "Opt-in later", symbol: "icloud", showsDivider: false)
                    }
                }

                Text("Any future cloud or sharing features should be explicitly enabled by you.")
                    .font(AppTypography.footnote())
                    .foregroundStyle(Color.appTextTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .appScreenBackground()
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
    }
}

// MARK: - About

struct AboutSettingsView: View {
    @State private var showDiagnostics = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                AppCard(elevated: true) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(spacing: 10) {
                            Image(systemName: "gauge.with.dots.needle.67percent")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(Color.appAccentMuted)
                            Text("UDC")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(Color.appTextPrimary)
                                .tracking(2)
                        }
                        Text("A premium driving companion for every car.")
                            .font(AppTypography.secondary())
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
                .onLongPressGesture(minimumDuration: 1.0) {
                    showDiagnostics = true
                }
                .accessibilityHint("Long press for diagnostics")

                AppCard {
                    VStack(alignment: .leading, spacing: 0) {
                        InfoRow(title: "Product", value: "UDC", symbol: "car.side")
                        InfoRow(title: "Version", value: version, symbol: "number")
                        InfoRow(title: "Build", value: build, symbol: "hammer", showsDivider: false)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .appScreenBackground()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .navigationDestination(isPresented: $showDiagnostics) {
            DiagnosticsView()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: VehicleProfile.self, inMemory: true)
    .preferredColorScheme(.dark)
}

private enum SettingsDestination: String, Hashable, Identifiable {
    case units
    case appearance
    case obd
    case privacy
    case about

    var id: String { rawValue }
}
