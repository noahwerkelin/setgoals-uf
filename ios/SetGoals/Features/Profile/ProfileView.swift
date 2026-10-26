import SwiftUI
import PhotosUI
import Supabase

/// Cross-screen navigation intent — mirrors the web's
/// `<Link to="/challenges" search={{ tab: "badges" }} />` deep link.
final class NavIntent {
    static let shared = NavIntent()
    var challengesTab: ChallengesView.Tab = .goals

    /// Reads the pending tab once, then falls back to the default.
    func consumeChallengesTab() -> ChallengesView.Tab {
        defer { challengesTab = .goals }
        return challengesTab
    }


}


/// Native personal dashboard: profile identity followed by cached statistics.
struct ProfileView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @ObservedObject var health = HealthKitService.shared
    @Binding var tab: AppTab

    @State private var photoItem: PhotosPickerItem?
    @State private var uploading = false
    @State private var showSettings = false

    private var stepsToday: Int { health.steps }
    private var isChild: Bool { settings.role == "child" }
    /// A linked child's picture is chosen by their parent and synced down.
    private var avatarLocked: Bool { settings.linkedChild }
    private var displayName: String {
        settings.displayName.isEmpty ? (settings.username.isEmpty ? L.t("dashboard.you") : settings.username) : settings.displayName
    }
    private var earnedMin: Int { settings.earnedMin(from: stepsToday) }

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(title: L.t("profile.title")) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape").font(.system(size: 18, weight: .medium))
                        .foregroundStyle(theme.primary)
                        .frame(width: 44, height: 44)
                        .background(theme.secondary, in: Circle())
                }
                .buttonStyle(FlatPress())
                .accessibilityLabel(L.t("profile.settings"))
            }
            VStack(spacing: 24) {
                hero
                StatsView(tab: $tab, embedded: true)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await handlePick(item) }
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(tab: $tab).environmentObject(theme).environmentObject(settings)
        }
    }

    // MARK: Hero — `rounded-[28px] bg-card p-6 ring-1 ring-black/5`

    private var hero: some View {
        ZStack {
            LinearGradient(colors: [theme.secondary, theme.accent, theme.card],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 12) {
                if avatarLocked {
                    avatarButton
                } else {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        avatarButton.overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil").font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.primaryForeground)
                                .frame(width: 32, height: 32).background(theme.primary, in: Circle())
                        }
                    }
                    .buttonStyle(FlatPress())
                    .accessibilityLabel(L.t("profile.change_photo"))
                    .disabled(uploading)
                }
                VStack(spacing: 2) {
                    Text(displayName).font(F.xl2).foregroundStyle(theme.foreground)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    Text("@\(settings.username)").font(F.sm).foregroundStyle(theme.mutedForeground)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    if settings.isPro {
                        Label(L.t("pro.badge"), systemImage: "crown.fill")
                            .font(F.sans(11, .semibold)).foregroundStyle(theme.primary)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(theme.card.opacity(0.8), in: Capsule())
                            .padding(.top, 6)
                    }
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
            AvatarBubble(avatar: settings.avatar, name: displayName, size: 112)
            if uploading {
                Circle().fill(theme.foreground.opacity(0.3))
                    .overlay(ProgressView().tint(theme.primaryForeground))
                    .frame(width: 112, height: 112)
            }
        }
        .overlay(Circle().strokeBorder(theme.card, lineWidth: 4))
        .shadow(color: theme.p.s950.opacity(0.10), radius: 12, x: 0, y: 8)
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
