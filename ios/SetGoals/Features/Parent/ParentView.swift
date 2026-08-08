import SwiftUI
import UIKit
import Supabase

/// 1:1 port of `src/routes/parent.tsx` — Personal / Children tabs, category
/// permissions, PRO screen-time rules, child cards, weekly summary, tasks,
/// gifting and invitation codes.
struct ParentView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @StateObject private var pst = ProSTStore.shared
    @Binding var tab: AppTab

    enum ParentTab: Hashable { case personal, children }

    @State private var section: ParentTab = .personal
    @State private var children: [ChildRow] = []
    @State private var today: [UUID: ChildDayStats] = [:]
    @State private var week: [UUID: [String: (steps: Int, usedMin: Int)]] = [:]
    @State private var parentID: UUID?

    @State private var editing: ChildRow?
    @State private var creatingChild = false
    @State private var deleting: ChildRow?
    @State private var gifting: ChildRow?
    @State private var editingChildST: ChildRow?
    @State private var editingMyST = false
    @State private var showPro = false

    private var isIndividual: Bool { settings.role == "individual" }
    private var isChild: Bool { settings.role == "child" }
    private var canManageChildren: Bool { !isChild }
    private static let maxChildren = 5

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(eyebrow: isIndividual ? L.t("screentime.eyebrow") : L.t("parent.eyebrow"),
                       title: isIndividual ? L.t("screentime.title") : L.t("parent.title")) {
                ZStack {
                    Circle().fill(theme.p.s100)
                    Image(systemName: isIndividual ? "clock" : "shield")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.p.s700)
                }
                .frame(width: 40, height: 40)
            }

            VStack(spacing: 24) {
                if canManageChildren {
                    SegmentedTabs(selection: $section, items: [
                        (.personal, L.t("parent.tab.personal")),
                        (.children, L.t("parent.tab.children")),
                    ])
                }

                if !canManageChildren || section == .personal {
                    myScreenTimeCard
                    categoriesSection
                    if !isChild {
                        ProScreenTimeSection(isPro: settings.isPro) { showPro = true }
                    }
                } else {
                    childrenSection
                }
            }
            .padding(.horizontal, 24)
        }
        .task { await reload() }
        .sheet(isPresented: $showPro) { ProUpgradeDialog() }
        .sheet(isPresented: $editingMyST) {
            ParentScreenTimeDialog(title: L.t("parent.my_screentime"),
                                   stepsPer30: settings.stepsPer30,
                                   dailyCapHours: settings.dailyCapHours) { steps, cap in
                Task {
                    settings.stepsPer30 = steps
                    settings.dailyCapHours = cap
                    try? await SupabaseAPI.updateSettings([
                        "steps_per_30": .integer(steps),
                        "daily_cap_hours": .integer(cap),
                    ])
                }
            }
        }
        .sheet(item: $editingChildST) { c in
            ParentScreenTimeDialog(title: L.t("parent.child_screentime", ["n": c.name.isEmpty ? "—" : c.name]),
                                   stepsPer30: c.steps_per_30,
                                   dailyCapHours: c.daily_cap_hours) { steps, cap in
                Task {
                    try? await SupabaseAPI.updateChildScreenTime(c.id, stepsPer30: steps, dailyCapHours: cap)
                    await reload()
                }
            }
        }
        .sheet(item: $editing) { c in
            ChildEditDialog(child: c, isNew: false, existing: children) { await reload() }
        }
        .sheet(isPresented: $creatingChild) {
            ChildEditDialog(child: nil, isNew: true, existing: children) { await reload() }
        }
        .sheet(item: $deleting) { c in
            DeleteChildDialog(child: c) { await reload() }
        }
        .sheet(item: $gifting) { c in
            GiftScreenTimeDialog(child: c) { await reload() }
        }
    }

    // MARK: - Personal

    private var myScreenTimeCard: some View {
        CardSurface(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: R.md, style: .continuous).fill(theme.p.s100)
                        Image(systemName: "clock").font(.system(size: 15)).foregroundStyle(theme.p.s700)
                    }
                    .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("parent.my_screentime")).font(F.sans(14, .semibold))
                            .foregroundStyle(theme.p.s950)
                        Text(L.t("parent.my_screentime_sub")).font(F.xs).foregroundStyle(theme.p.s600)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 12) {
                    ParentStat(label: L.t("parent.steps_per_30"), value: settings.stepsPer30.formatted())
                    ParentStat(label: L.t("parent.daily_cap"),
                               value: settings.dailyCapHours >= 24
                                   ? L.t("parent.no_cap")
                                   : "\(settings.dailyCapHours)\(L.t("settings.hours"))")
                }
                if isChild {
                    Text(L.t("parent.child_locked"))
                        .font(F.text11).foregroundStyle(theme.p.s600)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: R.md, style: .continuous)
                            .stroke(theme.p.s200, lineWidth: 1))
                } else {
                    Button { editingMyST = true } label: {
                        Text(L.t("parent.edit_screentime"))
                            .font(F.sans(12, .semibold)).foregroundStyle(theme.p.s700)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(theme.p.s100, in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
                    }
                }
            }
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "iphone").font(.system(size: 11, weight: .semibold))
                Text(L.t("parent.apps"))
            }
            .eyebrow(theme.p.s600)
            .padding(.horizontal, 4)

            Text(L.t("stmode.hint")).font(F.text11).foregroundStyle(theme.p.s600).padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(ScreenTimeCategories.keys.enumerated()), id: \.element) { i, key in
                    if i > 0 { Divider().background(theme.p.s100) }
                    HStack(spacing: 12) {
                        Text(L.t(key)).font(F.sm).foregroundStyle(theme.p.s900).lineLimit(1)
                        Spacer(minLength: 8)
                        CategoryToggle(
                            isAlways: pst.alwaysAllow[key] ?? true,
                            enabled: !isChild
                        ) { next in
                            pst.alwaysAllow[key] = next
                        }
                    }
                    .padding(16)
                }
            }
            .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1))
        }
    }

    // MARK: - Children

    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t("parent.children")).eyebrow(theme.p.s600).padding(.horizontal, 4)

            TaskNotificationsCard()

            if children.isEmpty {
                Text(L.t("parent.child.empty"))
                    .font(F.xs).foregroundStyle(theme.p.s600)
                    .frame(maxWidth: .infinity).padding(20)
                    .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                        .stroke(.black.opacity(0.05), lineWidth: 1))
            }

            ForEach(Array(children.enumerated()), id: \.element.id) { i, c in
                childCard(c).rise(delay: Double(i) * 0.06)
            }

            if children.count >= Self.maxChildren {
                Text(L.t("parent.child.limit_reached", ["max": "\(Self.maxChildren)"]))
                    .font(F.xs).foregroundStyle(theme.p.s600)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                        .stroke(theme.p.s200, lineWidth: 1))
            } else {
                Button { creatingChild = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .semibold))
                        Text(L.t("parent.add_child")).font(F.sans(14, .medium))
                    }
                    .foregroundStyle(theme.p.s700)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(theme.p.s300))
                }
            }
        }
    }

    private func childCard(_ c: ChildRow) -> some View {
        let stats = c.auth_user_id.flatMap { today[$0] } ?? ChildDayStats()
        let usedH = stats.usedMin / 60
        let usedM = stats.usedMin % 60
        return CardSurface(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    AvatarBubble(avatar: c.avatar, name: c.name, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.name).font(F.sans(14, .semibold)).foregroundStyle(theme.p.s950).lineLimit(1)
                        Text(Self.ageLabel(c.birthday)).font(F.xs).foregroundStyle(theme.p.s600)
                    }
                    Spacer(minLength: 0)
                    circleButton("pencil") { editing = c }
                    circleButton("trash") { deleting = c }
                }

                HStack(spacing: 12) {
                    ParentStat(label: L.t("parent.steps"), value: stats.steps.formatted())
                    ParentStat(label: L.t("parent.child.daily_goal"), value: c.daily_goal.formatted())
                    ParentStat(label: L.t("parent.used_screentime"),
                               value: usedH > 0 ? "\(usedH)\(L.t("settings.hours")) \(usedM)m" : "\(usedM)m")
                }

                WeeklySummary(week: c.auth_user_id.flatMap { week[$0] } ?? [:])

                innerCard(icon: "clock", title: L.t("parent.child_screentime", ["n": c.name.isEmpty ? "—" : c.name])) {
                    HStack(spacing: 12) {
                        ParentStat(label: L.t("parent.steps_per_30"), value: c.steps_per_30.formatted(), onCard: true)
                        ParentStat(label: L.t("parent.daily_cap"),
                                   value: c.daily_cap_hours >= 24
                                       ? L.t("parent.no_cap")
                                       : "\(c.daily_cap_hours)\(L.t("settings.hours"))",
                                   onCard: true)
                    }
                    Button { editingChildST = c } label: {
                        Text(L.t("parent.edit_screentime"))
                            .font(F.sans(12, .semibold)).foregroundStyle(theme.p.s700)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(theme.card, in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: R.md, style: .continuous)
                                .stroke(theme.p.s200, lineWidth: 1))
                    }
                }

                innerCard(icon: "gift", title: L.t("parent.gift.title")) {
                    Text(L.t("parent.gift.sub")).font(F.text11).foregroundStyle(theme.p.s600)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if stats.bonusMin > 0 {
                        Text(L.t("parent.gift.given_today", ["m": "\(stats.bonusMin)"]))
                            .font(F.sans(10, .semibold)).foregroundStyle(theme.p.s700)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(theme.card, in: Capsule())
                            .overlay(Capsule().stroke(theme.p.s200, lineWidth: 1))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button { gifting = c } label: {
                        Text(c.auth_user_id != nil ? L.t("parent.gift.cta") : L.t("parent.gift.needs_join"))
                            .font(F.sans(12, .semibold)).foregroundStyle(theme.primaryForeground)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(theme.primary, in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
                    }
                    .disabled(c.auth_user_id == nil)
                    .opacity(c.auth_user_id == nil ? 0.5 : 1)
                }

                ChildTasksSection(childID: c.id, childName: c.name, parentID: parentID,
                                  canAssign: c.auth_user_id != nil && parentID != nil)

                invitationBlock(c)
            }
        }
    }

    @ViewBuilder
    private func invitationBlock(_ c: ChildRow) -> some View {
        if c.invitation_status == "connected" {
            HStack(spacing: 8) {
                Image(systemName: "link").font(.system(size: 13)).foregroundStyle(theme.p.s700)
                Text(L.t("parent.child.status_connected")).font(F.sans(12, .semibold))
                    .foregroundStyle(theme.p.s900)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                .stroke(theme.p.s200, lineWidth: 1))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("parent.child.code")).eyebrow(theme.p.s600)
                        Text(c.code).font(F.sans(16, .semibold)).tracking(3.2)
                            .foregroundStyle(theme.p.s900)
                    }
                    Spacer(minLength: 0)
                    Text(L.t(c.invitation_status == "expired"
                             ? "parent.child.status_expired" : "parent.child.status_pending"))
                        .font(F.sans(10, .semibold))
                        .foregroundStyle(c.invitation_status == "expired" ? Color.red : Color.orange)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background((c.invitation_status == "expired" ? Color.red : Color.orange).opacity(0.12),
                                    in: Capsule())
                }
                HStack(spacing: 8) {
                    smallButton("doc.on.doc", L.t("parent.child.copy")) { copy(c.code) }
                    smallButton("square.and.arrow.up", L.t("parent.child.share")) { share(c) }
                    smallButton("arrow.clockwise", L.t("parent.child.regenerate"), primary: true) {
                        Task { _ = try? await SupabaseAPI.issueChildCode(c.id); await reload() }
                    }
                }
            }
            .padding(16)
            .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                .stroke(theme.p.s200, lineWidth: 1))

            Text(L.t("parent.child.code_help")).font(F.sans(10)).foregroundStyle(theme.p.s600)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Bits

    @ViewBuilder
    private func innerCard<C: View>(icon: String, title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(theme.p.s700)
                Text(title).font(F.sans(12, .semibold)).foregroundStyle(theme.p.s900)
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(16)
        .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
            .stroke(theme.p.s200, lineWidth: 1))
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(theme.p.s100)
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.p.s700)
            }
            .frame(width: 32, height: 32)
        }
    }

    private func smallButton(_ icon: String, _ title: String, primary: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(title).font(F.sans(11, .semibold)).lineLimit(1)
            }
            .foregroundStyle(primary ? theme.primaryForeground : theme.p.s700)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(primary ? theme.primary : theme.card,
                        in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.md, style: .continuous)
                .stroke(primary ? .clear : theme.p.s200, lineWidth: 1))
        }
    }

    private func copy(_ code: String) { UIPasteboard.general.string = code }

    private func share(_ c: ChildRow) {
        let text = L.t("parent.child.share_text", ["n": c.name, "c": c.code])
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first?.present(av, animated: true)
    }

    static func ageLabel(_ birthday: String?) -> String {
        guard let b = birthday, !b.isEmpty else { return "—" }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        guard let d = f.date(from: b) else { return "—" }
        let years = Calendar.current.dateComponents([.year], from: d, to: Date()).year ?? 0
        return L.t("parent.age", ["n": "\(years)"])
    }

    private func reload() async {
        parentID = await SupabaseAPI.currentUserID()
        children = (try? await SupabaseAPI.children()) ?? []
        let ids = children.compactMap(\.auth_user_id)
        let activity = await SupabaseAPI.childActivity(ids)
        today = activity.today
        week = activity.week
    }
}

