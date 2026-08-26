import SwiftUI

// MARK: - Spacing

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    /// Legacy aliases used during migration.
    static let small: CGFloat = xs
    static let medium: CGFloat = md
    static let large: CGFloat = lg
}

// MARK: - Corners

enum AppCornerRadius {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 28

    static let small: CGFloat = sm
    static let medium: CGFloat = md
    static let large: CGFloat = lg
}

// MARK: - Motion

enum AppMotion {
    static let quick = Animation.easeOut(duration: 0.22)
    static let standard = Animation.easeInOut(duration: 0.32)
    static let emphasize = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let appear = Animation.easeOut(duration: 0.45)
}

// MARK: - Colors

extension Color {
    /// Muted steel-blue accent — primary interactive color.
    static let appAccent = Color(light: Color(hex: 0x3D5A73), dark: Color(hex: 0x7A9BB8))
    static let appAccentMuted = Color(light: Color(hex: 0x5A7A94), dark: Color(hex: 0x8AA8C0))

    static let appBackground = Color(light: Color(hex: 0xE8ECF0), dark: Color(hex: 0x0A0C0F))
    static let appBackgroundSecondary = Color(light: Color(hex: 0xF2F4F7), dark: Color(hex: 0x101419))

    static let appSurface = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x161A20))
    static let appSurfaceElevated = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x1C222A))
    static let appSurfaceInset = Color(light: Color(hex: 0xF0F3F6), dark: Color(hex: 0x0F1217))

    static let appBorder = Color(light: Color(hex: 0xD5DBE3).opacity(0.9), dark: Color(hex: 0x2A313C).opacity(0.9))
    static let appHairline = Color(light: Color(hex: 0xC8D0DA).opacity(0.7), dark: Color(hex: 0x3A4250).opacity(0.55))

    static let appTextPrimary = Color(light: Color(hex: 0x12151A), dark: Color(hex: 0xF2F4F7))
    static let appTextSecondary = Color(light: Color(hex: 0x5C6673), dark: Color(hex: 0x9AA3B0))
    static let appTextTertiary = Color(light: Color(hex: 0x8A93A0), dark: Color(hex: 0x6B7380))

    static let appSuccess = Color(light: Color(hex: 0x3D6B5C), dark: Color(hex: 0x6FA894))
    static let appWarning = Color(light: Color(hex: 0x8A6A3A), dark: Color(hex: 0xC4A46A))
    static let appDanger = Color(light: Color(hex: 0x7A4545), dark: Color(hex: 0xC47A7A))

    static let appGraphite = Color(hex: 0x2A2F38)
    static let appCharcoal = Color(hex: 0x161A20)
    static let appSlate = Color(hex: 0x3E4754)
    static let appNavy = Color(hex: 0x1A2433)

    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Typography

enum AppTypography {
    static func display(_ size: CGFloat = 88) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func metric(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func headline() -> Font {
        .system(.title3, design: .default).weight(.semibold)
    }

    static func section() -> Font {
        .system(.subheadline, design: .default).weight(.semibold)
    }

    static func body() -> Font {
        .system(.body, design: .default)
    }

    static func secondary() -> Font {
        .system(.subheadline, design: .default)
    }

    static func label() -> Font {
        .system(.caption, design: .default).weight(.medium)
    }

    static func footnote() -> Font {
        .system(.footnote, design: .default)
    }

    static func micro() -> Font {
        .system(.caption2, design: .default).weight(.medium)
    }
}

// MARK: - Shadows

struct AppShadow {
    var color: Color
    var radius: CGFloat
    var y: CGFloat

    static let card = AppShadow(
        color: Color(light: .black.opacity(0.06), dark: .black.opacity(0.45)),
        radius: 18,
        y: 8
    )

    static let elevated = AppShadow(
        color: Color(light: .black.opacity(0.08), dark: .black.opacity(0.55)),
        radius: 24,
        y: 12
    )

    static let subtle = AppShadow(
        color: Color(light: .black.opacity(0.04), dark: .black.opacity(0.35)),
        radius: 10,
        y: 4
    )
}

// MARK: - Card Style

struct AppCardStyle: ViewModifier {
    var padding: CGFloat = AppSpacing.md
    var cornerRadius: CGFloat = AppCornerRadius.lg
    var elevated: Bool = false

