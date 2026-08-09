import SwiftUI

/// 1:1 port of `src/routes/index.tsx` (Today).
struct HomeView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @ObservedObject var health = HealthKitService.shared
    @Binding var tab: AppTab

    @AppStorage("st.rollover") private var rolloverEnabled = false

    @State private var family: [FamilyMember] = []
    @State private var friendsRank: Int = 0
    @State private var friendsTotal: Int = 0
    @State private var earnedBadges: [String] = []
    @State private var yesterdaySteps = 0

    private var goal: Int { settings.dailyGoal > 0 ? settings.dailyGoal : 8000 }
    private var steps: Int { health.steps }
    private var capMin: Int { settings.hasCap ? settings.dailyCapHours * 60 : 24 * 60 }
    private var rolloverMin: Int {
        guard settings.isPro, rolloverEnabled, settings.hasCap else { return 0 }
        let usedYesterday = min(capMin, settings.earnedMin(from: yesterdaySteps))
        return max(0, capMin - usedYesterday)
    }
    private var baseEarned: Int { settings.earnedMin(from: steps) }
    private var earnedMin: Int { min(capMin + rolloverMin, baseEarned + rolloverMin) + settings.bonusMin }
    private var remainingMin: Int {
        max(0, capMin + rolloverMin - min(capMin + rolloverMin, baseEarned + rolloverMin))
    }
    private var ringProgress: Double { min(1, Double(steps) / Double(max(goal, 1))) }

    var body: some View {
        AppShell(tab: $tab) {
            header
            VStack(spacing: 24) {
                ringCard
                statsRow
                if settings.role != "child" && settings.isPro && rolloverMin > 0 { rolloverCard }
                quoteCard
                RecentWins(earned: earnedBadges) { tab = .challenges }
                FamilyCard(rows: family) { tab = .profile }
                MyTasksCard()
                TaskNotificationsCard()
                LeaderboardTile(rank: friendsRank, total: friendsTotal) { tab = .challenges }

            }
            .padding(.horizontal, 24)
        }
        .task { await reload() }
        .onChange(of: remainingMin) { _, new in
            ScreenTimeService.shared.apply(remainingMin: new)
        }
    }

    private func reload() async {
        await settings.load()
        await health.requestAuthorization()
        family = (try? await SupabaseAPI.familyToday()) ?? []
        earnedBadges = await SupabaseAPI.earnedBadgesOrdered()
        let hist = await SupabaseAPI.historyFilled(days: 2)
        yesterdaySteps = hist.count >= 2 ? hist[hist.count - 2].steps : 0
        let friends = (try? await SupabaseAPI.leaderboard(scope: "friends")) ?? []
        friendsTotal = friends.count
        if let me = await SupabaseAPI.currentUserID() {
            friendsRank = friends.first(where: { $0.user_id == me })?.rank ?? 0
        }
        ScreenTimeService.shared.apply(remainingMin: remainingMin)
    }

    // MARK: header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.dateLine())
                    .font(F.sans(14, .medium)).foregroundStyle(theme.p.s600)
                Text("\(Self.greeting()), \(settings.displayName.isEmpty ? "Lukas" : settings.displayName)")
                    .font(F.xl2).tracking(-0.4).foregroundStyle(theme.foreground)
            }
            Spacer()
            Button { tab = .profile } label: {
                AvatarBubble(avatar: settings.avatar, name: settings.displayName.isEmpty ? settings.username : settings.displayName, size: 40)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .padding(.bottom, 16)
        .rise()
    }

    // MARK: ring

    private var ringCard: some View {
        CardSurface(radius: 28, padding: 32) {
            VStack(spacing: 24) {
                ProgressRing(progress: ringProgress) {
                    VStack(spacing: 4) {
                        Text(steps.formatted())
                            .font(F.sans(36, .semibold)).tabularNums()
                            .foregroundStyle(theme.foreground)
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

    // MARK: stats

    private var statsRow: some View {
        let d = settings.formatDistance(health.distanceKm)
        return HStack(spacing: 16) {
            if settings.role != "child" {
                StatTile(systemImage: "flame", label: L.t("home.energy"),
                         value: "\(health.calories)", unit: "kcal")
            }
            StatTile(systemImage: "shoeprints.fill", label: L.t("home.distance"),
                     value: d.0, unit: d.1)
        }
        .rise(delay: 0.12)
    }

    private var rolloverCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: R.xl2, style: .continuous).fill(theme.p.s600)
                Image(systemName: "sparkles").font(.system(size: 18))
                    .foregroundStyle(theme.primaryForeground)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(L.t("home.bonus_eyebrow"))
                    .font(F.sans(10, .semibold)).textCase(.uppercase).tracking(1.2)
                    .foregroundStyle(theme.p.s700)
                Text(L.t("home.bonus_text", ["n": "\(rolloverMin)"]))
                    .font(F.sans(14, .medium)).foregroundStyle(theme.p.s900)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(theme.p.s100, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                .strokeBorder(theme.p.s200, lineWidth: 1)
        )
        .rise(delay: 0.18)
    }

    // MARK: quote

    private var quoteCard: some View {
        let q = Quotes.today()
        return VStack(alignment: .leading, spacing: 0) {
            Text(L.t("home.quote_eyebrow"))
                .font(F.sans(10, .medium)).textCase(.uppercase).tracking(1.2)
                .foregroundStyle(.white.opacity(0.7))
            Text("\"\(q.text)\"")
                .font(F.sans(17, .medium))
                .foregroundStyle(.white)
                .padding(.top, 8)
            Text("— \(q.author)")
                .font(F.xs).foregroundStyle(.white.opacity(0.8))
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(theme.p.s600, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                .strokeBorder(theme.p.s700.opacity(0.4), lineWidth: 1)
        )
        .rise(delay: 0.21)
    }

    // MARK: helpers

    static func greeting() -> String {
        let cal = Calendar.current
        let now = Date()
        let md = String(format: "%02d-%02d", cal.component(.month, from: now), cal.component(.day, from: now))
        let holidays = [
            "01-01": "home.greeting.newyear", "02-14": "home.greeting.valentines",
            "10-31": "home.greeting.halloween", "12-24": "home.greeting.christmas",
            "12-25": "home.greeting.christmas", "12-26": "home.greeting.christmas",
            "12-31": "home.greeting.nye",
        ]
        if let key = holidays[md] { return L.t(key) }
        let h = cal.component(.hour, from: now)
        if h >= 12 && h < 17 { return L.t("home.greeting.afternoon") }
        if h >= 17 || h < 5 { return L.t("home.greeting.evening") }
        return L.t("home.greeting.morning")
    }

    static func dateLine() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: L.lang == "sv" ? "sv_SE" : "en_US")
        f.setLocalizedDateFormatFromTemplate("EEEE MMM d")
        let s = f.string(from: Date())
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}

// MARK: - Shared pieces

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
                    .font(F.sans(size * 0.25, .semibold)).tracking(1)
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

/// `RecentWins` — last six unlocked badges, or an empty-state nudge.
struct RecentWins: View {
    @EnvironmentObject var theme: Theme
    /// Badge ids ordered by `earned_at`, most recent first.
    let earned: [String]
    var onOpen: () -> Void

    private var items: [BadgeDef] {
        earned.compactMap { id in BADGES.first { $0.id == id } }.prefix(6).map { $0 }
    }
    private let cols = [GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)]


    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L.t("home.recent_wins"))
                    .font(F.sans(11, .semibold)).textCase(.uppercase).tracking(1.2)
                    .foregroundStyle(theme.p.s600)
                Spacer()
                Button(action: onOpen) {
                    Text(L.t("home.recent_wins.view_all"))
                        .font(F.sans(11, .semibold)).textCase(.uppercase).tracking(1.2)
                        .foregroundStyle(theme.p.s700)
                }
            }
            .padding(.horizontal, 4)

            if items.isEmpty {
                Button(action: onOpen) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: R.xl2, style: .continuous).fill(theme.p.s600)
                            Image(systemName: "sparkles").font(.system(size: 18))
                                .foregroundStyle(theme.primaryForeground)
                        }
                        .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.t("home.recent_wins.empty_title"))
                                .font(F.sans(14, .semibold)).foregroundStyle(theme.p.s900)
                            Text(L.t("home.recent_wins.empty_desc"))
                                .font(F.xs).foregroundStyle(theme.p.s700)
                                .multilineTextAlignment(.leading)
                            HStack(spacing: 4) {
                                Text(L.t("home.recent_wins.cta")).font(F.sans(11, .semibold))
                                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(theme.p.s900)
                            .padding(.top, 4)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(20)
                    .background(theme.p.s100, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                            .strokeBorder(theme.p.s200, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(items) { b in
                        Button(action: onOpen) {
                            VStack(spacing: 8) {
                                BadgeMedal(badge: b, earned: true, size: 48)
                                Text(b.name)
                                    .font(F.sans(10, .semibold))
                                    .multilineTextAlignment(.center).lineLimit(2)
                                    .foregroundStyle(theme.foreground)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                                    .strokeBorder(theme.ringBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .rise(delay: 0.24)
    }
}

struct FamilyCard: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    let rows: [FamilyMember]
    var onAddChild: () -> Void

    private var isChild: Bool { settings.role == "child" }
    private var members: [FamilyMember] {
        rows.filter { isChild || $0.relation == "child" || $0.is_self }
    }
    private var hasChildren: Bool { rows.contains { $0.relation == "child" } }

    var body: some View {
        CardSurface {
            if !isChild && !hasChildren {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L.t("home.family")).font(F.sans(14, .semibold))
                        .foregroundStyle(theme.foreground)
                    Text(L.t("home.family.empty")).font(F.xs)
                        .foregroundStyle(theme.p.s600).padding(.top, 8)
                    Button(action: onAddChild) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus").font(.system(size: 14, weight: .semibold))
                            Text(L.t("home.family.add_child")).font(F.sans(14, .semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .foregroundStyle(theme.primaryForeground)
                        .background(theme.p.s600, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                    }
                    .padding(.top, 16)
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(L.t("home.family")).font(F.sans(14, .semibold))
                            .foregroundStyle(theme.foreground)
                        Spacer()
                        Text(L.t("home.today")).eyebrow(theme.p.s600)
                    }
                    if members.isEmpty {
                        Text(L.t("home.family.empty")).font(F.xs).foregroundStyle(theme.p.s600)
                    }
                    ForEach(members) { m in
                        HStack {
                            HStack(spacing: 12) {
                                AvatarBubble(avatar: m.is_self ? settings.avatar : m.avatar,
                                             name: m.name, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.is_self ? L.t("home.family.you") : m.name)
                                        .font(F.sans(14, .medium)).foregroundStyle(theme.foreground)
                                    Text(L.t(m.relation == "parent" ? "home.family.parent" : "home.family.child"))
                                        .font(F.sans(10, .regular)).textCase(.uppercase).tracking(0.8)
                                        .foregroundStyle(theme.p.s600)
                                }
                            }
                            Spacer()
                            Text(m.steps.formatted())
                                .font(F.sans(14, .medium)).tabularNums()
                                .foregroundStyle(theme.foreground)
                        }
                    }
                }
            }
        }
        .rise(delay: 0.27)
    }
}

struct LeaderboardTile: View {
    @EnvironmentObject var theme: Theme
    let rank: Int
    let total: Int
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            CardSurface {
                HStack {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: R.lg, style: .continuous).fill(theme.p.s100)
                            Image(systemName: "bolt.fill").font(.system(size: 15))
                                .foregroundStyle(theme.p.s700)
                        }
                        .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t("home.leaderboards")).font(F.sans(14, .semibold))
                                .foregroundStyle(theme.foreground)
                            Text(total == 0
                                 ? L.t("home.lb_sub.empty")
                                 : L.t("home.lb_sub", ["rank": "\(rank)", "total": "\(total)"]))
                                .font(F.xs).foregroundStyle(theme.p.s600)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14))
                        .foregroundStyle(theme.p.s600)
                }
            }
        }
        .buttonStyle(.plain)
        .rise(delay: 0.3)
    }
}