// MARK: - Stat tile

struct ParentStat: View {
    @EnvironmentObject var theme: Theme
    let label: String
    let value: String
    var onCard: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(F.sans(14, .semibold)).tabularNums().foregroundStyle(theme.p.s900)
            Text(label).font(F.sans(10, .medium)).textCase(.uppercase).tracking(0.6)
                .foregroundStyle(theme.p.s600).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(onCard ? theme.card : theme.p.s50,
                    in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
            .stroke(.black.opacity(0.05), lineWidth: 1))
    }
}

// MARK: - Category toggle (Always allow / Only with earned time)

struct CategoryToggle: View {
    @EnvironmentObject var theme: Theme
    let isAlways: Bool
    var enabled: Bool = true
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 0) {
            pill(icon: "infinity", title: L.t("stmode.always_short"), active: isAlways,
                 fill: theme.primary) { onChange(true) }
            pill(icon: "bolt.fill", title: L.t("stmode.earned_short"), active: !isAlways,
                 fill: Color(red: 0.96, green: 0.62, blue: 0.04)) { onChange(false) }
        }
        .padding(4)
        .background(theme.p.s50, in: Capsule())
        .overlay(Capsule().stroke(.black.opacity(0.05), lineWidth: 1))
        .opacity(enabled ? 1 : 0.6)
        .allowsHitTesting(enabled)
    }

    private func pill(icon: String, title: String, active: Bool, fill: Color,
                      action: @escaping () -> Void) -> some View {
        Button { withAnimation(.easeOut(duration: 0.3)) { action() } } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(title).font(F.sans(11, .semibold)).lineLimit(1)
            }
            .foregroundStyle(active ? .white : theme.p.s700)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(active ? fill : .clear, in: Capsule())
        }
    }
}