    func body(content: Content) -> some View {
        let shadow = elevated ? AppShadow.elevated : AppShadow.card
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(elevated ? Color.appSurfaceElevated : Color.appSurface)
                    .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 0.5)
            }
    }
}

extension View {
    func appCard(padding: CGFloat = AppSpacing.md, cornerRadius: CGFloat = AppCornerRadius.lg, elevated: Bool = false) -> some View {
        modifier(AppCardStyle(padding: padding, cornerRadius: cornerRadius, elevated: elevated))
    }

    func appScreenBackground() -> some View {
        background {
            ZStack {
                Color.appBackground
                RadialGradient(
                    colors: [
                        Color.appNavy.opacity(0.35),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 420
                )
                RadialGradient(
                    colors: [
                        Color.appAccentMuted.opacity(0.07),
                        Color.clear
                    ],
                    center: .bottomLeading,
                    startRadius: 10,
                    endRadius: 380
                )
            }
            .ignoresSafeArea()
        }
    }

    func appearAnimation(delay: Double = 0) -> some View {
        modifier(AppearAnimationModifier(delay: delay))
    }
}

private struct AppearAnimationModifier: ViewModifier {
    let delay: Double
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 12)
            .onAppear {
                withAnimation(AppMotion.appear.delay(delay)) {
                    visible = true
                }
            }
    }
}

// MARK: - AppCard

