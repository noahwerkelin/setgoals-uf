import SwiftUI
import CoreLocation

/// 1:1 port of `src/routes/onboarding.tsx` — the intro slides plus the
/// permission screen that asks for Apple Health and then Location.
/// Shown once, before auth, on the very first launch.
struct OnboardingView: View {
    @EnvironmentObject var theme: Theme
    var onDone: () -> Void

    private enum PermState { case idle, busy, granted, unavailable }
    private enum Screen { case intro, perm }

    @State private var screen: Screen = .intro
    @State private var health: PermState = .idle
    @State private var location: PermState = .idle
    @StateObject private var locator = OnboardingLocator()

    private let steps: [(String, String)] = [
        ("shoeprints.fill", "s1"), ("shield.fill", "s2"), ("sparkles", "s3"),
    ]

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    if screen == .intro { intro } else { permissions }
                }
                footer
            }
            .frame(maxWidth: 448)
            .padding(.horizontal, 24)
            .padding(.top, 64)
            .padding(.bottom, 40)
        }
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 12) {
                brandChip
                Text(L.t("onb.headline"))
                    .font(F.sans(34, .semibold)).foregroundStyle(theme.p.s950)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L.t("onb.sub")).font(F.sm).foregroundStyle(theme.p.s600)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .rise()

            VStack(spacing: 16) {
                ForEach(Array(steps.enumerated()), id: \.element.1) { i, s in
                    HStack(alignment: .top, spacing: 16) {
                        iconChip(s.0)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t("onb.\(s.1).title")).font(F.sans(14, .semibold))
                                .foregroundStyle(theme.foreground)
                            Text(L.t("onb.\(s.1).desc")).font(F.xs).foregroundStyle(theme.p.s600)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(20)
                    .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                        .strokeBorder(theme.ringBorder, lineWidth: 1))
                    .rise(delay: 0.1 + Double(i) * 0.08)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Permissions

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                brandChip
                Text(L.t("onb.perm.title"))
                    .font(F.sans(28, .semibold)).foregroundStyle(theme.p.s950)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L.t("onb.perm.sub")).font(F.sm).foregroundStyle(theme.p.s600)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .rise()

            VStack(spacing: 16) {
                permCard(icon: "heart.text.square.fill",
                         title: L.t("onb.perm.health"),
                         desc: L.t("onb.perm.health_desc"),
                         state: health,
                         note: nil) {
                    Task {
                        health = .busy
                        await HealthKitService.shared.requestAuthorization()
                        guard HealthKitService.shared.isAvailable else { health = .unavailable; return }
                        health = HealthKitService.shared.authorized ? .granted : .idle
                        if health == .granted {
                            SettingsStore.shared.healthkitConnected = true
                            try? await SupabaseAPI.updateSettings(["healthkit_connected": .bool(true)])
                        }
                    }
                }
                permCard(icon: "mappin.and.ellipse",
                         title: L.t("onb.perm.location"),
                         desc: L.t("onb.perm.location_desc"),
                         state: location,
                         note: nil) {
                    location = .busy
                    locator.request()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: locator.status) { _, s in
            switch s {
            case .authorizedWhenInUse, .authorizedAlways: location = .granted
            case .denied, .restricted: location = .idle
            default: break
            }
        }
    }

    private func permCard(icon: String, title: String, desc: String, state: PermState,
                          note: String?, action: @escaping () -> Void) -> some View {
        let granted = state == .granted
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                iconChip(icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(F.sans(14, .semibold)).foregroundStyle(theme.foreground)
                    Text(desc).font(F.xs).foregroundStyle(theme.p.s600)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button(action: action) {
                    HStack(spacing: 4) {
                        if granted { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                        Text(granted ? L.t("onb.perm.allowed")
                             : state == .unavailable ? L.t("onb.perm.unavailable") : L.t("onb.perm.allow"))
                            .font(F.sans(12, .semibold))
                    }
                    .foregroundStyle(granted ? theme.p.s700 : theme.primaryForeground)
                    .padding(.horizontal, 12).frame(height: 36)
                    .background(granted ? theme.p.s100 : theme.p.s600, in: Capsule())
                    .opacity(state == .busy ? 0.6 : 1)
                }
                .disabled(granted || state == .busy || state == .unavailable)
            }
            if let note {
                Text(note).font(F.xs).foregroundStyle(theme.p.s600)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
            }
        }
        .padding(20)
        .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
            .strokeBorder(theme.ringBorder, lineWidth: 1))
        .rise(delay: 0.08)
    }

    // MARK: Chrome

    private var brandChip: some View {
        Text(L.t("onb.brand"))
            .font(F.sans(10, .semibold)).textCase(.uppercase).tracking(1.6)
            .foregroundStyle(theme.p.s700)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(theme.p.s100, in: Capsule())
    }

    private func iconChip(_ system: String) -> some View {
        Image(systemName: system).font(.system(size: 18))
            .foregroundStyle(theme.p.s700)
            .frame(width: 44, height: 44)
            .background(theme.p.s100, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                if screen == .intro { withAnimation(.easeOut(duration: 0.25)) { screen = .perm } }
                else { onDone() }
            } label: {
                Text(screen == .intro ? L.t("onb.cta") : L.t("onb.perm.continue"))
                    .font(F.sans(14, .semibold))
                    .foregroundStyle(theme.primaryForeground)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(theme.p.s600, in: Capsule())
            }
            Button { onDone() } label: {
                Text(screen == .intro ? L.t("onb.skip") : L.t("onb.perm.later"))
                    .font(F.sans(12, .medium)).foregroundStyle(theme.p.s600)
            }
        }
        .padding(.top, 32)
    }
}

/// Minimal location permission prompt used by onboarding.
@MainActor
final class OnboardingLocator: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status: CLAuthorizationStatus = .notDetermined
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        status = manager.authorizationStatus
    }

    func request() {
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let s = m.authorizationStatus
        Task { @MainActor in self.status = s }
    }
}
