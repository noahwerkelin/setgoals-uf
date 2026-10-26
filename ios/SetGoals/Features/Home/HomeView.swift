import SwiftUI

/// Today dashboard: header, progress, quote, family, recent wins, friends.
struct HomeView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @ObservedObject var health = HealthKitService.shared
    @ObservedObject var screenTime = ScreenTimeService.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var tab: AppTab

    @AppStorage("st.rollover") private var rolloverEnabled = false

    @ObservedObject private var familyStore = FamilyStore.shared
    @ObservedObject private var friendsStore = FriendsStore.shared
    @State private var showAddFriend = false
    @ObservedObject private var badgeStore = BadgeStore.shared
    @State private var rewardFailed = false

    private var goal: Int { settings.dailyGoal > 0 ? settings.dailyGoal : 8000 }
    private var steps: Int { health.steps }
    private var isChild: Bool { settings.role == "child" }
    private var capMin: Int { settings.hasCap ? settings.dailyCapHours * 60 : 24 * 60 }
    private var rolloverMin: Int {
        guard settings.isPro, settings.hasCap else { return 0 }
        return settings.rolloverMin
    }
    private var baseEarned: Int { settings.earnedMin(from: steps) }
    /// Screen time earned today from steps, rollover and parent gifts.
    private var baseAllowanceMin: Int {
        min(capMin + rolloverMin, baseEarned + rolloverMin) + settings.bonusMin
    }
    /// Everything earned today, including challenge rewards Apple has granted.
    private var earnedMin: Int { screenTime.allowanceMin }
    /// Minutes left before Apple's Screen Time locks the managed apps.
    private var remainingMin: Int { screenTime.remainingMin }
    /// Challenge screen time actually granted today.
    private var challengeRewardMin: Int { screenTime.rewardMin }
    private var ringProgress: Double { min(1, Double(steps) / Double(max(goal, 1))) }
    private var goalReached: Bool { steps >= goal }

    var body: some View {
        AppShell(tab: $tab) {
            header
            VStack(spacing: 20) {
                mainCard
                quoteCard
                familySection
                RecentWins(earned: badgeStore.ordered, dates: badgeStore.earnedAt) {
                    NavIntent.shared.challengesTab = .badges
                    tab = .challenges
                }
                TaskNotificationsCard()
                friendsCard
            }
            .padding(.horizontal, 24)
        }
        .task { await reload() }
        .onChange(of: baseAllowanceMin) { _, new in
            screenTime.setBaseAllowance(new)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                screenTime.refreshFromStore()
            }
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet(existing: friendsStore.friends) { Task { await friendsStore.refresh() } }
                .environmentObject(theme)
        }
    }

    private func reload() async {
        await settings.load()
        await health.requestAuthorization()
        screenTime.refreshAuthorization()
        screenTime.setBaseAllowance(baseAllowanceMin)
        // Pay out any challenge rewards completed since the last visit.
        let week = await SupabaseAPI.weekTotals()
        screenTime.setBaseAllowance(baseAllowanceMin)
        let claim = await ChallengeRewards.claimCompleted(week: week, today: health, settings: settings)
        rewardFailed = claim.failed
        screenTime.refreshFromStore()
    }

    private var anim: Animation? { reduceMotion ? nil : .easeOut(duration: 0.3) }

    // MARK: header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.dateLine())
                    .font(F.sans(14, .medium)).foregroundStyle(theme.p.s600)
                Text(L.t("home2.greeting", ["g": Self.greeting(), "name": displayName]))
                    .font(F.xl2).tracking(-0.4).foregroundStyle(theme.foreground)
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 12)
            Button { tab = .profile } label: {
                AvatarBubble(avatar: settings.avatar, name: displayName, size: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.t("nav.profile"))
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .padding(.bottom, 16)
        .rise()
    }

    private var displayName: String {
        settings.displayName.isEmpty ? settings.username : settings.displayName
    }

    // MARK: main card

    private var mainCard: some View {
        CardSurface(radius: R.xl3, padding: 20, backgroundColor: theme.p.s100) {
            VStack(alignment: .leading, spacing: 16) {
                streakPill
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.number(steps))
                        .font(F.xl4).tabularNums()
                        .foregroundStyle(theme.p.s700)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                        .animation(anim, value: steps)
                    Text(L.t("home2.daily_goal", ["g": L.number(goal)]))
                        .font(F.sans(12, .regular)).foregroundStyle(theme.p.s700)
                }

                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        stat(L.t("home2.earned"), L.duration(earnedMin), theme.p.s700)
                        stat(L.t("home2.remaining"), L.t("home2.minutes", ["n": L.number(max(0, remainingMin))]), theme.p.s700)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ProgressRing(progress: ringProgress, size: 112, stroke: 10,
                                 trackColor: theme.p.s200, ringColor: theme.p.s700) {
                        VStack(spacing: 0) {
                            if goalReached {
                                Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(theme.p.s700)
                            }
                            Text("\(Int((Double(steps) / Double(max(goal, 1)) * 100).rounded()))%")
                                .font(F.sans(20, .semibold)).tabularNums()
                                .foregroundStyle(theme.p.s700)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L.t("home2.ring_a11y", ["p": "\(Int(ringProgress * 100))"]))
                }

                if challengeRewardMin > 0 {
                    bonusRow("gift.fill", L.t("home2.challenge_bonus"), "+\(L.duration(challengeRewardMin))")
                } else if rewardFailed {
                    Text(L.t("home.challenge_reward_failed"))
                        .font(F.xs).foregroundStyle(theme.p.s700)
                }
                if settings.bonusMin > 0 {
                    bonusRow("heart.fill", L.t("home2.parent_gift"), "+\(L.duration(settings.bonusMin))")
                }
                if !isChild && settings.isPro && rolloverMin > 0 {
                    bonusRow("arrow.uturn.forward", L.t("home2.rollover"), "+\(L.duration(rolloverMin))")
                }

                Rectangle().fill(theme.border).frame(height: 1)

                HStack(spacing: 12) {
                    let d = settings.formatDistance(health.distanceKm)
                    miniStat("shoeprints.fill", L.t("home2.distance"), d.0, d.1)
                    if !isChild {
                        Rectangle().fill(theme.border).frame(width: 1, height: 32)
                        miniStat("flame", L.t("home2.energy"), L.number(health.calories), "kcal")
                    }
                }
            }
        }
        .rise(delay: 0.06)
    }

    private var streakPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill").font(.system(size: 11, weight: .semibold))
            Text(settings.streakCount > 0
                 ? L.t("home2.streak", ["n": "\(settings.streakCount)"])
                 : L.t("home2.streak_none"))
                .font(F.sans(11, .semibold))
            if goalReached {
                Text("·").font(F.sans(11, .semibold))
                Text(L.t("home2.goal_reached")).font(F.sans(11, .semibold))
            }
        }
        .foregroundStyle(theme.p.s700)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(theme.p.s100, in: Capsule())
        .overlay(Capsule().strokeBorder(theme.p.s200, lineWidth: 1))
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(F.sans(12, .medium)).foregroundStyle(theme.p.s700)
            Text(value).font(F.sans(18, .semibold)).tabularNums().foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .animation(anim, value: value)
        }
    }

    private func bonusRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(theme.p.s700)
            Text(label).font(F.sans(13, .medium)).foregroundStyle(theme.p.s700)
            Spacer(minLength: 8)
            Text(value).font(F.sans(13, .semibold)).tabularNums().foregroundStyle(theme.p.s700)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(theme.p.s100, in: RoundedRectangle(cornerRadius: R.lg, style: .continuous))
    }

    private func miniStat(_ icon: String, _ label: String, _ value: String, _ unit: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: R.sm, style: .continuous).fill(theme.p.s100)
                Image(systemName: icon).font(.system(size: 12)).foregroundStyle(theme.p.s700)
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(F.sans(11, .medium)).foregroundStyle(theme.p.s700)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(F.sans(15, .semibold)).tabularNums().foregroundStyle(theme.p.s700)
                    Text(unit).font(F.sans(11, .regular)).foregroundStyle(theme.p.s700)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: family

    private var quoteCard: some View {
        let quote = Quotes.today()
        return CardSurface(radius: R.xl3, padding: 20, backgroundColor: theme.primary) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("home2.quote"))
                    .font(F.sans(10, .medium)).textCase(.uppercase)
                    .foregroundStyle(theme.primaryForeground.opacity(0.8))
                Text("“\(quote.text)”")
                    .font(F.sans(18, .medium)).foregroundStyle(theme.primaryForeground)
                    .fixedSize(horizontal: false, vertical: true)
                Text("— \(quote.author)")
                    .font(F.xs).foregroundStyle(theme.primaryForeground.opacity(0.8))
            }
        }
    }

    @ViewBuilder private var familySection: some View {
        FamilyCard(rows: familyStore.members, onAddChild: {
            tab = .screenTime
        }, onView: {
            tab = .screenTime
        })
        if isChild { MyTasksCard() }
    }

    // MARK: friends

    private var friendsCard: some View {
        let top = Array(friendsStore.board.prefix(3))
        let me = friendsStore.board.first { $0.user_id == friendsStore.userID }
        return CardSurface(radius: R.xl3, padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("person.2.fill", L.t("home2.friends"))
                if friendsStore.loaded && friendsStore.friends.isEmpty {
                    emptyState(L.t("home2.no_friends"), L.t("home2.no_friends_sub"))
                    PrimaryButton(title: L.t("home2.add_friend")) { showAddFriend = true }
                } else {
                    VStack(spacing: 10) {
                        ForEach(top) { row in lbRow(row, isMe: row.user_id == friendsStore.userID) }
                        if let me, me.rank > 3 {
                            Rectangle().fill(theme.border).frame(height: 1)
                            lbRow(me, isMe: true)
                        }
                    }
                }
                linkButton(L.t("home2.view_friends")) {
                    NavIntent.shared.challengesTab = .lb
                    tab = .challenges
                }
            }
        }
    }

    private func lbRow(_ r: LeaderboardEntry, isMe: Bool) -> some View {
        HStack(spacing: 12) {
            Text("\(r.rank)").font(F.sans(13, .semibold)).tabularNums()
                .foregroundStyle(theme.p.s600).frame(width: 20)
            AvatarBubble(avatar: isMe ? settings.avatar : r.avatar_url,
                         name: r.display_name.isEmpty ? r.username : r.display_name, size: 32)
            Text(isMe ? L.t("home2.you") : (r.display_name.isEmpty ? "@\(r.username)" : r.display_name))
                .font(F.sans(14, .medium)).foregroundStyle(theme.foreground).lineLimit(1)
            Spacer(minLength: 8)
            Text("\(L.number(r.total_steps)) \(L.t("home2.steps_unit"))")
                .font(F.sans(13, .medium)).tabularNums().foregroundStyle(theme.p.s700)
        }
        .padding(.horizontal, isMe ? 10 : 0).padding(.vertical, isMe ? 6 : 0)
        .background(isMe ? theme.p.s100 : .clear, in: RoundedRectangle(cornerRadius: R.lg, style: .continuous))
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
        f.locale = L.locale
        f.setLocalizedDateFormatFromTemplate("EEEE MMM d")
        let s = f.string(from: Date())
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}

