import SwiftData
import SwiftUI

struct DrivesView: View {
    @Query(sort: \DriveRecord.endedAt, order: .reverse) private var drives: [DriveRecord]

    var body: some View {
        NavigationStack {
            Group {
                if drives.isEmpty {
                    EmptyStateView(
                        symbol: "road.lanes",
                        title: "No drives yet",
                        message: "Completed drives appear here automatically after meaningful trips with distance, duration, and speed statistics."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(drives) { drive in
                                NavigationLink {
                                    DriveDetailView(drive: drive)
                                } label: {
                                    DriveRowCard(drive: drive)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.xl)
                    }
                }
            }
            .appScreenBackground()
            .navigationTitle("Drives")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
        }
        .tint(Color.appAccent)
    }
}

private struct DriveRowCard: View {
    let drive: DriveRecord

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(drive.vehicleName)
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                    Text(drive.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(AppTypography.footnote())
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appTextTertiary)
                    .accessibilityHidden(true)
            }

            HStack(spacing: AppSpacing.sm) {
                metric(title: "Distance", value: String(format: "%.1f %@", drive.displayDistance, drive.distanceUnit.rawValue))
                metric(title: "Duration", value: formatDuration(drive.durationSeconds))
                metric(title: "Avg", value: String(format: "%.0f %@", drive.displayAverageSpeed, drive.speedUnit.rawValue))
                metric(title: "Max", value: String(format: "%.0f %@", drive.displayMaximumSpeed, drive.speedUnit.rawValue))
            }
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
        .accessibilityLabel(accessibilityLabel)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(AppTypography.micro())
                .foregroundStyle(Color.appTextTertiary)
                .tracking(0.4)
            Text(value)
                .font(AppTypography.label())
                .foregroundStyle(Color.appTextPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilityLabel: String {
        "\(drive.vehicleName), \(drive.startedAt.formatted(date: .abbreviated, time: .shortened)), \(String(format: "%.1f", drive.displayDistance)) \(drive.distanceUnit.rawValue), \(formatDuration(drive.durationSeconds))"
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct DriveDetailView: View {
    let drive: DriveRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                AppCard(elevated: true) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        StatusBadge(title: "Completed", icon: "checkmark", style: .success)
                        Text(drive.vehicleName)
                            .font(.title.weight(.semibold))
                            .foregroundStyle(Color.appTextPrimary)
                        Text(drive.startedAt.formatted(date: .complete, time: .shortened))
                            .font(AppTypography.secondary())
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: 0) {
                        InfoRow(title: "Duration", value: formatDuration(drive.durationSeconds), symbol: "timer")
                        InfoRow(
                            title: "Distance",
                            value: String(format: "%.2f %@", drive.displayDistance, drive.distanceUnit.settingsLabel.lowercased()),
                            symbol: "point.topleft.down.to.point.bottomright.curvepath"
                        )
                        InfoRow(
                            title: "Average Speed",
                            value: String(format: "%.1f %@", drive.displayAverageSpeed, drive.speedUnit.rawValue),
                            symbol: "speedometer"
                        )
                        InfoRow(
                            title: "Maximum Speed",
                            value: String(format: "%.1f %@", drive.displayMaximumSpeed, drive.speedUnit.rawValue),
                            symbol: "gauge.with.needle.fill",
                            showsDivider: false
                        )
                    }
                }

                futureSection(title: "Route", message: "Route maps and path summaries will appear here in a future update.")
                futureSection(title: "Performance", message: "Linked acceleration and distance runs will appear here.")
                futureSection(title: "Fuel", message: "Economy and cost insights for this drive will appear here.")
                futureSection(title: "Notes", message: "Personal notes and tags will appear here.")
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .appScreenBackground()
        .navigationTitle("Drive")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .tint(Color.appAccent)
    }

    private func futureSection(title: String, message: String) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SectionHeader(title: title, subtitle: "Coming later")
                Text(message)
                    .font(AppTypography.secondary())
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d hr %d min", hours, minutes)
        }
        if minutes > 0 {
            return String(format: "%d min %d sec", minutes, seconds)
        }
        return String(format: "%d sec", seconds)
    }
}

#Preview {
    DrivesView()
        .modelContainer(for: [VehicleProfile.self, DriveRecord.self], inMemory: true)
        .preferredColorScheme(.dark)
}