struct AppCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.md
    var elevated: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .appCard(padding: padding, elevated: elevated)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.section())
                    .foregroundStyle(Color.appTextPrimary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.footnote())
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            Spacer(minLength: AppSpacing.sm)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(AppTypography.label())
                    .foregroundStyle(Color.appAccentMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    enum Style: Equatable {
        case neutral, success, warning, accent, idle

        var foreground: Color {
            switch self {
            case .neutral: Color.appTextSecondary
            case .success: Color.appSuccess
            case .warning: Color.appWarning
            case .accent: Color.appAccentMuted
            case .idle: Color.appTextTertiary
            }
        }

        var background: Color {
            foreground.opacity(0.14)
        }
    }

    let title: String
    var icon: String? = nil
    var style: Style = .neutral
    var showsActionAffordance: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(AppTypography.micro())
                .tracking(0.4)
            if showsActionAffordance {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.72)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(style.foreground)
        .padding(.horizontal, showsActionAffordance ? 11 : 10)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(style.background))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    style.foreground.opacity(showsActionAffordance ? 0.32 : 0.18),
                    lineWidth: showsActionAffordance ? 0.75 : 0.5
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    var unit: String? = nil
    var symbol: String? = nil
    var footnote: String? = nil
    var emphasis: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appAccentMuted)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(AppTypography.label())
                    .foregroundStyle(Color.appTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(emphasis ? AppTypography.metric(40) : AppTypography.metric(28))
                    .foregroundStyle(Color.appTextPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let unit {
                    Text(unit)
                        .font(AppTypography.secondary())
                        .foregroundStyle(Color.appTextTertiary)
                }
            }

            if let footnote {
                Text(footnote)
                    .font(AppTypography.footnote())
                    .foregroundStyle(Color.appTextTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = ["\(title) \(value)"]
        if let unit { parts.append(unit) }
        if let footnote { parts.append(footnote) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Dashboard Metric (compact tile)

struct DashboardMetric: View {
    let title: String
    let value: String
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.appAccentMuted)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(AppTypography.micro())
                    .foregroundStyle(Color.appTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            Text(value)
                .font(AppTypography.metric(24))
                .foregroundStyle(Color.appTextPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .fill(Color.appSurfaceInset)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .strokeBorder(Color.appHairline, lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }
}

// MARK: - Dashboard Header

/// Presentation-only session badge state. Waiting is never a DrivingEngine phase.
struct DashboardSessionBadgePresentation: Equatable, Sendable {
    var title: String
    var style: StatusBadge.Style
    var icon: String?
    var isActionable: Bool
    var showsActionAffordance: Bool
    var accessibilityLabel: String
    var accessibilityHint: String?

    static let waitingAccessibilityLabel = "Waiting for End Drive confirmation"

    /// Resolves the header badge. `isEndDriveConfirmationPresented` forces Waiting without
    /// changing DrivingEngine. Cancel restores whatever phase the engine currently reports.
    static func resolve(
        phase: DriveSessionPhase,
        isEndDriveConfirmationPresented: Bool,
        canEndDriveManually: Bool,
        gpsStatus: GPSStatus,
        isMoving: Bool
    ) -> DashboardSessionBadgePresentation {
        if isEndDriveConfirmationPresented {
            return DashboardSessionBadgePresentation(
                title: "Waiting",
                style: .neutral,
                icon: "ellipsis",
                isActionable: false,
                showsActionAffordance: false,
                accessibilityLabel: waitingAccessibilityLabel,
                accessibilityHint: nil
            )
        }

        let title: String
        let style: StatusBadge.Style
        let icon: String
        if phase != .idle {
            title = phase.displayName
            switch phase {
            case .driving:
                style = .success
                icon = "car.fill"
            case .preparing:
                style = .accent
                icon = "hare.fill"
            case .stopped:
                style = .warning
                icon = "pause.fill"
            case .idle:
                style = .neutral
                icon = "circle.fill"
            }
        } else {
            switch gpsStatus {
            case .ready:
                title = isMoving ? "Live" : "Ready"
                style = .success
                icon = "location.fill"
            case .searching:
                title = "Searching"
                style = .accent
                icon = "location.magnifyingglass"
            case .poorSignal:
                title = "Weak Signal"
                style = .warning
                icon = "location.north.circle"
            case .permissionNeeded:
                title = "Permission"
                style = .neutral
                icon = "hand.raised.fill"
            case .locationDisabled:
                title = "Disabled"
                style = .neutral
                icon = "location.slash.fill"
            case .unavailable:
                title = "Unavailable"
                style = .warning
                icon = "exclamationmark.triangle.fill"
            }
        }

        let actionable = canEndDriveManually
        return DashboardSessionBadgePresentation(
            title: title,
            style: style,
            icon: icon,
            isActionable: actionable,
            showsActionAffordance: actionable,
            accessibilityLabel: title,
            accessibilityHint: actionable ? DashboardHeader.endDriveAccessibilityHint : nil
        )
    }
}

struct DashboardHeader: View {
    let vehicleName: String
    let statusTitle: String
    var statusStyle: StatusBadge.Style = .success
    var statusIcon: String? = "circle.fill"
    var canEndDriveManually: Bool = false
    var showsActionAffordance: Bool = true
    var statusAccessibilityLabel: String? = nil
    var statusAccessibilityHint: String? = nil
    var onEndDriveTap: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVE VEHICLE")
                    .font(AppTypography.micro())
                    .foregroundStyle(Color.appTextTertiary)
                    .tracking(0.7)
                Text(vehicleName)
                    .font(AppTypography.headline())
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Active vehicle \(vehicleName)")

            Spacer(minLength: AppSpacing.sm)
            sessionStatusBadge
        }
    }

    @ViewBuilder
    private var sessionStatusBadge: some View {
        let affordance = canEndDriveManually && showsActionAffordance
        let label = statusAccessibilityLabel ?? statusTitle
        if canEndDriveManually {
            Button {
                onEndDriveTap?()
            } label: {
                StatusBadge(
                    title: statusTitle,
                    icon: statusIcon,
                    style: statusStyle,
                    showsActionAffordance: affordance
                )
            }
            .buttonStyle(AppPressableButtonStyle())
            .accessibilityLabel(label)
            .accessibilityHint(statusAccessibilityHint ?? Self.endDriveAccessibilityHint)
            .accessibilityAddTraits(.isButton)
            .frame(minWidth: 44, minHeight: 44)
        } else {
            StatusBadge(
                title: statusTitle,
                icon: statusIcon,
                style: statusStyle,
                showsActionAffordance: false
            )
            .accessibilityLabel(label)
        }
    }

    static let endDriveAccessibilityHint = "Double tap to end the current drive."

    static func isEndDriveActionAvailable(canEndDriveManually: Bool) -> Bool {
        canEndDriveManually
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let title: String
    let value: String
    var symbol: String? = nil
    var showsDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.appAccentMuted)
                        .frame(width: 22)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(AppTypography.body())
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                Text(value)
                    .font(AppTypography.secondary())
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, AppSpacing.sm)
            if showsDivider {
                Divider().overlay(Color.appHairline)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.appSurfaceElevated)
                    .frame(width: 96, height: 96)
                    .shadow(color: AppShadow.subtle.color, radius: AppShadow.subtle.radius, y: AppShadow.subtle.y)
                Circle()
                    .strokeBorder(Color.appBorder, lineWidth: 0.5)
                    .frame(width: 96, height: 96)
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Color.appAccentMuted)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityHidden(true)

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(AppTypography.secondary())
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 240)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xl)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(Color(light: .white, dark: Color.appBackgroundSecondary))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                    .fill(isEnabled ? Color.appAccentMuted : Color.appSlate.opacity(0.45))
            }
        }
        .buttonStyle(AppPressableButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }
}