// MARK: - Shared card pieces

extension View {
    func sectionTitle(_ icon: String, _ title: String) -> some View { SectionTitle(icon: icon, title: title) }
    func emptyState(_ title: String, _ sub: String) -> some View { EmptyStateText(title: title, sub: sub) }
    func linkButton(_ title: String, _ action: @escaping () -> Void) -> some View { CardLinkButton(title: title, action: action) }
}

struct SectionTitle: View {
    @EnvironmentObject var theme: Theme
    let icon: String
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: R.sm, style: .continuous).fill(theme.p.s100)
                Image(systemName: icon).font(.system(size: 12)).foregroundStyle(theme.p.s700)
            }
            .frame(width: 28, height: 28)
            Text(title).font(F.sans(14, .semibold)).foregroundStyle(theme.foreground)
            Spacer(minLength: 0)
        }
    }
}

struct EmptyStateText: View {
    @EnvironmentObject var theme: Theme
    let title: String
    let sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(F.sans(14, .medium)).foregroundStyle(theme.p.s900)
            if !sub.isEmpty { Text(sub).font(F.xs).foregroundStyle(theme.p.s600) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Full-width secondary link at the bottom of a Home card.
struct CardLinkButton: View {
    @EnvironmentObject var theme: Theme
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).font(F.sans(13, .semibold))
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .foregroundStyle(theme.p.s900)
            .background(theme.p.s100, in: Capsule())
            .overlay(Capsule().strokeBorder(theme.p.s200, lineWidth: 1))
        }
        .buttonStyle(FlatPress())
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

/// Three most recently earned badges, or an empty-state nudge.
struct RecentWins: View {
    @EnvironmentObject var theme: Theme
    /// Badge ids ordered by `earned_at`, most recent first.
    let earned: [String]
    var dates: [String: Date] = [:]
    var onOpen: () -> Void

