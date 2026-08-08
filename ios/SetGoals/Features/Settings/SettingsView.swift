import SwiftUI
import Supabase

/// 1:1 port of `src/routes/settings.tsx`.
/// Sections, order, copy and interaction match the web page exactly:
/// PRO card → theme → earning rules → integrations → privacy →
/// account & language → support → version footer.
struct SettingsView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @Binding var tab: AppTab

    @AppStorage("app.lang") private var lang: String = L.lang

    @State private var stepsOpen = false
    @State private var capOpen = false
    @State private var goalOpen = false
    @State private var themeOpen = false
    @State private var proOpen = false
    @State private var connectKind: String?
    @State private var nicknameOpen = false
    @State private var usernameOpen = false
    @State private var emailOpen = false
    @State private var passwordOpen = false
    @State private var reportOpen = false
    @State private var deleteOpen = false

    private var isChild: Bool { settings.role == "child" }

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(title: L.t("settings.title")) { EmptyView() }
            VStack(spacing: 24) {
                proCard
                themeGroup
                if !isChild { earningGroup }
                integrationsGroup
                privacyGroup
                accountGroup
                supportGroup
                Text("SetGoals · v1.0.0")
                    .font(F.text11).foregroundStyle(theme.p.s600)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
            }
            .padding(.horizontal, 24)
        }
        .id(lang)
        .sheet(isPresented: $proOpen) { ProUpgradeDialog() }
        .sheet(isPresented: $themeOpen) { ThemePickerDialog() }
        .sheet(isPresented: $goalOpen) {
            SliderDialog(title: L.t("settings.daily_goal"), initial: settings.dailyGoal,
                         min: 2000, max: 25000, step: 500, unit: L.t("settings.steps")) { v in
                settings.dailyGoal = v
                Task { try? await SupabaseAPI.updateSettings(["daily_goal": .integer(v)]) }
            }
        }
        .sheet(isPresented: $stepsOpen) {
            SliderDialog(title: L.t("settings.steps_per_30"), initial: settings.stepsPer30,
                         min: 200, max: 3000, step: 100) { v in
                settings.stepsPer30 = v
                Task { try? await SupabaseAPI.updateSettings(["steps_per_30": .integer(v)]) }
            }
        }
        .sheet(isPresented: $capOpen) {
            SliderDialog(title: L.t("settings.daily_cap"), initial: settings.dailyCapHours,
                         min: 1, max: 8, step: 1, unit: L.t("settings.hours"),
                         unlimited: (24, L.t("parent.no_cap"))) { v in
                settings.dailyCapHours = v
                Task { try? await SupabaseAPI.updateSettings(["daily_cap_hours": .integer(v)]) }
            }
        }
        .sheet(item: Binding(get: { connectKind.map(IdentifiedString.init) },
                             set: { connectKind = $0?.value })) { k in
            HealthConnectDialog(kind: k.value) {
                if k.value == "hk" {
                    settings.healthkitConnected = true
                    Task { try? await SupabaseAPI.updateSettings(["healthkit_connected": .bool(true)]) }
                } else {
                    settings.googlefitConnected = true
                    Task { try? await SupabaseAPI.updateSettings(["googlefit_connected": .bool(true)]) }
                }
            }
        }
        .sheet(isPresented: $nicknameOpen) {
            NicknameDialog(current: settings.displayName) { v in
                settings.displayName = v
                Task { try? await SupabaseAPI.updateProfile(["display_name": .string(v)]) }
            }
        }
        .sheet(isPresented: $usernameOpen) {
            UsernameDialog(current: settings.username) { v in
                settings.username = v
                Task { try? await SupabaseAPI.updateProfile(["username": .string(v)]) }
            }
        }
        .sheet(isPresented: $emailOpen) {
            EmailDialog(current: settings.email) { v in
                do {
                    try await supabase.auth.update(user: UserAttributes(email: v))
                    settings.email = v
                    return nil
                } catch { return error.localizedDescription }
            }
        }
        .sheet(isPresented: $passwordOpen) {
            PasswordDialog { v in
                do {
                    try await supabase.auth.update(user: UserAttributes(password: v))
                    return nil
                } catch { return error.localizedDescription }
            }
        }
        .sheet(isPresented: $reportOpen) { ReportProblemDialog() }
        .sheet(isPresented: $deleteOpen) { DeleteAccountDialog() }
    }

    // MARK: - PRO card

    @ViewBuilder private var proCard: some View {
        if !isChild {
            Button { proOpen = true } label: { proCardBody(filled: settings.isPro) }
        } else {
            proCardBody(filled: false)
        }
    }

    private func proCardBody(filled: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 20))
                .foregroundStyle(filled ? .white : theme.p.s700)
                .frame(width: 40, height: 40)
                .background(filled ? Color.white.opacity(0.15) : theme.p.s100,
                            in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(L.t("pro.title")).font(F.sans(14, .semibold))
                    .foregroundStyle(filled ? .white : theme.p.s950)
                Text(proSubtitle)
                    .font(F.xs)
                    .foregroundStyle(filled ? Color.white.opacity(0.8) : theme.p.s600)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            if !isChild {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(filled ? .white : theme.p.s700)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(filled ? theme.p.s600 : theme.card,
                    in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
            .strokeBorder(filled ? theme.p.s700.opacity(0.4) : theme.ringBorder, lineWidth: 1))
        .rise()
    }

    private var proSubtitle: String {
        if isChild {
            if settings.parentFamilyCancelling, let ends = settings.parentFamilyEndsAt {
                return L.t("pro.child_ending", ["date": Formatters.date(ends)])
            }
            return settings.isPro ? L.t("pro.child_active") : L.t("pro.child_desc")
        }
        if settings.isPro {
            if let ends = settings.proExpiresAt {
                return L.t("pro.status.ends_on_short", ["date": Formatters.date(ends)])
            }
            return L.t("pro.active")
        }
        return L.t("pro.subtitle")
    }

    // MARK: - Theme

    private var themeGroup: some View {
        group(L.t("theme.title")) {
            Button { if settings.isPro { themeOpen = true } else { proOpen = true } } label: {
                HStack(spacing: 12) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 18)).foregroundStyle(theme.p.s700)
                        .frame(width: 40, height: 40)
                        .background(theme.p.s100, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("theme.\(settings.isPro ? settings.themeColor.rawValue : "sage")"))
                            .font(F.sans(14, .semibold)).foregroundStyle(theme.p.s950)
                        Text(settings.isPro ? L.t("theme.desc")
                             : (isChild ? L.t("pro.child_desc") : L.t("pro.unlock")))
                            .font(F.xs).foregroundStyle(theme.p.s600)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        ForEach(Array(ThemeColor.allCases.prefix(5))) { c in
                            Circle().fill(SagePalette.table[c]!.s600)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().strokeBorder(.black.opacity(0.1), lineWidth: 1))
                        }
                    }
                    Image(systemName: settings.isPro ? "chevron.right" : "lock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.p.s600)
                }
                .padding(16)
            }
        }
    }

    // MARK: - Earning rules

    private var earningGroup: some View {
        group(L.t("settings.earning")) {
            row(L.t("settings.daily_goal"),
                meta: "\(settings.dailyGoal.formatted()) \(L.t("settings.steps"))") { goalOpen = true }
            divider
            row(L.t("settings.steps_per_30"), meta: settings.stepsPer30.formatted()) { stepsOpen = true }
            divider
            row(L.t("settings.daily_cap"),
                meta: settings.dailyCapHours >= 24
                    ? L.t("parent.no_cap")
                    : "\(settings.dailyCapHours)\(L.t("settings.hours"))") { capOpen = true }
        }
    }

    // MARK: - Integrations

    private var integrationsGroup: some View {
        group(L.t("settings.integrations")) {
            integrationRow(icon: "iphone", label: L.t("settings.healthkit"),
                           connected: settings.healthkitConnected) {
                if settings.healthkitConnected {
                    settings.healthkitConnected = false
                    Task { try? await SupabaseAPI.updateSettings(["healthkit_connected": .bool(false)]) }
                } else { connectKind = "hk" }
            }
            divider
            integrationRow(icon: "figure.walk", label: L.t("settings.googlefit"),
                           connected: settings.googlefitConnected) {
                if settings.googlefitConnected {
                    settings.googlefitConnected = false
                    Task { try? await SupabaseAPI.updateSettings(["googlefit_connected": .bool(false)]) }
                } else { connectKind = "gf" }
            }
            divider
            toggleRow(L.t("settings.push"), isOn: Binding(
                get: { settings.pushOn },
                set: { v in
                    settings.pushOn = v
                    Task { try? await SupabaseAPI.updateSettings(["push_on": .bool(v)]) }
                }))
        }
    }

    // MARK: - Privacy

    private var privacyGroup: some View {
        group(L.t("settings.privacy")) {
            toggleRow(L.t("settings.anon_lb"), isOn: Binding(
                get: { settings.anonymousLeaderboard },
                set: { v in
                    settings.anonymousLeaderboard = v
                    Task { try? await SupabaseAPI.updateSettings(["anonymous_leaderboard": .bool(v)]) }
                }))
            divider
            selectRow(L.t("settings.share_loc"),
                      value: settings.shareLocation,
                      options: [("off", L.t("settings.off")),
                                ("while_using", L.t("settings.while_using")),
                                ("always", L.t("settings.on"))]) { v in
                settings.shareLocation = v
                Task { try? await SupabaseAPI.updateSettings(["share_location": .string(v)]) }
            }
        }
    }

    // MARK: - Account & language

    private var accountGroup: some View {
        group(L.t("settings.account")) {
            selectRow(L.t("settings.language"), value: lang,
                      options: [("en", "English"), ("sv", "Svenska")]) { v in lang = v }
            divider
            selectRow(L.t("units.label"), value: settings.units,
                      options: [("metric", L.t("units.metric")), ("imperial", L.t("units.imperial"))]) { v in
                settings.units = v
                Task { try? await SupabaseAPI.updateSettings(["units": .string(v)]) }
            }
            divider
            row(L.t("settings.nickname"), meta: settings.displayName) { nicknameOpen = true }
            divider
            row(L.t("settings.username"), meta: "@\(settings.username)") { usernameOpen = true }
            if !isChild {
                divider
                row(L.t("settings.email"), meta: settings.email) { emailOpen = true }
                divider
                row(L.t("settings.password"), meta: "••••••••") { passwordOpen = true }
            }
            divider
            row(L.t("settings.signout")) { Task { await AuthStore.shared.signOut() } }
        }
    }

    // MARK: - Support

    private var supportGroup: some View {
        group(L.t("settings.support")) {
            row(L.t("settings.report_problem")) { reportOpen = true }
            if !isChild {
                divider
                row(L.t("settings.delete_account"), danger: true) { deleteOpen = true }
            }
        }
    }

    // MARK: - Building blocks (Group / Row / ToggleRow / SelectRow / IntegrationRow)

    private var divider: some View {
        Rectangle().fill(theme.p.s100).frame(height: 1)
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(F.sans(11, .semibold)).textCase(.uppercase).tracking(1.4)
                .foregroundStyle(theme.p.s600).padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .frame(maxWidth: .infinity)
                .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                    .strokeBorder(theme.ringBorder, lineWidth: 1))
        }
        .rise()
    }

    private func row(_ label: String, meta: String? = nil, danger: Bool = false,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).font(F.sans(14, .medium))
                    .foregroundStyle(danger ? theme.destructive : theme.p.s950)
                Spacer(minLength: 12)
                HStack(spacing: 4) {
                    if let meta {
                        Text(meta).font(F.sans(12, .medium)).lineLimit(1).truncationMode(.middle)
                    }
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(danger ? theme.destructive : theme.p.s600)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label).font(F.sans(14, .medium)).foregroundStyle(theme.p.s950)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(theme.primary)
        }
        .padding(16)
    }

    private func selectRow(_ label: String, value: String,
                           options: [(String, String)],
                           onChange: @escaping (String) -> Void) -> some View {
        HStack(spacing: 12) {
            Text(label).font(F.sans(14, .medium)).foregroundStyle(theme.p.s950)
            Spacer()
            Menu {
                ForEach(options, id: \.0) { opt in
                    Button { onChange(opt.0) } label: {
                        if opt.0 == value { Label(opt.1, systemImage: "checkmark") } else { Text(opt.1) }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(options.first { $0.0 == value }?.1 ?? value)
                        .font(F.sans(12, .medium))
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(theme.p.s700)
                .padding(.horizontal, 12).frame(height: 32)
                .frame(minWidth: 120)
                .background(theme.p.s100, in: RoundedRectangle(cornerRadius: R.sm, style: .continuous))
            }
        }
        .padding(16)
    }

    private func integrationRow(icon: String, label: String, connected: Bool,
                                action: @escaping () -> Void) -> some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 15))
                    .foregroundStyle(theme.p.s700)
                    .frame(width: 32, height: 32)
                    .background(theme.p.s100, in: RoundedRectangle(cornerRadius: R.lg, style: .continuous))
                Text(label).font(F.sans(14, .medium)).foregroundStyle(theme.p.s950)
            }
            Spacer()
            Button(action: action) {
                Text(connected ? L.t("settings.connected") : L.t("settings.connect"))
                    .font(F.sans(12, .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .foregroundStyle(connected ? theme.p.s700 : theme.primaryForeground)
                    .background(connected ? theme.p.s100 : theme.primary, in: Capsule())
            }
        }
        .padding(16)
    }
}

/// Wraps a `String` so it can drive `.sheet(item:)`.
struct IdentifiedString: Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}