// MARK: - Weekly summary

struct WeeklySummary: View {
    @EnvironmentObject var theme: Theme
    let week: [String: (steps: Int, usedMin: Int)]

    private var days: [(key: String, date: Date, steps: Int, usedMin: Int)] {
        (0..<7).map { i in
            let d = Calendar.current.date(byAdding: .day, value: -(6 - i), to: Date())!
            let key = SupabaseAPI.dayKey(d)
            let cell = week[key] ?? (steps: 0, usedMin: 0)
            return (key, d, cell.steps, cell.usedMin)
        }
    }

    private func fmtMin(_ m: Int) -> String {
        m >= 60 ? "\(m / 60)\(L.t("settings.hours")) \(m % 60)m" : "\(m)m"
    }

    var body: some View {
        let rows = days
        let maxSteps = max(1, rows.map(\.steps).max() ?? 1)
        let totalSteps = rows.reduce(0) { $0 + $1.steps }
        let totalMin = rows.reduce(0) { $0 + $1.usedMin }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(L.t("parent.week_summary")).font(F.sans(12, .semibold)).foregroundStyle(theme.p.s900)
                Spacer()
                Text("\(totalSteps.formatted()) \(L.t("parent.steps").lowercased()) · \(fmtMin(totalMin))")
                    .font(F.sans(10, .medium)).foregroundStyle(theme.p.s600)
            }
            HStack(alignment: .top, spacing: 6) {
                ForEach(rows, id: \.key) { r in
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(theme.card.opacity(0.7))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(theme.p.s200, lineWidth: 1))
                            Capsule().fill(theme.p.s500)
                                .frame(width: 10,
                                       height: max(4, CGFloat(r.steps) / CGFloat(maxSteps) * 56))
                        }
                        .frame(height: 64)
                        Text(Self.narrowWeekday(r.date)).font(F.sans(9, .semibold))
                            .textCase(.uppercase).foregroundStyle(theme.p.s700)
                        Text(r.steps > 0 ? r.steps.formatted() : "—")
                            .font(F.sans(9)).tabularNums().foregroundStyle(theme.p.s600)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text(r.usedMin > 0 ? fmtMin(r.usedMin) : "—")
                            .font(F.sans(9)).tabularNums().foregroundStyle(theme.p.s500)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
            .stroke(theme.p.s200, lineWidth: 1))
    }

    static func narrowWeekday(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: L.lang == "sv" ? "sv_SE" : "en_US")
        f.dateFormat = "EEEEE"
        return f.string(from: d)
    }
}

