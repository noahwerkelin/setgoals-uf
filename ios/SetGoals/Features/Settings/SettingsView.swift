import SwiftUI

/// Port of `src/routes/settings.tsx` — account, screen-time rules,
/// categories, appearance (PRO themes), PRO management and support.
struct SettingsView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @Binding var tab: AppTab

    @State private var goal: Double = 8000
    @State private var per30: Double = 1000
    @State private var cap: Double = 3
    @State private var restrictions: [RestrictionRow] = []
    @State private var showNickname = false
    @State private var showEmail = false
    @State private var showPassword = false
    @State private var showReport = false
    @State private var showDelete = false
    @State private var saving = false

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(eyebrow: L.t("settings.eyebrow"), title: L.t("settings.title")) { EmptyView() }
            VStack(spacing: 24) {
                accountSection
                screenTimeSection
                categoriesSection
                appearanceSection
                proSection
                supportSection
            }
            .padding(.horizontal, 24)
        }
        .task {
            goal = Double(settings.dailyGoal)
            per30 = Double(settings.stepsPer30)
            cap = Double(settings.dailyCapHours)
            restrictions = (try? await SupabaseAPI.restrictions()) ?? []
        }
        .sheet(isPresented: $showNickname) { EditFieldSheet(title: L.t("settings.nickname"), initial: settings.displayName) { v in
            try? await SupabaseAPI.updateProfile(["display_name": .string(v)]); settings.displayName = v
        } }
        .sheet(isPresented: $showEmail) { EditFieldSheet(title: L.t("settings.email"), initial: "") { v in
            try? await supabase.auth.update(user: UserAttributes(email: v))
        } }
        .sheet(isPresented: $showPassword) { EditFieldSheet(title: L.t("settings.password"), initial: "", secure: true) { v in
            try? await supabase.auth.update(user: UserAttributes(password: v))
        } }
        .sheet(isPresented: $showReport) { ReportProblemSheet() }
        .sheet(isPresented: $showDelete) { DeleteAccountSheet() }
    }

    // MARK: Account

    private var accountSection: some View {
        group(L.t("settings.account")) {
            SettingsRow(icon: "person", title: L.t("settings.nickname"), subtitle: settings.displayName) { showNickname = true }
            divider
            SettingsRow(icon: "at", title: L.t("settings.username"), subtitle: "@\(settings.username)") { }
            divider
            SettingsRow(icon: "envelope", title: L.t("settings.email")) { showEmail = true }
            divider
            SettingsRow(icon: "key", title: L.t("settings.password")) { showPassword = true }
        }
    }

    // MARK: Screen time

    private var screenTimeSection: some View {
        group(settings.role == "individual" ? L.t("settings.screentime") : L.t("settings.screentime")) {
            VStack(alignment: .leading, spacing: 20) {
                SliderRow(title: L.t("settings.daily_goal"), valueLabel: Int(goal).formatted(),
                          value: $goal, range: 2000...25000, step: 500)
                SliderRow(title: L.t("settings.steps_per_30"), valueLabel: Int(per30).formatted(),
                          value: $per30, range: 250...5000, step: 250)
                SliderRow(title: L.t("settings.cap"),
                          valueLabel: cap == 0 ? "∞" : "\(Int(cap)) h",
                          value: $cap, range: 0...12, step: 1)
                Text(currentRuleText).font(F.xs).foregroundStyle(theme.p.s600)
                PrimaryButton(title: saving ? L.t("common.saving") : L.t("common.save"), busy: saving) {
                    Task { await save() }
                }
            }
            .padding(12)
        }
    }

    private var currentRuleText: String {
        let capText = cap == 0 ? L.t("settings.no_cap") : L.t("settings.max_h", ["h": "\(Int(cap))"])
        return L.t("settings.rule_line", [
            "steps": Int(per30).formatted(), "cap": capText,
        ])
    }

    private func save() async {
        saving = true
        try? await SupabaseAPI.updateSettings([
            "daily_goal": .integer(Int(goal)),
            "steps_per_30": .integer(Int(per30)),
            "daily_cap_hours": .integer(Int(cap)),
        ])
        settings.dailyGoal = Int(goal)
        settings.stepsPer30 = Int(per30)
        settings.dailyCapHours = Int(cap)
        saving = false
    }

    // MARK: Categories (Apple ScreenTime categories)

    private var categoriesSection: some View {
        group(L.t("settings.categories")) {
            VStack(spacing: 0) {
                ForEach(Array(restrictions.enumerated()), id: \.element.id) { i, r in
                    if i > 0 { divider }
                    HStack {
                        Text(r.label).font(F.sm).foregroundStyle(theme.p.s900)
                        Spacer()
                        PermissionPills(alwaysAllow: Binding(
                            get: { !r.active },
                            set: { newValue in
                                restrictions[i].active = !newValue
                                Task { try? await SupabaseAPI.setRestriction(id: r.id, active: !newValue) }
                            }))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 12)
                }
                if restrictions.isEmpty {
                    Text(L.t("settings.no_categories")).font(F.sm)
                        .foregroundStyle(theme.p.s600).padding(12)
                }
            }
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        group(L.t("settings.appearance")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ForEach(ThemeColor.allCases) { c in
                        Button {
                            guard settings.isPro else { return }
                            settings.themeColor = c
                            theme.color = c
                            Task { try? await SupabaseAPI.updateSettings(["theme_color": .string(c.rawValue)]) }
                        } label: {
                            ZStack {
                                Circle().fill(SagePalette.table[c]!.s600)
                                if theme.color == c {
                                    Circle().strokeBorder(.white, lineWidth: 3)
                                }
                            }
                            .frame(width: 34, height: 34)
                            .overlay(Circle().strokeBorder(theme.ringBorder, lineWidth: 1))
                            .opacity(settings.isPro ? 1 : 0.4)
                        }
                    }
                }
                if !settings.isPro {
                    Text(settings.role == "child" ? L.t("pro.child_desc") : L.t("settings.theme_locked"))
                        .font(F.xs).foregroundStyle(theme.p.s600)
                }
            }
            .padding(12)
        }
    }

    // MARK: PRO

    private var proSection: some View {
        group("SetGoals PRO") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(settings.isPro ? L.t("pro.active") : L.t("pro.inactive"))
                        .font(F.sans(14, .semibold)).foregroundStyle(theme.p.s900)
                    Spacer()
                    Text(settings.proPlan).font(F.xs).foregroundStyle(theme.p.s600)
                }
                Text(settings.isPro ? L.t("pro.manage_desc") : L.t("pro.upsell"))
                    .font(F.sm).foregroundStyle(theme.p.s600)
            }
            .padding(12)
        }
    }

    // MARK: Support

    private var supportSection: some View {
        group(L.t("settings.support")) {
            SettingsRow(icon: "exclamationmark.bubble", title: L.t("settings.report")) { showReport = true }
            divider
            SettingsRow(icon: "trash", title: L.t("settings.delete_account"), destructive: true) { showDelete = true }
        }
    }

    // MARK: Helpers

    private var divider: some View { Divider().overlay(theme.p.s100) }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).eyebrow(theme.p.s600)
            CardSurface(padding: 8) { VStack(spacing: 0) { content() } }
        }
        .rise()
    }
}

