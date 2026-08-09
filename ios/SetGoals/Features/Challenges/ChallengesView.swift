import SwiftUI

/// Port of `src/routes/challenges.tsx` — Goals / Badges / Leaderboards tabs.
struct ChallengesView: View {
    enum Tab: Hashable { case goals, badges, lb }

    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @ObservedObject var health = HealthKitService.shared
    @Binding var tab: AppTab
    var initialTab: Tab = .goals

    @State private var sub: Tab = .goals
    @State private var week: [(day: String, steps: Int)] = []
    @State private var earnedBadges: Set<String> = []
    @State private var streak: StreakRow?
    @State private var detail: Challenge?

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(eyebrow: L.t("challenges.eyebrow"), title: L.t("challenges.title")) { EmptyView() }
            VStack(spacing: 24) {
                SegmentedTabs(selection: $sub, items: [
                    (.goals, L.t("challenges.tab.goals")),
                    (.badges, L.t("challenges.tab.badges")),
                    (.lb, L.t("challenges.tab.lb")),
                ])
                switch sub {
                case .goals: goals
                case .badges: BadgesGrid(earned: earnedBadges)
                case .lb: LeaderboardsSection()
                }
            }
            .padding(.horizontal, 24)
        }
        .task {
            sub = initialTab
            week = await SupabaseAPI.weekSteps()
            earnedBadges = (try? await SupabaseAPI.earnedBadges()) ?? []
            streak = try? await SupabaseAPI.streak()
        }
        .sheet(item: $detail) { c in
            ChallengeDetailSheet(challenge: c, progress: ChallengeCatalog.progress(c, today: health, week: week, settings: settings))
                .environmentObject(theme)
        }
    }

    private var goals: some View {
        VStack(spacing: 24) {
            streakCard
            section(L.t("challenges.today"), ChallengeCatalog.todaysDaily, delay: 0)
            section(L.t("challenges.week"), ChallengeCatalog.thisWeeksWeekly, delay: 0.15)
        }
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").font(.system(size: 12))
                Text(L.t("challenges.streak")).textCase(.uppercase).tracking(1)
                    .font(F.sans(10, .medium))
            }
            .foregroundStyle(theme.p.s100.opacity(0.85))
            Text(L.t("challenges.streak_days", ["n": "\(streak?.count ?? 0)"]))
                .font(F.xl3).tabularNums().foregroundStyle(theme.primaryForeground)
            Text(L.t("challenges.streak_sub")).font(F.sm)
                .foregroundStyle(theme.p.s100.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(theme.p.s600, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
        .rise()
    }

    private func section(_ title: String, _ list: [Challenge], delay: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(F.sans(11, .semibold)).textCase(.uppercase).tracking(1)
                .foregroundStyle(theme.p.s600).padding(.horizontal, 4)
            ForEach(Array(list.enumerated()), id: \.element.id) { i, c in
                let p = ChallengeCatalog.progress(c, today: health, week: week, settings: settings)
                ChallengeRow(title: c.title, progress: p.target == 0 ? 0 : min(1, p.current / p.target), done: p.done)
                    .onTapGesture { detail = c }
                    .rise(delay: delay + Double(i) * 0.05)
            }
        }
    }
}

struct ChallengeRow: View {
    @EnvironmentObject var theme: Theme
    let title: String
    let progress: Double
    let done: Bool

    var body: some View {
        CardSurface(radius: R.xl2, padding: 16) {
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(done ? theme.p.s600 : theme.p.s300)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(F.sans(14, .medium)).foregroundStyle(theme.p.s900)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.p.s100)
                            Capsule().fill(theme.p.s600).frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 6)
                }
                Text("\(Int(progress * 100))%").font(F.xs).tabularNums()
                    .foregroundStyle(theme.p.s600)
            }
        }
    }
}

struct ChallengeDetailSheet: View {
    @EnvironmentObject var theme: Theme
    let challenge: Challenge
    let progress: ChallengeCatalog.Progress

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(challenge.title).font(F.sans(20, .semibold)).foregroundStyle(theme.p.s950)
            Text(challenge.detail).font(F.sm).foregroundStyle(theme.p.s700)
            CardSurface {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(L.t("challenges.progress")).eyebrow(theme.p.s600)
                        Spacer()
                        Text("\(ChallengeCatalog.format(progress.current, challenge.metric)) / \(ChallengeCatalog.format(progress.target, challenge.metric))")
                            .font(F.sans(13, .semibold)).tabularNums().foregroundStyle(theme.p.s900)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.p.s100)
                            Capsule().fill(theme.p.s600)
                                .frame(width: geo.size.width * min(1, progress.target == 0 ? 0 : progress.current / progress.target))
                        }
                    }
                    .frame(height: 8)
                }
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background)
        .presentationDetents([.height(320)])
        .presentationCornerRadius(28)
    }
}

