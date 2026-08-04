import SwiftUI

/// Port of `src/routes/index.tsx` (Today).
struct HomeView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @ObservedObject var health = HealthKitService.shared
    @Binding var tab: AppTab

    @State private var family: [FamilyMember] = []
    @State private var friendsRank: Int? = nil

    private var goal: Int { settings.dailyGoal > 0 ? settings.dailyGoal : 8000 }
    private var steps: Int { health.steps }
    private var baseEarned: Int { settings.earnedMin(from: steps) }
    private var earnedMin: Int { baseEarned + settings.bonusMin }
    private var remainingMin: Int { max(0, settings.capMin - baseEarned) }
    private var ringProgress: Double { min(1, Double(steps) / Double(goal)) }

    var body: some View {
        AppShell(tab: $tab) {
            header
            VStack(spacing: 24) {
                ringCard
                statsRow
                QuoteCard()
                FamilyCard(members: family)
                LeaderboardTile(rank: friendsRank)
            }
            .padding(.horizontal, 24)
        }
        .task {
            await settings.load()
            await health.requestAuthorization()
            family = (try? await SupabaseAPI.familyToday()) ?? []
            let friends = (try? await SupabaseAPI.leaderboard(scope: "friends")) ?? []
            if let me = await SupabaseAPI.currentUserID() {
                friendsRank = friends.first(where: { $0.user_id == me })?.rank
            }
            ScreenTimeService.shared.apply(remainingMin: remainingMin)
        }
        .onChange(of: remainingMin) { _, new in
            ScreenTimeService.shared.apply(remainingMin: new)
        }
    }

    private var header: some View {
        PageHeader(eyebrow: Self.dateLine(), title: "\(L.greeting()), \(settings.displayName)") {
            Button { tab = .profile } label: { AvatarBubble(avatar: settings.avatar, name: settings.displayName, size: 40) }
        }
        .rise()
    }

    private var ringCard: some View {
        CardSurface(radius: 28, padding: 32) {
            VStack(spacing: 24) {
                ProgressRing(progress: ringProgress) {
                    VStack(spacing: 4) {
                        Text(steps.formatted())
                            .font(F.sans(36, .semibold)).tabularNums()
                        Text(L.t("home.steps_of", ["goal": goal.formatted()]))
                            .font(F.sans(14, .medium)).foregroundStyle(theme.p.s600)
                    }
                }
                HStack(spacing: 0) {
                    metric(L.t("home.earned"), SettingsStore.formatScreenMin(earnedMin), theme.foreground)
                    Rectangle().fill(theme.p.s950.opacity(0.05)).frame(width: 1)
                    metric(L.t("home.remaining"), SettingsStore.formatScreenMin(remainingMin), theme.p.s600)
                }
                if settings.bonusMin > 0 {
                    Text(L.t("home.bonus_gift", ["m": SettingsStore.formatScreenMin(settings.bonusMin)]))
                        .font(F.sans(11, .semibold))
                        .foregroundStyle(theme.p.s700)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(theme.p.s100, in: Capsule())
                        .overlay(Capsule().strokeBorder(theme.p.s200, lineWidth: 1))
                        .padding(.top, -8)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .rise(delay: 0.06)
    }

    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).eyebrow(theme.p.s600)
            Text(value).font(F.sans(18, .medium)).tabularNums().foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var statsRow: some View {
        let d = settings.formatDistance(health.distanceKm)
        return HStack(spacing: 16) {
            if settings.role != "child" {
                StatTile(systemImage: "flame", label: L.t("home.energy"), value: "\(health.calories)", unit: "kcal")
            }
            StatTile(systemImage: "figure.walk", label: L.t("home.distance"), value: d.0, unit: d.1)
        }
        .rise(delay: 0.12)
    }

    static func dateLine() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: L.lang == "sv" ? "sv_SE" : "en_US")
        f.setLocalizedDateFormatFromTemplate("EEEE MMM d")
        return f.string(from: Date()).prefix(1).uppercased() + f.string(from: Date()).dropFirst()
    }
}

struct AvatarBubble: View {
    @EnvironmentObject var theme: Theme
    let avatar: String?
    let name: String
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let a = avatar, a.hasPrefix("http") || a.hasPrefix("data:") {
                AsyncImage(url: URL(string: a)) { $0.resizable().scaledToFill() } placeholder: { theme.p.s200 }
            } else if let a = avatar, !a.isEmpty {
                Text(a).font(.system(size: size * 0.45))
            } else {
                Text(Self.initials(name))
                    .font(F.sans(10, .semibold)).tracking(1)
                    .foregroundStyle(theme.p.s700)
            }
        }
        .frame(width: size, height: size)
        .background(theme.p.s200)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(theme.ringBorder, lineWidth: 1))
    }

    static func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

struct QuoteCard: View {
    @EnvironmentObject var theme: Theme
    var body: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("home.quote_eyebrow")).eyebrow(theme.p.s600)
                Text(L.quoteOfTheDay()).font(F.sm).foregroundStyle(theme.p.s900)
            }
        }
        .rise(delay: 0.18)
    }
}

struct FamilyCard: View {
    @EnvironmentObject var theme: Theme
    let members: [FamilyMember]

    var body: some View {
        if !members.isEmpty {
            CardSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L.t("home.family")).font(F.sans(14, .semibold))
                    ForEach(members) { m in
                        HStack(spacing: 12) {
                            AvatarBubble(avatar: m.avatar, name: m.name, size: 36)
                            Text(m.name).font(F.sm).foregroundStyle(theme.p.s900)
                            Spacer()
                            Text(m.steps.formatted())
                                .font(F.sans(14, .medium)).tabularNums()
                                .foregroundStyle(theme.p.s700)
                        }
                    }
                }
            }
            .rise(delay: 0.24)
        }
    }
}

struct LeaderboardTile: View {
    @EnvironmentObject var theme: Theme
    let rank: Int?

    var body: some View {
        CardSurface {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: R.xl2, style: .continuous).fill(theme.p.s600)
                    Image(systemName: "trophy").foregroundStyle(theme.primaryForeground)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("home.leaderboard")).eyebrow(theme.p.s700)
                    Text(rank.map { L.t("home.friends_rank", ["n": "\($0)"]) } ?? L.t("home.no_friends"))
                        .font(F.sans(14, .medium)).foregroundStyle(theme.p.s900)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(theme.p.s600)
            }
        }
        .rise(delay: 0.3)
    }
}
