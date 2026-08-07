import SwiftUI

/// Port of `src/routes/parent.tsx` — child dashboard with today's stats,
/// weekly summary, tasks, gifting screen time and child management.
struct ParentView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @Binding var tab: AppTab

    @State private var children: [ChildRow] = []
    @State private var stepsByChild: [UUID: Int] = [:]
    @State private var tasks: [TaskRow] = []
    @State private var giftTarget: ChildRow?
    @State private var deleteTarget: ChildRow?
    @State private var showAddChild = false

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(eyebrow: L.t("parent.eyebrow"), title: L.t("parent.title")) {
                Button { showAddChild = true } label: {
                    ZStack {
                        Circle().fill(theme.primary)
                        Image(systemName: "plus").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.primaryForeground)
                    }
                    .frame(width: 40, height: 40)
                }
            }
            VStack(spacing: 20) {
                if children.isEmpty {
                    CardSurface(padding: 24) {
                        VStack(spacing: 10) {
                            Text(L.t("parent.no_children_title")).font(F.sans(16, .semibold))
                                .foregroundStyle(theme.p.s950)
                            Text(L.t("parent.no_children_desc")).font(F.sm)
                                .foregroundStyle(theme.p.s600).multilineTextAlignment(.center)
                            PrimaryButton(title: L.t("parent.add_child")) { showAddChild = true }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .rise()
                } else {
                    ForEach(Array(children.enumerated()), id: \.element.id) { i, c in
                        childCard(c).rise(delay: Double(i) * 0.06)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .task { await reload() }
        .sheet(item: $giftTarget) { c in
            GiftScreenTimeSheet(child: c) { await reload() }
        }
        .sheet(item: $deleteTarget) { c in
            DeleteChildSheet(child: c) { await reload() }
        }
        .sheet(isPresented: $showAddChild) {
            AddChildSheet { await reload() }
        }
    }

    private func reload() async {
        children = (try? await SupabaseAPI.children()) ?? []
        let ids = children.compactMap(\.auth_user_id)
        stepsByChild = (try? await SupabaseAPI.stepsFor(userIDs: ids)) ?? [:]
        tasks = (try? await SupabaseAPI.tasks()) ?? []
    }

    private func childCard(_ c: ChildRow) -> some View {
        let steps = c.auth_user_id.flatMap { stepsByChild[$0] } ?? 0
        let earned = min(steps / max(1, c.steps_per_30) * 30, c.daily_cap_hours > 0 ? c.daily_cap_hours * 60 : .max)
        let childTasks = tasks.filter { $0.child_id == c.id }
        return CardSurface(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    AvatarBubble(avatar: c.avatar, name: c.name, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.name).font(F.sans(16, .semibold)).foregroundStyle(theme.p.s950)
                        Text(c.username.map { "@\($0)" } ?? L.t("parent.pending"))
                            .font(F.text11).foregroundStyle(theme.p.s600)
                    }
                    Spacer()
                    Menu {
                        Button(L.t("parent.gift")) { giftTarget = c }
                        Button(L.t("parent.delete_child"), role: .destructive) { deleteTarget = c }
                    } label: {
                        Image(systemName: "ellipsis").foregroundStyle(theme.p.s600)
                            .frame(width: 32, height: 32)
                    }
                }

                HStack(spacing: 12) {
                    stat(L.t("parent.steps"), steps.formatted())
                    stat(L.t("parent.goal"), c.daily_goal.formatted())
                    stat(L.t("parent.screen"), SettingsStore.formatScreenMin(earned))
                }

                if !childTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.t("parent.tasks")).eyebrow(theme.p.s600)
                        ForEach(childTasks.prefix(4)) { t in
                            HStack(spacing: 8) {
                                Image(systemName: t.status == "approved" ? "checkmark.circle.fill"
                                      : t.status == "submitted" ? "clock" : "circle")
                                    .foregroundStyle(t.status == "approved" ? theme.p.s600 : theme.p.s300)
                                Text(t.title).font(F.sm).foregroundStyle(theme.p.s900)
                                Spacer()
                                Text("+\(t.reward_minutes)m").font(F.xs).tabularNums()
                                    .foregroundStyle(theme.p.s600)
                            }
                        }
                    }
                }

                WeeklySummary(childUserID: c.auth_user_id)
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).eyebrow(theme.p.s600)
            Text(value).font(F.sans(16, .semibold)).tabularNums().foregroundStyle(theme.p.s900)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.lg, style: .continuous))
    }
}