/// Port of the `Leaderboard` component in `src/routes/challenges.tsx`.
struct LeaderboardsSection: View {
    @EnvironmentObject var theme: Theme
    @State private var scope = "local"
    @State private var rows: [LeaderboardEntry] = []
    @State private var loading = true
    @State private var me: UUID?
    @State private var region = "—"
    @State private var country = "—"

    private let scopes: [(String, String, String)] = [
        ("local", "mappin.and.ellipse", "lb.local"),
        ("national", "globe", "lb.national"),
        ("friends", "person.2", "lb.friends"),
    ]

    private var youRow: LeaderboardEntry? { rows.first { $0.user_id == me } }
    private var top: [LeaderboardEntry] { Array(rows.prefix(10)) }

    private var todayLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: L.lang == "sv" ? "sv_SE" : "en_US")
        f.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return f.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 20) {
            scopeTabs

            HStack {
                switch scope {
                case "friends": Text(L.t("lb.friends_count", ["n": "\(max(0, rows.count - 1))"]))
                case "local": Text(L.t("lb.region_label", ["region": region]))
                default: Text(L.t("lb.country_label", ["country": country]))
                }
                Spacer()
                Text(L.t("lb.today_label", ["date": todayLabel]))
            }
            .font(F.xs).foregroundStyle(theme.p.s600)

            if loading {
                emptyCard(L.t("lb.loading"))
            } else if top.isEmpty {
                emptyCard(scope == "friends" ? L.t("lb.no_friends") : L.t("lb.empty"))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(top.enumerated()), id: \.element.id) { i, r in
                        row(r, isYou: r.user_id == me).rise(delay: Double(i) * 0.02)
                    }
                }
            }

            if let you = youRow, you.rank > 10 {
                row(you, isYou: true)
            }

            Text(L.t("lb.refresh"))
                .font(F.xs).foregroundStyle(theme.p.s600)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 4)
        }
        .task(id: scope) {
            loading = true
            me = await SupabaseAPI.currentUserID()
            if let p = try? await SupabaseAPI.profile(), let p {
                region = p.region.isEmpty ? "—" : p.region
                country = p.country_code.isEmpty ? "—" : p.country_code
            }
            rows = (try? await SupabaseAPI.leaderboard(scope: scope)) ?? []
            loading = false
        }
    }

    /// `grid grid-cols-3 gap-1 rounded-2xl bg-card p-1 ring-1 ring-black/5`
    private var scopeTabs: some View {
        HStack(spacing: 4) {
            ForEach(scopes, id: \.0) { value, icon, key in
                let active = scope == value
                Button { withAnimation(.easeOut(duration: 0.2)) { scope = value } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                        Text(L.t(key)).font(F.sans(11, .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(active ? theme.primaryForeground : theme.p.s700)
                    .background(
                        Group {
                            if active {
                                RoundedRectangle(cornerRadius: R.xl, style: .continuous).fill(theme.p.s600)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                .strokeBorder(theme.ringBorder, lineWidth: 1)
        )
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(F.sm).foregroundStyle(theme.p.s600)
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                    .strokeBorder(theme.ringBorder, lineWidth: 1)
            )
    }

    private func row(_ r: LeaderboardEntry, isYou: Bool) -> some View {
        HStack(spacing: 16) {
            Text("\(r.rank)")
                .font(F.sans(12, .semibold)).tabularNums()
                .foregroundStyle(isYou ? theme.primaryForeground : theme.p.s700)
                .frame(width: 32, height: 32)
                .background(isYou ? Color.white.opacity(0.15) : theme.p.s100, in: Circle())
            Text(isYou ? L.t("lb.you") : r.display_name)
                .font(F.sans(14, .medium)).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(isYou ? theme.primaryForeground : theme.foreground)
            Text(r.total_steps.formatted())
                .font(F.sans(14, .semibold)).tabularNums()
                .foregroundStyle(isYou ? theme.primaryForeground : theme.foreground)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                .fill(isYou ? theme.p.s600 : theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                .strokeBorder(isYou ? theme.p.s700.opacity(0.4) : theme.ringBorder, lineWidth: 1)
        )
    }
}

