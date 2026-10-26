import SwiftUI
import UIKit
import Supabase
import FamilyControls

/// Unified native Screen Time dashboard; existing family APIs and restrictions remain authoritative.
struct ParentView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @Binding var tab: AppTab

    @ObservedObject private var screenTime = ScreenTimeService.shared
    @ObservedObject private var health = HealthKitService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedChildID: UUID?
    @State private var family: [FamilyMember] = []
    @State private var loadingFamily = true
    @State private var familyError = false
    @State private var confirmation: String?
    @State private var childPanel: ChildPanel = .overview
    private enum ChildPanel: Hashable { case overview, tasks, settings }
    @State private var selectionRevision = 0
    @State private var authorizationError = false

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
    @State private var pickerMode: PickerMode?
    private enum PickerMode: String, Identifiable {
        case earned, always
        var id: String { rawValue }
    }
    @State private var showPro = false

    private var isChild: Bool { settings.role == "child" }
    private var canManageChildren: Bool { !isChild }
    private static let maxChildren = 5

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(eyebrow: L.t("dashboard.eyebrow"), title: L.t("nav.screenTime")) { EmptyView() }

            VStack(alignment: .leading, spacing: 28) {
                myScreenTimeCard
                if !isChild { childrenSection }
                categoriesSection
                if isChild { MyTasksCard() }
                if !isChild { ProScreenTimeSection(isPro: settings.isPro) { showPro = true } }
            }
            .padding(.horizontal, 24)
        }
        .task {
            screenTime.refreshAuthorization()
            screenTime.refreshFromStore()
            if canManageChildren { await reload() }
        }

        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                screenTime.refreshAuthorization()
                screenTime.refreshFromStore()
                if canManageChildren { Task { await reload() } }
            }
        }
        .sheet(item: $pickerMode) { mode in
            NativeScreenTimePicker(alwaysAllowed: false) { selectionRevision += 1 }
        }
        .sheet(isPresented: $showPro) { ProUpgradeDialog() }
        .sheet(isPresented: $editingMyST) {
            ParentScreenTimeDialog(title: L.t("parent.my_screentime"),
                                   stepsPer30: settings.stepsPer30,
                                   dailyCapHours: settings.dailyCapHours) { steps, cap in
                Task {
                    guard settings.isPro, !isChild else { return }
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
            GiftScreenTimeDialog(child: c) {
                confirmation = L.t("dashboard.bonus_confirmed", ["name": c.name])
                await reload()
            }
        }
    }

    // MARK: - Personal

    private var myScreenTimeCard: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(L.t("dashboard.personal"), icon: "hourglass")
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        balanceStat(L.t("dashboard.earned"), screenTime.allowanceMin)
                        balanceStat(L.t("dashboard.remaining"), screenTime.remainingMin)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        balanceStat(L.t("dashboard.earned"), screenTime.allowanceMin)
                        balanceStat(L.t("dashboard.remaining"), screenTime.remainingMin)
                    }
                }
                ProgressView(value: Double(health.steps % max(1, settings.stepsPer30)),
                             total: Double(max(1, settings.stepsPer30)))
                    .tint(theme.primary)
                Text(L.t("dashboard.conversion", ["steps": L.number(settings.stepsPer30)]))
                    .font(F.xs).foregroundStyle(theme.p.s600)
                HStack {
                    Text(L.t("dashboard.limit")).font(F.sans(12, .semibold))
                    Spacer()
                    Text(settings.hasCap ? L.duration(settings.dailyCapHours * 60) : L.t("parent.no_cap"))
                        .font(F.sans(12, .semibold)).tabularNums()
                }
                .foregroundStyle(theme.p.s900)
                if isChild {
                    Text(L.t("parent.child_locked")).font(F.xs).foregroundStyle(theme.mutedForeground)
                } else {
                    Button {
                        if settings.isPro { editingMyST = true } else { showPro = true }
                    } label: {
                            HStack(spacing: 6) {
                            Image(systemName: settings.isPro ? "slider.horizontal.3" : "lock.fill").font(.system(size: 12, weight: .semibold))
                            Text(L.t("parent.edit_screentime")).font(F.sans(14, .semibold))
                        }
                        .foregroundStyle(theme.p.s900)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(theme.p.s100, in: Capsule())
                        .overlay(Capsule().strokeBorder(theme.p.s200, lineWidth: 1))
                    }
                    .buttonStyle(FlatPress())
                }
            }
        }
    }

    private func balanceStat(_ title: String, _ minutes: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(F.sans(12, .medium)).foregroundStyle(theme.p.s600)
            Text(L.t("home2.minutes", ["n": L.number(minutes)]))
                .font(F.sans(20, .medium)).tabularNums().foregroundStyle(theme.foreground)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: R.lg, style: .continuous).fill(theme.p.s100)
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(theme.p.s700)
            }
            .frame(width: 28, height: 28)
            Text(title).font(F.sans(14, .semibold)).foregroundStyle(theme.p.s950)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var categoriesSection: some View {
        let selected = ScreenTimeRules.restricted
        return CardSurface {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(L.t("dashboard.apps"), icon: "iphone")
                if isChild {
                    Text(L.t("dashboard.remote")).font(F.xs).foregroundStyle(theme.p.s600)
                } else {
                    Text(L.t("dashboard.selection", [
                        "apps": L.number(selected.applicationTokens.count),
                        "categories": L.number(selected.categoryTokens.count),
                        "websites": L.number(selected.webDomainTokens.count),
                    ])).font(F.xs).foregroundStyle(theme.p.s600)
                    SecondaryButton(title: L.t("dashboard.restrict")) {
                        Task {
                            screenTime.refreshAuthorization()
                            if !screenTime.authorized { await screenTime.requestAuthorization() }
                            guard screenTime.authorized else { authorizationError = true; return }
                            authorizationError = false
                            pickerMode = .earned
                        }
                    }
                }
                if authorizationError {
                    Text(L.t("dashboard.authorization_error")).font(F.xs).foregroundStyle(theme.p.s600)
                }
            }
        }
        .id(selectionRevision)
    }

    // MARK: - Children

    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(L.t("dashboard.family"), icon: "figure.2.and.child.holdinghands")
            TaskNotificationsCard()
            if let confirmation {
                Label(confirmation, systemImage: "checkmark.circle.fill")
                    .font(F.sm).foregroundStyle(theme.primary)
            }
            if loadingFamily && children.isEmpty {
                ProgressView().tint(theme.primary).frame(maxWidth: .infinity)
            } else if familyError {
                Text(L.t("dashboard.load_error")).font(F.sm).foregroundStyle(theme.mutedForeground)
                SecondaryButton(title: L.t("dashboard.retry")) { Task { await reload() } }
            } else if children.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "figure.2.and.child.holdinghands")
                        .font(.system(size: 36)).foregroundStyle(theme.primary)
                    Text(L.t("dashboard.empty_title")).font(F.sans(16, .semibold)).foregroundStyle(theme.foreground)
                    Text(L.t("dashboard.empty_desc")).font(F.sm).foregroundStyle(theme.mutedForeground)
                    PrimaryButton(title: L.t("parent.add_child")) { creatingChild = true }
                }
            } else {
                ForEach(children) { child in
                    childPreview(child)
                    if selectedChildID == child.id {
                        childCard(child).transition(.opacity)
                    }
                }
                if children.count < Self.maxChildren {
                    PrimaryButton(title: L.t("parent.add_child")) { creatingChild = true }
                } else {
                    Text(L.t("parent.child.limit_reached", ["max": "\(Self.maxChildren)"]))
                        .font(F.xs).foregroundStyle(theme.mutedForeground)
                }
            }
        }
    }

    private func childPreview(_ child: ChildRow) -> some View {
        let member = family.first { $0.member_id == child.id.uuidString.lowercased() || $0.member_id.lowercased() == child.id.uuidString.lowercased() }
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                childPanel = .overview
                selectedChildID = selectedChildID == child.id ? nil : child.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    AvatarBubble(avatar: child.avatar, name: child.name, size: 44)
                    Text(child.name).font(F.sans(16, .semibold)).foregroundStyle(theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: selectedChildID == child.id ? "chevron.up" : "chevron.down")
                        .foregroundStyle(theme.primary)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        childMetric(L.t("dashboard.steps"), member.map { L.number($0.steps) })
                        childMetric(L.t("dashboard.earned"), member?.earned_min.map { L.t("home2.minutes", ["n": L.number($0)]) })
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        childMetric(L.t("dashboard.steps"), member.map { L.number($0.steps) })
                        childMetric(L.t("dashboard.earned"), member?.earned_min.map { L.t("home2.minutes", ["n": L.number($0)]) })
                    }
                }
            }
            .padding(16).background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2))
            .overlay(RoundedRectangle(cornerRadius: R.xl2).strokeBorder(theme.border, lineWidth: 1))
        }
        .buttonStyle(FlatPress())
        .accessibilityLabel(L.t(selectedChildID == child.id ? "dashboard.collapse" : "dashboard.manage", ["name": child.name]))
    }

    private func childMetric(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(F.xs).foregroundStyle(theme.mutedForeground)
            Text(value ?? L.t("dashboard.unavailable")).font(F.sans(14, .medium)).foregroundStyle(theme.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func childCard(_ c: ChildRow) -> some View {
        let stats = c.auth_user_id.flatMap { today[$0] } ?? ChildDayStats()

        return VStack(alignment: .leading, spacing: 20) {
            SegmentedTabs(selection: $childPanel, items: [
                (.overview, L.t("dashboard.overview")),
                (.tasks, L.t("tasks.title")),
                (.settings, L.t("dashboard.child_settings")),
            ])
            switch childPanel {
            case .overview:
                HStack(spacing: 16) {
                    childMetric(L.t("parent.child.daily_goal"), L.number(c.daily_goal))
                    childMetric(L.t("parent.used_screentime"), L.duration(stats.usedMin))
                }
                WeeklySummary(week: c.auth_user_id.flatMap { week[$0] } ?? [:])
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(L.t("parent.gift.title"), icon: "gift")
                    Text(L.t("parent.gift.sub")).font(F.xs).foregroundStyle(theme.mutedForeground)
                    if stats.bonusMin > 0 {
                        Label(L.t("parent.gift.given_today", ["m": L.number(stats.bonusMin)]), systemImage: "checkmark.circle")
                            .font(F.xs).foregroundStyle(theme.primary)
                    }
                    PrimaryButton(title: L.t(c.auth_user_id != nil ? "parent.gift.cta" : "parent.gift.needs_join"),
                                  enabled: c.auth_user_id != nil) { gifting = c }
                }
                if c.invitation_status != "connected" { invitationBlock(c) }
            case .tasks:
                ChildTasksSection(childID: c.id, childName: c.name, parentID: parentID,
                                  canAssign: c.auth_user_id != nil && parentID != nil)
            case .settings:
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader(L.t("dashboard.child_settings"), icon: "person.crop.circle")
                    HStack(spacing: 12) {
                        AvatarBubble(avatar: c.avatar, name: c.name, size: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.name).font(F.sans(16, .semibold)).foregroundStyle(theme.foreground)
                            Text(Self.ageLabel(c.birthday)).font(F.xs).foregroundStyle(theme.mutedForeground)
                        }
                    }
                    SettingsRow(icon: "pencil", title: L.t("parent.child.edit")) { editing = c }
                    Divider().overlay(theme.border)
                    HStack(spacing: 16) {
                        childMetric(L.t("parent.steps_per_30"), L.number(c.steps_per_30))
                        childMetric(L.t("parent.daily_cap"), c.daily_cap_hours >= 24
                                    ? L.t("parent.no_cap") : L.duration(c.daily_cap_hours * 60))
                    }
                    SecondaryButton(title: L.t("parent.edit_screentime")) { editingChildST = c }
                    Text(L.t("dashboard.remote")).font(F.xs).foregroundStyle(theme.mutedForeground)
                    Divider().overlay(theme.border)
                    invitationBlock(c)
                    SettingsRow(icon: "trash", title: L.t("parent.child.delete"), destructive: true) { deleting = c }
                }
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
                        Text(L.t("parent.child.code")).font(F.xs).foregroundStyle(theme.mutedForeground)
                        Text(c.code).font(F.sans(20, .semibold)).monospacedDigit()
                            .foregroundStyle(theme.p.s900)
                    }
                    Spacer(minLength: 0)
                    Text(L.t(c.invitation_status == "expired"
                             ? "parent.child.status_expired" : "parent.child.status_pending"))
                        .font(F.sans(10, .semibold))
                        .foregroundStyle(theme.primary)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background((theme.primary).opacity(0.12),
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

            Text(L.t("parent.child.code_help")).font(F.xs).foregroundStyle(theme.p.s600)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Bits

    private func smallButton(_ icon: String, _ title: String, primary: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(title).font(F.sans(12, .semibold)).multilineTextAlignment(.center)
            }
            .foregroundStyle(primary ? theme.primaryForeground : theme.p.s700)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(primary ? theme.primary : theme.card,
                        in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.md, style: .continuous)
                .stroke(primary ? .clear : theme.p.s200, lineWidth: 1))
        }
        .buttonStyle(FlatPress())
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
        guard canManageChildren else { return }
        loadingFamily = true
        defer { loadingFamily = false }
        parentID = await SupabaseAPI.currentUserID()
        do {
            async let childRows = SupabaseAPI.children()
            async let members = SupabaseAPI.familyToday()
            children = try await childRows
            family = try await members
            familyError = false
            let activity = await SupabaseAPI.childActivity(children.compactMap(\.auth_user_id))
            today = activity.today
            week = activity.week
            if let selectedChildID, !children.contains(where: { $0.id == selectedChildID }) {
                self.selectedChildID = nil
            }
        } catch {
            familyError = true
        }
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
        // Fixed control width so every category row lines up identically.
        .frame(width: 188)
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
                Text(title).font(F.sans(12, .semibold)).multilineTextAlignment(.center).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(active ? .white : theme.p.s700)
            .padding(.vertical, 6)
            .background(active ? fill : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
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
