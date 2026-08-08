import SwiftUI
import PhotosUI

/// Cross-screen navigation intent — mirrors the web's
/// `<Link to="/challenges" search={{ tab: "badges" }} />` deep link.
@MainActor
final class NavIntent: ObservableObject {
    static let shared = NavIntent()
    @Published var challengesTab: ChallengesView.Tab = .goals
}

/// 1:1 port of `src/routes/profile.tsx`.
/// Hero (ProfileAura + avatar + name) → Today → Progress → Manage.
struct ProfileView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @ObservedObject var health = HealthKitService.shared
    @Binding var tab: AppTab

    @State private var earned: Set<String> = []
    @State private var photoItem: PhotosPickerItem?
    @State private var uploading = false
    @State private var showSettings = false
    @State private var showParent = false
    @State private var showStats = false

    private var stepsToday: Int { health.steps }
    private var isChild: Bool { settings.role == "child" }
    /// A linked child's picture is chosen by their parent and synced down.
    private var avatarLocked: Bool { settings.linkedChild }
    private var displayName: String {
        settings.displayName.isEmpty ? (settings.username.isEmpty ? "You" : settings.username) : settings.displayName
    }
    private var earnedMin: Int { settings.earnedMin(from: stepsToday) }

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(title: L.t("profile.title")) { EmptyView() }
            VStack(spacing: 24) {
                hero
                todaySection
                progressSection
                manageSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .task { earned = (try? await SupabaseAPI.earnedBadges()) ?? [] }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await handlePick(item) }
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(tab: $tab).environmentObject(theme).environmentObject(settings)
        }
        .fullScreenCover(isPresented: $showParent) {
            ParentView(tab: $tab).environmentObject(theme).environmentObject(settings)
        }
        .fullScreenCover(isPresented: $showStats) {
            StatsView(tab: $tab).environmentObject(theme).environmentObject(settings)
        }
    }

    // MARK: Hero — `rounded-[28px] bg-card p-6 ring-1 ring-black/5`

    private var hero: some View {
        ZStack {
            ProfileAura(
                activity: Double(stepsToday) / Double(max(1, settings.dailyGoal)),
                screen: Double(earnedMin) / Double(max(1, (settings.hasCap ? settings.dailyCapHours : 3) * 60))
            )
            VStack(spacing: 12) {
                avatarButton
                VStack(spacing: 2) {
                    Text(displayName).font(F.sans(18, .semibold)).foregroundStyle(theme.foreground)
                    Text("@\(settings.username)").font(F.xs).foregroundStyle(theme.p.s600)
                }
                if avatarLocked {
                    Text(L.t("profile.photo_parent_managed"))
                        .font(F.text11).foregroundStyle(theme.p.s600).padding(.top, 4)
                } else {
                    HStack(spacing: 8) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text(L.t("profile.change_photo"))
                                .font(F.sans(11, .semibold))
                                .foregroundStyle(theme.primaryForeground)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(theme.p.s700, in: Capsule())
                        }
                        if settings.avatar?.isEmpty == false {
                            Button {
                                Task { await save(avatar: nil) }
                            } label: {
                                Image(systemName: "trash").font(.system(size: 13))
                                    .foregroundStyle(theme.p.s700)
                                    .frame(width: 32, height: 32)
                                    .background(theme.p.s100, in: Circle())
                            }
                            .accessibilityLabel(L.t("profile.remove_photo"))
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
            .strokeBorder(theme.ringBorder, lineWidth: 1))
        .rise()
    }

    private var avatarButton: some View {
        ZStack {
            AvatarBubble(avatar: settings.avatar, name: displayName, size: 96)
            if uploading {
                Circle().fill(Color.black.opacity(0.3))
                    .overlay(ProgressView().tint(.white))
                    .frame(width: 96, height: 96)
            }
        }
        .overlay(Circle().strokeBorder(theme.card, lineWidth: 4))
        .shadow(color: theme.p.s950.opacity(0.10), radius: 12, x: 0, y: 8)
    }

    // MARK: Today

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(L.t("profile.section.today"))

            HStack(spacing: 12) {
                mini(label: L.t("profile.mini.steps"), value: stepsToday.formatted(.number.grouping(.automatic)))
                mini(label: L.t("profile.mini.earned"), value: SettingsStore.formatScreenMin(earnedMin))
            }

            CardSurface(radius: R.xl3, padding: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                                .fill(settings.streakCount > 0 ? Color(hex: "#FFEDD5") : theme.p.s100)
                            Image(systemName: "flame.fill").font(.system(size: 22))
                                .foregroundStyle(settings.streakCount > 0 ? Color(hex: "#EA580C") : theme.p.s600)
                        }
                        .frame(width: 56, height: 56)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t("profile.streak.title")).eyebrow(theme.p.s600)
                            Text("\(settings.streakCount)")
                                .font(F.sans(24, .semibold)).tabularNums()
                                .foregroundStyle(theme.foreground)
                            Text(streakLabel).font(F.xs).foregroundStyle(theme.p.s600)
                        }
                        Spacer()
                        Text(L.t("profile.streak.best", ["n": "\(settings.streakBest)"]))
                            .eyebrow(theme.p.s600)
                            .multilineTextAlignment(.trailing)
                    }

                    Text(statusText)
                        .font(F.xs)
                        .foregroundStyle(statusColors.fg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(statusColors.bg, in: RoundedRectangle(cornerRadius: R.sm, style: .continuous))
                }
            }
        }
        .rise(delay: 0.06)
    }

    private var streakLabel: String {
        switch settings.streakCount {
        case 0: return L.t("profile.streak.zero")
        case 1: return L.t("profile.streak.day")
        default: return L.t("profile.streak.days", ["n": "\(settings.streakCount)"])
        }
    }

    private var statusText: String {
        if settings.goalMetToday { return L.t("profile.streak.active") }
        return settings.streakCount > 0 ? L.t("profile.streak.at_risk") : L.t("profile.streak.zero")
    }

    private var statusColors: (bg: Color, fg: Color) {
        if settings.goalMetToday { return (theme.p.s100, theme.p.s700) }
        if settings.streakCount > 0 { return (Color(hex: "#FFFBEB"), Color(hex: "#B45309")) }
        return (theme.p.s50, theme.p.s600)
    }

    // MARK: Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(L.t("profile.section.progress"))
            ProfileBadgeStrip(earned: earned) {
                NavIntent.shared.challengesTab = .badges
                tab = .challenges
            }
            FriendsCard()
        }
        .rise(delay: 0.12)
    }

    // MARK: Manage

    private var manageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(L.t("profile.section.manage"))
            VStack(spacing: 0) {
                row("chart.bar", L.t("profile.row.stats"), L.t("profile.row.stats_sub")) { showStats = true }
                if !isChild {
                    divider
                    row("shield", L.t("profile.row.screentime"), L.t("profile.row.screentime_sub")) { showParent = true }
                    divider
                    row("person.2", L.t("profile.row.children"), L.t("profile.row.children_sub")) { showParent = true }
                }
                divider
                row("gearshape", L.t("profile.row.settings"), L.t("profile.row.settings_sub")) { showSettings = true }
            }
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                .strokeBorder(theme.ringBorder, lineWidth: 1))
        }
        .rise(delay: 0.18)
    }

    private var divider: some View { Rectangle().fill(Color.black.opacity(0.05)).frame(height: 1) }

    private func row(_ icon: String, _ label: String, _ subtitle: String,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: R.sm, style: .continuous).fill(theme.p.s100)
                    Image(systemName: icon).font(.system(size: 14)).foregroundStyle(theme.p.s700)
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(F.sans(14, .semibold)).foregroundStyle(theme.foreground)
                    Text(subtitle).font(F.xs).foregroundStyle(theme.p.s600)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(theme.p.s600)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s)
            .font(F.sans(11, .semibold))
            .textCase(.uppercase)
            .tracking(1.3)                    // tracking-[0.12em]
            .foregroundStyle(theme.p.s600)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mini(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(F.sans(18, .semibold)).tabularNums().foregroundStyle(theme.foreground)
            Text(label).eyebrow(theme.p.s600)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
            .strokeBorder(theme.ringBorder, lineWidth: 1))
    }

    // MARK: Avatar upload — square-crop + compress, stored inline like the web.

    private func handlePick(_ item: PhotosPickerItem) async {
        uploading = true
        defer { uploading = false; photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let dataURL = Self.squareDataURL(image) else { return }
        await save(avatar: dataURL)
    }

    private func save(avatar: String?) async {
        settings.avatar = avatar
        try? await SupabaseAPI.updateProfile(["avatar_url": avatar.map { AnyJSON.string($0) } ?? .null])
    }

    /// Port of `src/lib/avatar.ts` — center-crop to 256px, JPEG q0.82, data URL.
    static func squareDataURL(_ image: UIImage, size: CGFloat = 256) -> String? {
        let side = min(image.size.width, image.size.height)
        let rect = CGRect(x: (image.size.width - side) / 2, y: (image.size.height - side) / 2,
                          width: side, height: side)
        guard let cg = image.cgImage?.cropping(to: rect) else { return nil }
        let cropped = UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let scaled = renderer.image { _ in
            cropped.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        guard let jpeg = scaled.jpegData(compressionQuality: 0.82) else { return nil }
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }
}

/// Port of `src/components/ProfileAura.tsx` — living gradient behind the hero.
/// Blobs shift with time of day, activity and screen-time usage, always using
/// the active theme scale so it follows the user's chosen color.
struct ProfileAura: View {
    @EnvironmentObject var theme: Theme
    let activity: Double
    let screen: Double

    private var dayProgress: Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double((c.hour ?? 0) * 60 + (c.minute ?? 0)) / 1440
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let a = min(1, max(0, activity)), s = min(1, max(0, screen))
            let deep = 0.35 + a * 0.45
            let soft = 0.30 + s * 0.35
            let light = 0.45 + (1 - dayProgress) * 0.30
            let x = dayProgress * 100

            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [theme.p.s100, theme.p.s200],
                               startPoint: .topLeading, endPoint: .bottomTrailing)

                blob(theme.p.s500.opacity(deep),
                     w: w * (0.55 + a * 0.35), h: h * 1.5,
                     x: w * (-0.15 + x * 0.004), y: -h * 0.35)

                blob(theme.p.s700.opacity(soft),
                     w: w * (0.50 + s * 0.35), h: h * 1.4,
                     x: w - w * (0.50 + s * 0.35) - w * (-0.20 + (1 - dayProgress) * 0.25),
                     y: h - h * 1.4 + h * 0.40)

                blob(theme.p.s300.opacity(light),
                     w: w * (0.45 + a * 0.25), h: h * 1.2,
                     x: w * (0.25 + sin(dayProgress * .pi) * 0.20), y: -h * 0.25)

                LinearGradient(colors: [theme.card.opacity(0.10), theme.card.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .allowsHitTesting(false)
    }

    private func blob(_ color: Color, w: CGFloat, h: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Ellipse()
            .fill(RadialGradient(colors: [color, color.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: max(w, h) * 0.35))
            .frame(width: w, height: h)
            .offset(x: x, y: y)
    }
}
