import SwiftUI

/// Port of `src/routes/profile.tsx` — Today / Progress / Manage sections,
/// with the animated `ProfileAura` header.
struct ProfileView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @ObservedObject var health = HealthKitService.shared
    @Binding var tab: AppTab

    @State private var streak: StreakRow?
    @State private var showPhotoPicker = false

    private var earned: Int { settings.earnedMin(from: health.steps) + settings.bonusMin }

    var body: some View {
        AppShell(tab: $tab) {
            auraHeader
            VStack(spacing: 24) {
                todaySection
                progressSection
                manageSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .task { streak = try? await SupabaseAPI.streak() }
    }

    private var auraHeader: some View {
        ZStack(alignment: .bottomLeading) {
            ProfileAura(progress: min(1, Double(health.steps) / Double(max(settings.dailyGoal, 1))))
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: R.xl3, style: .continuous))

            HStack(spacing: 12) {
                Button { showPhotoPicker = true } label: {
                    AvatarBubble(avatar: settings.avatar, name: settings.displayName, size: 64)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.displayName).font(F.sans(20, .semibold)).foregroundStyle(theme.p.s950)
                    Text("@\(settings.username)").font(F.xs).foregroundStyle(theme.p.s700)
                }
            }
            .padding(20)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .rise()
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t("profile.today")).eyebrow(theme.p.s600)
            HStack(spacing: 16) {
                StatTile(systemImage: "figure.walk", label: L.t("profile.steps"),
                         value: health.steps.formatted(), unit: "")
                StatTile(systemImage: "hourglass", label: L.t("profile.earned"),
                         value: SettingsStore.formatScreenMin(earned), unit: "")
            }
        }
        .rise(delay: 0.06)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t("profile.progress")).eyebrow(theme.p.s600)
            CardSurface {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: R.xl2, style: .continuous).fill(theme.p.s100)
                        Image(systemName: "flame.fill").foregroundStyle(theme.p.s700)
                    }
                    .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("profile.streak")).eyebrow(theme.p.s600)
                        Text(L.t("profile.streak_days", ["n": "\(streak?.count ?? 0)"]))
                            .font(F.sans(14, .medium)).foregroundStyle(theme.p.s900)
                    }
                    Spacer()
                    Text(L.t("profile.best", ["n": "\(streak?.best ?? 0)"]))
                        .font(F.xs).foregroundStyle(theme.p.s600)
                }
            }
        }
        .rise(delay: 0.12)
    }

    @State private var showSettings = false
    @State private var showParent = false
    @State private var showStats = false

    private var manageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t("profile.manage")).eyebrow(theme.p.s600)
            CardSurface(padding: 8) {
                VStack(spacing: 0) {
                    row("gearshape", L.t("profile.settings")) { showSettings = true }
                    Divider().overlay(theme.p.s100)
                    row("chart.bar", L.t("stats.title")) { showStats = true }
                    Divider().overlay(theme.p.s100)
                    row("figure.2.and.child.holdinghands", L.t("parent.title")) { showParent = true }
                    Divider().overlay(theme.p.s100)
                    row("trophy", L.t("profile.badges")) { tab = .challenges }
                    Divider().overlay(theme.p.s100)
                    row("rectangle.portrait.and.arrow.right", L.t("profile.sign_out")) {
                        Task { await AuthStore.shared.signOut() }
                    }
                }
            }
        }
        .rise(delay: 0.18)
        .fullScreenCover(isPresented: $showSettings) { SettingsView(tab: $tab).environmentObject(theme).environmentObject(settings) }
        .fullScreenCover(isPresented: $showParent) { ParentView(tab: $tab).environmentObject(theme).environmentObject(settings) }
        .fullScreenCover(isPresented: $showStats) { StatsView(tab: $tab).environmentObject(theme).environmentObject(settings) }
    }


    private func row(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 20).foregroundStyle(theme.p.s700)
                Text(title).font(F.sm).foregroundStyle(theme.p.s900)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(theme.p.s600)
            }
            .padding(.horizontal, 12).padding(.vertical, 14)
        }
    }
}

/// Port of `src/components/ProfileAura.tsx` — three blurred blobs of the
/// active theme color drifting into each other (18s / 24s / 21s loops).
struct ProfileAura: View {
    @EnvironmentObject var theme: Theme
    let progress: Double
    @State private var animate = false

    var body: some View {
        ZStack {
            theme.p.s100
            blob(theme.p.s300, size: 220, offset: CGSize(width: -60, height: -30),
                 drift: CGSize(width: 30, height: 22), scale: 1.18, duration: 18)
            blob(theme.p.s500.opacity(0.75), size: 200, offset: CGSize(width: 70, height: 20),
                 drift: CGSize(width: -34, height: -26), scale: 0.92, duration: 24)
            blob(theme.p.s600.opacity(0.55 + 0.35 * progress), size: 180,
                 offset: CGSize(width: 10, height: 60),
                 drift: CGSize(width: 22, height: -30), scale: 1.25, duration: 21)
        }
        .compositingGroup()
        .onAppear { animate = true }
    }

    private func blob(_ color: Color, size: CGFloat, offset: CGSize, drift: CGSize,
                      scale: CGFloat, duration: Double) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 30)
            .offset(x: offset.width + (animate ? drift.width : 0),
                    y: offset.height + (animate ? drift.height : 0))
            .scaleEffect(animate ? scale : 1)
            .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true), value: animate)
    }
}