    private var items: [BadgeDef] {
        Array(earned.compactMap { id in BADGES.first { $0.id == id } }.prefix(3))
    }

    private func dateText(_ id: String) -> String {
        guard let d = dates[id] else { return "" }
        let f = DateFormatter()
        f.locale = L.locale
        f.setLocalizedDateFormatFromTemplate("MMM d")
        return f.string(from: d)
    }

    var body: some View {
        CardSurface(radius: R.xl3, padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(icon: "rosette", title: L.t("home2.recent_wins"))
                if items.isEmpty {
                    EmptyStateText(title: L.t("home2.no_badges"), sub: L.t("home2.no_badges_sub"))
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(items) { b in
                            VStack(spacing: 6) {
                                BadgeMedal(badge: b, earned: true, size: 44)
                                Text(b.name)
                                    .font(F.sans(11, .semibold))
                                    .multilineTextAlignment(.center).lineLimit(2)
                                    .foregroundStyle(theme.foreground)
                                Text(dateText(b.id))
                                    .font(F.sans(10, .regular)).foregroundStyle(theme.p.s600)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        ForEach(0..<(3 - items.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
                    }
                }
                CardLinkButton(title: L.t("home2.view_all"), action: onOpen)
            }
        }
        .rise(delay: 0.24)
    }
}

/// Role-aware family card: children preview, parent for kids, or add-child.
struct FamilyCard: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    let rows: [FamilyMember]
    var onAddChild: () -> Void
    var onView: () -> Void

    private var isChild: Bool { settings.role == "child" }
    private var children: [FamilyMember] { rows.filter { $0.relation == "child" } }
    private var parent: FamilyMember? { rows.first { $0.relation == "parent" && !$0.is_self } }

    var body: some View {
        CardSurface(radius: R.xl3, padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(icon: "figure.2.and.child.holdinghands", title: L.t("home2.family"))
                if isChild {
                    if let p = parent {
                        HStack(spacing: 12) {
                            AvatarBubble(avatar: p.avatar, name: p.name, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(F.sans(14, .medium)).foregroundStyle(theme.foreground)
                                Text(L.t("home2.your_parent")).font(F.sans(11, .regular)).foregroundStyle(theme.p.s600)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                } else if children.isEmpty {
                    EmptyStateText(title: L.t("home2.no_children"), sub: "")
                    PrimaryButton(title: L.t("home2.add_child"), action: onAddChild)
                } else {
                    VStack(spacing: 12) {
                        ForEach(children) { c in
                            HStack(spacing: 12) {
                                AvatarBubble(avatar: c.avatar, name: c.name, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.name).font(F.sans(14, .medium)).foregroundStyle(theme.foreground).lineLimit(1)
                                    Text("\(L.number(c.steps)) \(L.t("home2.steps_unit"))")
                                        .font(F.sans(12, .regular)).tabularNums().foregroundStyle(theme.p.s600)
                                }
                                Spacer(minLength: 8)
                                Text(L.duration(c.earned_min ?? 0))
                                    .font(F.sans(14, .semibold)).tabularNums().foregroundStyle(theme.p.s700)
                            }
                        }
                    }
                }
                if isChild ? parent != nil : !children.isEmpty {
                    CardLinkButton(title: L.t("home2.view_family"), action: onView)
                }
            }
        }
        .rise(delay: 0.12)
    }
}