struct EditFieldSheet: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let title: String
    @State var initial: String
    var secure = false
    let onSave: (String) async -> Void
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(F.sans(18, .semibold)).foregroundStyle(theme.p.s950)
            if secure {
                SecureField(title, text: $initial).fieldStyle()
            } else {
                TextField(title, text: $initial).fieldStyle().autocorrectionDisabled()
            }
            PrimaryButton(title: L.t("common.save"), busy: busy) {
                busy = true
                Task { await onSave(initial); busy = false; dismiss() }
            }
            Spacer()
        }
        .padding(24)
        .background(theme.background)
        .presentationDetents([.height(260)])
        .presentationCornerRadius(28)
    }
}

struct ReportProblemSheet: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.t("settings.report")).font(F.sans(18, .semibold)).foregroundStyle(theme.p.s950)
            Text(L.t("report.desc")).font(F.sm).foregroundStyle(theme.p.s600)
            TextEditor(text: $text)
                .font(F.sm).frame(height: 120).scrollContentBackground(.hidden)
                .padding(8)
                .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                    .strokeBorder(theme.ringBorder, lineWidth: 1))
            PrimaryButton(title: L.t("report.send")) {
                let subject = "SetGoals — \(L.t("settings.report"))"
                let body = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "mailto:support@setgoals.app?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body)") {
                    UIApplication.shared.open(url)
                }
                Task { await SupabaseAPI.awardBadge("reporter") }
                dismiss()
            }
            Spacer()
        }
        .padding(24)
        .background(theme.background)
        .presentationDetents([.height(400)])
        .presentationCornerRadius(28)
    }
}

struct DeleteAccountSheet: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.t("settings.delete_account")).font(F.sans(18, .semibold))
                .foregroundStyle(theme.destructive)
            Text(L.t("delete.desc")).font(F.sm).foregroundStyle(theme.p.s600)
            SecureField(L.t("settings.password"), text: $password).fieldStyle()
            Button {
                busy = true
                Task {
                    if let email = try? await supabase.auth.user().email {
                        try? await supabase.auth.signIn(email: email, password: password)
                        if let uid = await SupabaseAPI.currentUserID() {
                            try? await supabase.from("account_deletion_requests")
                                .insert(["user_id": AnyJSON.string(uid.uuidString)]).execute()
                        }
                        await AuthStore.shared.signOut()
                    }
                    busy = false
                    dismiss()
                }
            } label: {
                Text(L.t("delete.confirm"))
                    .font(F.sans(14, .semibold)).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(theme.destructive, in: Capsule())
            }
            .disabled(busy || password.isEmpty)
            Spacer()
        }
        .padding(24)
        .background(theme.background)
        .presentationDetents([.height(320)])
        .presentationCornerRadius(28)
    }
}