/// Weekly steps bars per child (port of the parent dashboard summary).
struct WeeklySummary: View {
    @EnvironmentObject var theme: Theme
    let childUserID: UUID?
    @State private var days: [(day: String, steps: Int)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t("parent.week")).eyebrow(theme.p.s600)
            HStack(alignment: .bottom, spacing: 6) {
                let maxV = max(1, days.map(\.steps).max() ?? 1)
                ForEach(days, id: \.day) { d in
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            VStack {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(theme.p.s600.opacity(0.8))
                                    .frame(height: max(2, geo.size.height * Double(d.steps) / Double(maxV)))
                            }
                        }
                        .frame(height: 56)
                        Text(StatsView.weekdayNarrow(d.day)).font(F.sans(9, .medium))
                            .foregroundStyle(theme.p.s600)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .task {
            guard let uid = childUserID else { return }
            struct Row: Codable { let day: String; let steps: Int }
            let rows: [Row] = (try? await supabase.from("activity_steps")
                .select("day,steps").eq("user_id", value: uid)
                .order("day", ascending: false).limit(7).execute().value) ?? []
            days = rows.reversed().map { ($0.day, $0.steps) }
        }
    }
}

struct GiftScreenTimeSheet: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let child: ChildRow
    let onDone: () async -> Void
    @State private var minutes: Double = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.t("parent.gift_title", ["n": child.name])).font(F.sans(18, .semibold))
                .foregroundStyle(theme.p.s950)
            SliderRow(title: L.t("parent.minutes"), valueLabel: "\(Int(minutes)) min",
                      value: $minutes, range: 5...180, step: 5)
            PrimaryButton(title: L.t("parent.gift")) {
                Task {
                    if let uid = child.auth_user_id {
                        try? await SupabaseAPI.giftScreenTime(childUserID: uid, minutes: Int(minutes))
                    }
                    await onDone(); dismiss()
                }
            }
            Spacer()
        }
        .padding(24)
        .background(theme.background)
        .presentationDetents([.height(280)])
        .presentationCornerRadius(28)
    }
}

struct DeleteChildSheet: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let child: ChildRow
    let onDone: () async -> Void
    @State private var password = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.t("parent.delete_child")).font(F.sans(18, .semibold))
                .foregroundStyle(theme.destructive)
            Text(L.t("parent.delete_desc", ["n": child.name])).font(F.sm)
                .foregroundStyle(theme.p.s600)
            SecureField(L.t("settings.password"), text: $password).fieldStyle()
            Button {
                busy = true
                Task {
                    if let email = try? await supabase.auth.user().email {
                        try? await supabase.auth.signIn(email: email, password: password)
                        try? await supabase.from("children").delete().eq("id", value: child.id).execute()
                    }
                    busy = false
                    await onDone(); dismiss()
                }
            } label: {
                Text(L.t("delete.confirm")).font(F.sans(14, .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .foregroundStyle(.white).background(theme.destructive, in: Capsule())
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

struct AddChildSheet: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let onDone: () async -> Void
    @State private var name = ""
    @State private var username = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.t("parent.add_child")).font(F.sans(18, .semibold)).foregroundStyle(theme.p.s950)
            TextField(L.t("parent.child_name"), text: $name).fieldStyle()
            TextField(L.t("parent.child_username"), text: $username)
                .fieldStyle().autocorrectionDisabled().textInputAutocapitalization(.never)
            if let error { Text(error).font(F.xs).foregroundStyle(theme.destructive) }
            PrimaryButton(title: L.t("common.save"), busy: busy) {
                busy = true
                Task {
                    do {
                        guard let uid = await SupabaseAPI.currentUserID() else { return }
                        let available = (try? await SupabaseAPI.usernameAvailable(username)) ?? false
                        guard available else { error = L.t("auth.username_taken"); busy = false; return }
                        try await supabase.from("children").insert([
                            "parent_id": AnyJSON.string(uid.uuidString),
                            "name": .string(name),
                            "username": .string(username),
                        ]).execute()
                        busy = false
                        await onDone(); dismiss()
                    } catch {
                        self.error = error.localizedDescription
                        busy = false
                    }
                }
            }
            Spacer()
        }
        .padding(24)
        .background(theme.background)
        .presentationDetents([.height(340)])
        .presentationCornerRadius(28)
    }
}
