import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @Environment(\.modelContext) private var modelContext

    @State private var step = 0
    @State private var notice: String?
    @State private var appear = false

    private let totalSteps = 2

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            RadialGradient(
                colors: [Color.appNavy.opacity(0.55), Color.clear],
                center: .top,
                startRadius: 40,
                endRadius: 480
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Color.appAccentMuted.opacity(0.08), Color.clear],
                center: .bottom,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)

                TabView(selection: $step) {
                    welcomePage.tag(0)
                    setupPage.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(AppMotion.standard, value: step)

                bottomChrome
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)
            }
        }
        .tint(Color.appAccent)
        .onAppear {
            withAnimation(AppMotion.appear) { appear = true }
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appAccentMuted)
                Text("UDC")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.appTextPrimary)
                    .tracking(1.5)
            }
            Spacer()
            Button("Skip") {
                isComplete = true
            }
            .font(AppTypography.label())
            .foregroundStyle(Color.appTextSecondary)
            .accessibilityLabel("Skip onboarding")
        }
    }

    private var welcomePage: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                Spacer(minLength: AppSpacing.lg)

                ZStack {
                    Circle()
                        .fill(Color.appSurfaceElevated)
                        .frame(width: 140, height: 140)
                        .shadow(color: AppShadow.elevated.color, radius: 28, y: 14)
                    Circle()
                        .strokeBorder(Color.appBorder, lineWidth: 0.5)
                        .frame(width: 140, height: 140)
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 52, weight: .ultraLight))
                        .foregroundStyle(Color.appAccentMuted)
                        .symbolRenderingMode(.hierarchical)
                        .offset(y: 2)
                }
                .scaleEffect(appear ? 1 : 0.92)
                .opacity(appear ? 1 : 0)
                .accessibilityHidden(true)

                VStack(spacing: AppSpacing.sm) {
                    Text("Drive with clarity")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.appTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("A premium companion for every car—GPS, OBD-II, or classic driveline. Private by design.")
                        .font(AppTypography.secondary())
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 10)

                VStack(spacing: AppSpacing.md) {
                    featurePill(symbol: "location.fill", title: "Works with every vehicle")
                    featurePill(symbol: "lock.fill", title: "On-device by default")
                    featurePill(symbol: "gauge.with.needle", title: "Instrument-grade metrics")
                }
                .padding(.top, AppSpacing.sm)

                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private var setupPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Choose your start")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.appTextPrimary)
                    Text("Pick the connection approach that fits this vehicle. You can change it anytime in Garage.")
                        .font(AppTypography.secondary())
                        .foregroundStyle(Color.appTextSecondary)
                }
                .padding(.top, AppSpacing.md)

                VStack(spacing: AppSpacing.md) {
                    ChoiceRow(
                        title: "Use GPS only",
                        subtitle: "Speed and trips from location—ready for any car.",
                        symbol: "location.fill"
                    ) {
                        finish(mode: .gpsOnly, name: "My Vehicle")
                    }

                    ChoiceRow(
                        title: "Connect an OBD-II adapter",
                        subtitle: "Live engine data when hardware is available.",
                        symbol: "cable.connector"
                    ) {
                        withAnimation(AppMotion.quick) {
                            notice = "OBD-II adapter support will arrive during development."
                        }
                    }

                    ChoiceRow(
                        title: "Classic or non-OBD vehicle",
                        subtitle: "Estimate RPM from tire, axle, and gear ratios.",
                        symbol: "wrench.and.screwdriver.fill"
                    ) {
                        finish(mode: .manualDriveline, name: "My Classic")
                    }

                    ChoiceRow(
                        title: "Decide later",
                        subtitle: "Jump into the cabin and configure when ready.",
                        symbol: "arrow.right.circle.fill"
                    ) {
                        isComplete = true
                    }
                }

                if let notice {
                    Text(notice)
                        .font(AppTypography.footnote())
                        .foregroundStyle(Color.appTextSecondary)
                        .padding(.horizontal, 4)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .accessibilityLabel(notice)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    private var bottomChrome: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Color.appAccentMuted : Color.appHairline)
                        .frame(width: index == step ? 22 : 8, height: 6)
                        .animation(AppMotion.emphasize, value: step)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(step + 1) of \(totalSteps)")

            if step == 0 {
                PrimaryButton(title: "Continue", symbol: "arrow.right") {
                    withAnimation(AppMotion.standard) { step = 1 }
                }
            } else {
                SecondaryButton(title: "Back") {
                    withAnimation(AppMotion.standard) { step = 0 }
                }
            }
        }
    }

    private func featurePill(symbol: String, title: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appAccentMuted)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(title)
                .font(AppTypography.secondary())
                .foregroundStyle(Color.appTextPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .fill(Color.appSurface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .strokeBorder(Color.appBorder, lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    private func finish(mode: VehicleDataSourceMode, name: String) {
        modelContext.insert(VehicleProfile(name: name, dataSourceMode: mode))
        isComplete = true
    }
}

#Preview {
    OnboardingView(isComplete: .constant(false))
        .modelContainer(for: VehicleProfile.self, inMemory: true)
        .preferredColorScheme(.dark)
}