// MARK: - PRO screen-time rules

struct ProScreenTimeSection: View {
    @EnvironmentObject var theme: Theme
    @StateObject private var pst = ProSTStore.shared
    let isPro: Bool
    let onUpgrade: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: R.md, style: .continuous).fill(theme.primary)
                        Image(systemName: "sparkles").font(.system(size: 14))
                            .foregroundStyle(theme.primaryForeground)
                    }
                    .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("pro.st.title")).font(F.sans(14, .semibold)).foregroundStyle(theme.p.s950)
                        Text(L.t("pro.badge")).eyebrow(theme.p.s600)
                    }
                }
                Spacer(minLength: 0)
                if !isPro {
                    Button(action: onUpgrade) {
                        Text(L.t("pro.upgrade")).font(F.sans(12, .semibold))
                            .foregroundStyle(theme.primaryForeground)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(theme.primary, in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
                    }
                }
            }

            Text(L.t("pro.st.sub")).font(F.xs).foregroundStyle(theme.p.s600)

            VStack(spacing: 8) {
                toggleRow(L.t("pro.st.rollover"), L.t("pro.st.rollover_sub"), $pst.rollover)
                toggleRow(L.t("pro.st.weekend2x"), L.t("pro.st.weekend2x_sub"), $pst.weekend2x)
                toggleRow(L.t("pro.st.split_caps"), L.t("pro.st.split_caps_sub"), $pst.splitCaps)

                if pst.splitCaps {
                    VStack(spacing: 12) {
                        capSlider(L.t("pro.st.weekday_cap"), value: $pst.weekdayCap)
                        capSlider(L.t("pro.st.weekend_cap"), value: $pst.weekendCap)
                    }
                    .padding(16)
                    .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                        .stroke(theme.p.s200, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock").font(.system(size: 12)).foregroundStyle(theme.p.s700)
                        Text(L.t("pro.st.cat_limits")).font(F.sans(12, .semibold)).foregroundStyle(theme.p.s900)
                        Spacer(minLength: 0)
                    }
                    Text(L.t("pro.st.cat_limits_sub")).font(F.text11).foregroundStyle(theme.p.s600)
                    ForEach(ScreenTimeCategories.keys, id: \.self) { key in
                        let v = pst.catLimits[key] ?? 0
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(L.t(key)).font(F.sans(11, .medium)).foregroundStyle(theme.p.s700)
                                Spacer()
                                Text(v == 0 ? L.t("pro.st.no_limit") : "\(v) min")
                                    .font(F.sans(11, .medium)).tabularNums().foregroundStyle(theme.p.s700)
                            }
                            Slider(value: Binding(
                                get: { Double(v) },
                                set: { pst.catLimits[key] = Int($0.rounded()) }
                            ), in: 0...240, step: 15).tint(theme.primary)
                        }
                    }
                }
                .padding(16)
                .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                    .stroke(theme.p.s200, lineWidth: 1))
            }
            .opacity(isPro ? 1 : 0.6)
            .allowsHitTesting(isPro)

            if !isPro {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.system(size: 11))
                    Text(L.t("pro.st.unlock")).font(F.sans(11, .medium))
                }
                .foregroundStyle(theme.p.s700)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(theme.card.opacity(0.6), in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                    .stroke(theme.p.s200, lineWidth: 1))
            }
        }
        .padding(20)
        .background(isPro ? theme.card : theme.p.s50,
                    in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
            .stroke(isPro ? .black.opacity(0.05) : theme.p.s200, lineWidth: 1))
    }

    private func toggleRow(_ label: String, _ sub: String, _ binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(F.sans(12, .semibold)).foregroundStyle(theme.p.s900)
                Text(sub).font(F.text11).foregroundStyle(theme.p.s600)
            }
            Spacer(minLength: 0)
            if isPro {
                Toggle("", isOn: binding).labelsHidden().tint(theme.primary)
            } else {
                Image(systemName: "lock.fill").font(.system(size: 13)).foregroundStyle(theme.p.s500)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
            .stroke(theme.p.s200, lineWidth: 1))
    }

    private func capSlider(_ label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(F.sans(11, .medium)).textCase(.uppercase).tracking(0.6)
                    .foregroundStyle(theme.p.s600)
                Spacer()
                Text("\(value.wrappedValue)\(L.t("settings.hours"))")
                    .font(F.sans(11, .medium)).tabularNums().foregroundStyle(theme.p.s700)
            }
            Slider(value: Binding(get: { Double(value.wrappedValue) },
                                  set: { value.wrappedValue = Int($0.rounded()) }),
                   in: 1...8, step: 1).tint(theme.primary)
        }
    }
}
