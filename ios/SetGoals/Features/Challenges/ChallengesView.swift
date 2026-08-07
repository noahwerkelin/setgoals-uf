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

/// Port of `src/routes/leaderboards.tsx` + the leaderboard tab.
struct LeaderboardsSection: View {
    @EnvironmentObject var theme: Theme
    @State private var scope = "local"
    @State private var rows: [LeaderboardEntry] = []
    @State private var loading = true

    var body: some View {
        VStack(spacing: 16) {
            SegmentedTabs(selection: $scope, items: [
                ("local", L.t("lb.local")), ("national", L.t("lb.national")), ("friends", L.t("lb.friends")),
            ])
            if loading {
                ProgressView().tint(theme.p.s600).padding(.vertical, 32)
            } else if rows.isEmpty {
                CardSurface { Text(L.t("lb.empty")).font(F.sm).foregroundStyle(theme.p.s600) }
            } else {
                CardSurface(padding: 8) {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.prefix(10).enumerated()), id: \.element.id) { i, r in
                            if i > 0 { Divider().overlay(theme.p.s100) }
                            HStack(spacing: 12) {
                                Text("\(r.rank)").font(F.sans(13, .semibold)).tabularNums()
                                    .frame(width: 22).foregroundStyle(theme.p.s600)
                                AvatarBubble(avatar: r.avatar_url, name: r.display_name, size: 32)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(r.display_name).font(F.sans(14, .medium)).foregroundStyle(theme.p.s900)
                                    Text("@\(r.username)").font(F.text11).foregroundStyle(theme.p.s600)
                                }
                                Spacer()
                                Text(r.total_steps.formatted()).font(F.sans(14, .semibold)).tabularNums()
                                    .foregroundStyle(theme.p.s700)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 12)
                        }
                    }
                }
            }
        }
        .task(id: scope) {
            loading = true
            rows = (try? await SupabaseAPI.leaderboard(scope: scope)) ?? []
            loading = false
        }
    }
}