struct SecondaryButton: View {
    let title: String
    var symbol: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.appTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                    .fill(Color.appSurfaceInset)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 0.75)
            }
        }
        .buttonStyle(AppPressableButtonStyle())
        .accessibilityLabel(title)
    }
}

private struct AppPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(AppMotion.quick, value: configuration.isPressed)
    }
}

// MARK: - Vehicle Card

struct VehicleCard: View {
    let name: String
    let detail: String
    let dataSource: String
    var isActive: Bool = false
    var symbol: String = "car.side.fill"
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
                        .fill(isActive ? Color.appAccentMuted.opacity(0.18) : Color.appSurfaceInset)
                        .frame(width: 56, height: 56)
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isActive ? Color.appAccentMuted : Color.appTextSecondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(.headline)
                            .foregroundStyle(Color.appTextPrimary)
                            .lineLimit(1)
                        if isActive {
                            StatusBadge(title: "Active", icon: "checkmark", style: .success)
                        }
                    }
                    if !detail.isEmpty {
                        Text(detail)
                            .font(AppTypography.secondary())
                            .foregroundStyle(Color.appTextSecondary)
                            .lineLimit(1)
                    }
                    Text(dataSource)
                        .font(AppTypography.footnote())
                        .foregroundStyle(Color.appTextTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appTextTertiary)
                    .opacity(action == nil ? 0 : 1)
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
                    .strokeBorder(isActive ? Color.appAccentMuted.opacity(0.45) : Color.appBorder, lineWidth: isActive ? 1 : 0.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var accessibilityLabel: String {
        var parts = [name]
        if !detail.isEmpty { parts.append(detail) }
        parts.append(dataSource)
        if isActive { parts.append("Active") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Choice Row (onboarding / settings-style)

struct ChoiceRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
                        .fill(Color.appSurfaceInset)
                        .frame(width: 48, height: 48)
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.appAccentMuted)
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(AppTypography.footnote())
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: AppSpacing.xs)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appTextTertiary)
                    .accessibilityHidden(true)
            }
            .padding(AppSpacing.md)
            .background {
                RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                    .fill(Color.appSurface)
                    .shadow(color: AppShadow.subtle.color, radius: AppShadow.subtle.radius, y: AppShadow.subtle.y)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                    .strokeBorder(Color.appBorder, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

// MARK: - Performance Run Card

struct PerformanceRunCard: View {
    let title: String
    let subtitle: String
    let elapsedTime: String
    let elapsedUnit: String
    var topSpeed: String? = nil
    var topSpeedUnit: String? = nil
    var symbol: String = "gauge.with.needle"
    var statusTitle: String = "Ready"
    var statusStyle: StatusBadge.Style = .accent
    var delay: Double = 0

    /// Convenience for time-only runs.
    init(
        title: String,
        subtitle: String,
        value: String,
        unit: String,
        symbol: String = "gauge.with.needle",
        statusTitle: String = "Ready",
        statusStyle: StatusBadge.Style = .accent,
        delay: Double = 0
    ) {
        self.title = title
        self.subtitle = subtitle
        self.elapsedTime = value
        self.elapsedUnit = unit
        self.topSpeed = nil
        self.topSpeedUnit = nil
        self.symbol = symbol
        self.statusTitle = statusTitle
        self.statusStyle = statusStyle
        self.delay = delay
    }

    init(
        title: String,
        subtitle: String,
        elapsedTime: String,
        elapsedUnit: String,
        topSpeed: String? = nil,
        topSpeedUnit: String? = nil,
        symbol: String = "gauge.with.needle",
        statusTitle: String = "Ready",
        statusStyle: StatusBadge.Style = .accent,
        delay: Double = 0
    ) {
        self.title = title
        self.subtitle = subtitle
        self.elapsedTime = elapsedTime
        self.elapsedUnit = elapsedUnit
        self.topSpeed = topSpeed
        self.topSpeedUnit = topSpeedUnit
        self.symbol = symbol
        self.statusTitle = statusTitle
        self.statusStyle = statusStyle
        self.delay = delay
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.appAccentMuted)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                Spacer()
                StatusBadge(title: statusTitle, style: statusStyle)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                Text(subtitle)
                    .font(AppTypography.footnote())
                    .foregroundStyle(Color.appTextTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(elapsedTime)
                    .font(AppTypography.metric(topSpeed == nil ? 36 : 32))
                    .foregroundStyle(Color.appTextPrimary)
                    .monospacedDigit()
                Text(elapsedUnit)
                    .font(AppTypography.secondary())
                    .foregroundStyle(Color.appTextTertiary)
            }

            if let topSpeed, let topSpeedUnit {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOP SPEED")
                        .font(AppTypography.micro())
                        .foregroundStyle(Color.appTextTertiary)
                        .tracking(0.6)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(topSpeed)
                            .font(AppTypography.metric(24))
                            .foregroundStyle(Color.appAccentMuted)
                            .monospacedDigit()
                        Text(topSpeedUnit)
                            .font(AppTypography.footnote())
                            .foregroundStyle(Color.appTextTertiary)
                    }
                }
                .padding(.top, 2)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous)
                        .fill(Color.appSurfaceInset)
                }
            }
        }
        .appCard(padding: AppSpacing.lg, elevated: true)
        .appearAnimation(delay: delay)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = ["\(title), \(elapsedTime) \(elapsedUnit)"]
        if let topSpeed, let topSpeedUnit {
            parts.append("top speed \(topSpeed) \(topSpeedUnit)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Speed Band (digital motion visualization)

enum SpeedBandNormalizer {
    /// Maps a speed into 0...1 for band fill / marker position.
    static func progress(speed: Double, maximum: Double = 120) -> Double {
        guard maximum > 0 else { return 0 }
        return min(max(speed / maximum, 0), 1)
    }
}

struct SpeedBand: View {
    let speed: Double
    var maximum: Double = 120
    var tickCount: Int = 9

    private var progress: Double {
        SpeedBandNormalizer.progress(speed: speed, maximum: maximum)
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let markerX = width * progress

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.appSurfaceInset)
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(Color.appHairline, lineWidth: 0.5)
                        }

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.appAccentMuted.opacity(0.25),
                                    Color.appAccentMuted.opacity(0.75)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(markerX, 4))

                    HStack(spacing: 0) {
                        ForEach(0..<tickCount, id: \.self) { index in
                            Rectangle()
                                .fill(Color.appTextTertiary.opacity(index % 2 == 0 ? 0.45 : 0.22))
                                .frame(width: 1, height: index % 2 == 0 ? 10 : 6)
                            if index < tickCount - 1 {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal, 2)

                    Capsule(style: .continuous)
                        .fill(Color.appTextPrimary)
                        .frame(width: 3, height: 18)
                        .shadow(color: Color.appAccentMuted.opacity(0.35), radius: 4, y: 0)
                        .offset(x: max(markerX - 1.5, 0))
                }
            }
            .frame(height: 18)

            HStack {
                Text("0")
                Spacer()
                Text("\(Int(maximum / 2))")
                Spacer()
                Text("\(Int(maximum))")
            }
            .font(AppTypography.micro())
            .foregroundStyle(Color.appTextTertiary)
            .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Speed band")
        .accessibilityValue("\(Int(speed.rounded())) of \(Int(maximum))")
    }
}

// MARK: - Fuel Feature Card

struct FuelFeatureCard: View {
    let title: String
    let detail: String
    let value: String
    let symbol: String
    var delay: Double = 0

    var body: some View {
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

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Text(detail)
                    .font(AppTypography.footnote())
                    .foregroundStyle(Color.appTextSecondary)
            }

            Spacer(minLength: 0)

            Text(value)
                .font(AppTypography.metric(22))
                .foregroundStyle(Color.appTextPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .appCard()
        .appearAnimation(delay: delay)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value), \(detail)")
    }
}
