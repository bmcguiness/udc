import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: Int

    init(initialTab: Int = 0) {
        let envTab = ProcessInfo.processInfo.environment["UDC_TAB"].flatMap(Int.init)
        _selectedTab = State(initialValue: envTab ?? initialTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: selectedTab == 0
                          ? "gauge.with.dots.needle.67percent"
                          : "gauge.with.dots.needle.33percent")
                }
                .tag(0)

            DrivesView()
                .tabItem {
                    Label("Drives", systemImage: "road.lanes")
                }
                .tag(1)

            PerformanceView()
                .tabItem {
                    Label("Performance", systemImage: "flag.checkered")
                }
                .tag(2)

            GarageView()
                .tabItem {
                    Label("Garage", systemImage: "car.side.fill")
                }
                .tag(3)

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
                .tag(4)
        }
        .tint(Color.appAccent)
        .toolbarBackground(Color.appSurface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

private struct MoreView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("More")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(Color.appTextPrimary)
                        Text("Fuel, settings, and future cabin tools.")
                            .font(AppTypography.secondary())
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.top, AppSpacing.xs)

                    VStack(spacing: AppSpacing.md) {
                        NavigationLink(value: MoreDestination.fuel) {
                            moreRow(
                                symbol: "fuelpump.fill",
                                title: "Fuel",
                                subtitle: "Economy, fill-ups, and Gas911"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(value: MoreDestination.settings) {
                            moreRow(
                                symbol: "gearshape.fill",
                                title: "Settings",
                                subtitle: "Units, connections, and privacy"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .appearAnimation(delay: 0.06)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
            .appScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MoreDestination.self) { destination in
                switch destination {
                case .fuel: FuelView()
                case .settings: SettingsView()
                }
            }
            .onAppear {
                if let route = ProcessInfo.processInfo.environment["UDC_MORE"],
                   let destination = MoreDestination(rawValue: route) {
                    path = NavigationPath([destination])
                }
            }
        }
        .tint(Color.appAccent)
    }

    private func moreRow(symbol: String, title: String, subtitle: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
                    .fill(Color.appSurfaceInset)
                    .frame(width: 52, height: 52)
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.appAccentMuted)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Text(subtitle)
                    .font(AppTypography.footnote())
                    .foregroundStyle(Color.appTextSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appTextTertiary)
                .accessibilityHidden(true)
        }
        .padding(AppSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: AppShadow.card.color, radius: AppShadow.card.radius, y: AppShadow.card.y)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                .strokeBorder(Color.appBorder, lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

private enum MoreDestination: String, Hashable {
    case fuel
    case settings
}

#Preview {
    RootTabView()
        .preferredColorScheme(.dark)
}
