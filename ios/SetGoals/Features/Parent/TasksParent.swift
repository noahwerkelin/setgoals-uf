import SwiftUI
import Supabase

/// Port of `src/components/TasksParent.tsx` and `TaskNotifications.tsx`.

struct StatusPill: View {
    @EnvironmentObject var theme: Theme
    let status: String
    var overdue = false

    private var color: Color {
        if overdue || status == "rejected" { return .red }
        if status == "approved" { return Color(red: 0.06, green: 0.72, blue: 0.51) }
        if status == "submitted" { return .orange }
        return theme.p.s700
    }

    var body: some View {
        Text(L.t(overdue ? "tasks.status.overdue" : "tasks.status.\(status)"))
            .font(F.sans(10, .semibold)).foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct ChildTasksSection: View {
    @EnvironmentObject var theme: Theme
    let childID: UUID
    let childName: String
    let parentID: UUID?
    let canAssign: Bool

    @State private var tasks: [TaskRow] = []
    @State private var filter = "all"
    @State private var editing: TaskRow?
    @State private var creating = false
    @State private var reviewing: TaskRow?

    private let filters = ["all", "pending", "submitted", "approved", "rejected", "overdue"]

    private var visible: [TaskRow] {
        tasks.filter { t in
            switch filter {
            case "all": return true
            case "overdue": return Self.isOverdue(t)
            default: return t.status == filter
            }
        }
    }

    private var awaiting: Int { tasks.filter { $0.status == "submitted" }.count }

    private var weekStats: (count: Int, minutes: Int) {
        let since = Date().addingTimeInterval(-7 * 86_400)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let done = tasks.filter {
            guard $0.status == "approved" else { return false }
            let raw = $0.approved_at ?? $0.updated_at ?? ""
            let d = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
            return (d ?? .distantPast) >= since
        }
        return (done.count, done.reduce(0) { $0 + $1.reward_minutes })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.clipboard").font(.system(size: 13)).foregroundStyle(theme.p.s700)
                Text(L.t("tasks.title")).font(F.sans(12, .semibold)).foregroundStyle(theme.p.s900)
                Spacer(minLength: 0)
                if awaiting > 0 {
                    Text(L.t("tasks.awaiting", ["n": "\(awaiting)"]))
                        .font(F.sans(10, .semibold)).foregroundStyle(.orange)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                }
            }

            Text(L.t("tasks.week_summary", ["n": "\(weekStats.count)", "m": "\(weekStats.minutes)"]))
                .font(F.text11).foregroundStyle(theme.p.s600)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(filters, id: \.self) { f in
                        Button { filter = f } label: {
                            Text(L.t("tasks.filter.\(f)"))
                                .font(F.sans(10, .semibold))
                                .foregroundStyle(filter == f ? theme.primaryForeground : theme.p.s700)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(filter == f ? theme.primary : theme.card, in: Capsule())
                                .overlay(Capsule().stroke(filter == f ? .clear : theme.p.s200, lineWidth: 1))
                        }
                    }
                }
                .padding(.bottom, 2)
            }

            if visible.isEmpty {
                Text(L.t("tasks.empty_parent")).font(F.text11).foregroundStyle(theme.p.s600)
            }

            ForEach(visible) { task in
                taskRow(task)
            }

            Button { creating = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                    Text(canAssign ? L.t("tasks.new") : L.t("tasks.needs_join")).font(F.sans(12, .semibold))
                }
                .foregroundStyle(theme.primaryForeground)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(theme.primary, in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
            }
            .disabled(!canAssign)
            .opacity(canAssign ? 1 : 0.5)
        }
        .padding(16)
        .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
            .stroke(theme.p.s200, lineWidth: 1))
        .task { await reload() }
        .sheet(item: $editing) { t in
            TaskEditDialog(task: t, parentID: parentID, childID: childID) { await reload() }
        }
        .sheet(isPresented: $creating) {
            TaskEditDialog(task: nil, parentID: parentID, childID: childID) { await reload() }
        }
        .sheet(item: $reviewing) { t in
            TaskReviewDialog(task: t, childName: childName) { await reload() }
        }
    }

    private func taskRow(_ task: TaskRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(F.sans(14, .semibold)).foregroundStyle(theme.p.s900).lineLimit(1)
                    Text(subtitle(task)).font(F.text11).foregroundStyle(theme.p.s600)
                }
                Spacer(minLength: 0)
                StatusPill(status: task.status, overdue: Self.isOverdue(task))
            }
            if task.status == "submitted" {
                Button { reviewing = task } label: {
                    Text(L.t("tasks.review")).font(F.sans(11, .semibold))
                        .foregroundStyle(theme.primaryForeground)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(theme.primary, in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
                }
            } else {
                HStack(spacing: 8) {
                    Button { editing = task } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil").font(.system(size: 11))
                            Text(L.t("tasks.edit")).font(F.sans(11, .semibold))
                        }
                        .foregroundStyle(theme.p.s700)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: R.md, style: .continuous)
                            .stroke(theme.p.s200, lineWidth: 1))
                    }
                    Button {
                        Task { try? await SupabaseAPI.deleteTask(task.id); await reload() }
                    } label: {
                        Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(theme.p.s700)
                            .frame(width: 36, height: 34)
                            .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: R.md, style: .continuous)
                                .stroke(theme.p.s200, lineWidth: 1))
                    }
                }
            }
        }
        .padding(12)
        .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
            .stroke(theme.p.s200, lineWidth: 1))
    }

    private func subtitle(_ t: TaskRow) -> String {
        var s = "+\(Self.formatReward(t.reward_minutes))"
        if let d = t.due_date { s += " · \(d)" }
        if let r = t.repeat_schedule, r != "none" { s += " · \(L.t("tasks.repeat.\(r)"))" }
        return s
    }

    static func formatReward(_ minutes: Int) -> String {
        minutes >= 60 && minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes)m"
    }

    static func isOverdue(_ t: TaskRow) -> Bool {
        guard let due = t.due_date, t.status == "pending" else { return false }
        return due < SupabaseAPI.localToday
    }

    private func reload() async {
        tasks = await SupabaseAPI.tasks(childID: childID)
    }
}

// MARK: - Task create / edit

struct TaskEditDialog: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let task: TaskRow?
    let parentID: UUID?
    let childID: UUID
    let onDone: () async -> Void

    @State private var title = ""
    @State private var desc = ""
    @State private var reward = 30
    @State private var due = ""
    @State private var hasDue = false
    @State private var repeatSchedule = "none"
    @State private var interval = 2
    @State private var priority = "normal"
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            AppDialog(title: L.t(task != nil ? "tasks.edit_title" : "tasks.new_title"),
                      description: L.t("tasks.new_sub")) {
                VStack(alignment: .leading, spacing: 14) {
                    labeled(L.t("tasks.field.title")) { TextField("", text: $title).fieldStyle() }
                    labeled(L.t("tasks.field.desc")) { TextField("", text: $desc).fieldStyle() }

                    HStack(spacing: 12) {
                        labeled(L.t("tasks.field.reward")) {
                            Stepper("\(reward) min", value: $reward, in: 0...600, step: 5)
                                .font(F.sm).foregroundStyle(theme.p.s900)
                        }
                    }

                    labeled(L.t("tasks.field.due")) {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $hasDue) { Text(L.t("tasks.field.due")).font(F.sm) }
                                .tint(theme.primary)
                            if hasDue {
                                DatePicker("", selection: dueBinding, displayedComponents: .date)
                                    .labelsHidden()
                            }
                        }
                    }

                    labeled(L.t("tasks.field.priority")) {
                        chips(["low", "normal", "high"], selected: priority, prefix: "tasks.priority.") {
                            priority = $0
                        }
                    }

                    labeled(L.t("tasks.field.repeat")) {
                        VStack(alignment: .leading, spacing: 8) {
                            chips(["none", "daily", "weekly", "custom"], selected: repeatSchedule,
                                  prefix: "tasks.repeat.") { repeatSchedule = $0 }
                            if repeatSchedule == "custom" {
                                Stepper("\(interval)", value: $interval, in: 1...365)
                                    .font(F.sm).foregroundStyle(theme.p.s900)
                            }
                        }
                    }

                    if let error { Text(error).font(F.xs).foregroundStyle(theme.destructive) }
                }
            } footer: {
                DialogFooterButtons(cancelTitle: L.t("settings.cancel"),
                                    confirmTitle: L.t("tasks.save"),
                                    disabled: busy || title.trimmingCharacters(in: .whitespaces).isEmpty,
                                    onCancel: { dismiss() },
                                    onConfirm: { Task { await save() } })
            }
        }
        .background(theme.card)
        .presentationCornerRadius(R.xl3)
        .presentationDetents([.large])
        .onAppear(perform: seed)
    }

    private func labeled<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).eyebrow(theme.p.s600)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chips(_ values: [String], selected: String, prefix: String,
                       onSelect: @escaping (String) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(values, id: \.self) { v in
                Button { onSelect(v) } label: {
                    Text(L.t(prefix + v)).font(F.sans(11, .semibold))
                        .foregroundStyle(selected == v ? theme.primaryForeground : theme.p.s700)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(selected == v ? theme.primary : theme.p.s50,
                                    in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: R.md, style: .continuous)
                            .stroke(selected == v ? .clear : theme.p.s200, lineWidth: 1))
                }
            }
        }
    }

    private var dueBinding: Binding<Date> {
        Binding(
            get: {
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
                return f.date(from: due) ?? Date()
            },
            set: { due = SupabaseAPI.dayKey($0) }
        )
    }

    private func seed() {
        guard let t = task else { return }
        title = t.title
        desc = t.description ?? ""
        reward = t.reward_minutes
        due = t.due_date ?? ""
        hasDue = t.due_date != nil
        repeatSchedule = t.repeat_schedule ?? "none"
        interval = t.repeat_interval_days ?? 2
        priority = t.priority ?? "normal"
    }

    private func save() async {
        let name = title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        busy = true
        defer { busy = false }
        let dueValue: String? = hasDue ? (due.isEmpty ? SupabaseAPI.localToday : due) : nil
        do {
            if let t = task {
                try await SupabaseAPI.updateTask(t.id, [
                    "title": .string(name),
                    "description": desc.isEmpty ? .null : .string(desc),
                    "reward_minutes": .integer(reward),
                    "due_date": dueValue.map { AnyJSON.string($0) } ?? .null,
                    "repeat_schedule": .string(repeatSchedule),
                    "repeat_interval_days": repeatSchedule == "custom" ? .integer(interval) : .null,
                    "priority": .string(priority),
                ])
            } else {
                guard let pid = parentID else { return }
                try await SupabaseAPI.createTask(parentID: pid, childID: childID, title: name,
                                                 description: desc, rewardMinutes: reward,
                                                 dueDate: dueValue, repeatSchedule: repeatSchedule,
                                                 repeatIntervalDays: interval, priority: priority)
            }
            await onDone()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Review submitted task

struct TaskReviewDialog: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let task: TaskRow
    let childName: String
    let onDone: () async -> Void

    @State private var reason = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            AppDialog(title: L.t("tasks.review_title"),
                      description: L.t("tasks.review_sub", ["name": childName.isEmpty ? "—" : childName,
                                                            "title": task.title])) {
                VStack(alignment: .leading, spacing: 12) {
                    infoBox("\(L.t("tasks.reward_label")): +\(ChildTasksSection.formatReward(task.reward_minutes))")
                    if let note = task.proof_note, !note.isEmpty { infoBox(note) }
                    if let img = task.proof_image_url, let url = URL(string: img) {
                        AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { theme.p.s100 }
                            .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L.t("tasks.reject_reason")).eyebrow(theme.p.s600)
                        TextField("", text: $reason).fieldStyle()
                    }
                    if let error { Text(error).font(F.xs).foregroundStyle(theme.destructive) }
                }
            } footer: {
                HStack(spacing: 8) {
                    Spacer()
                    Button {
                        busy = true
                        Task {
                            do {
                                try await SupabaseAPI.rejectTask(task, reason: reason.trimmingCharacters(in: .whitespaces))
                                await onDone(); dismiss()
                            } catch { self.error = error.localizedDescription; busy = false }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle").font(.system(size: 13))
                            Text(L.t("tasks.reject")).font(F.sans(14, .semibold))
                        }
                        .foregroundStyle(theme.p.s700)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    .disabled(busy)
                    Button {
                        busy = true
                        Task {
                            do {
                                _ = try await SupabaseAPI.approveTask(task)
                                await onDone(); dismiss()
                            } catch { self.error = error.localizedDescription; busy = false }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle").font(.system(size: 13))
                            Text(L.t("tasks.approve")).font(F.sans(14, .semibold))
                        }
                        .foregroundStyle(theme.primaryForeground)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(theme.primary, in: Capsule())
                    }
                    .disabled(busy)
                }
            }
        }
        .background(theme.card)
        .presentationCornerRadius(R.xl3)
        .presentationDetents([.medium, .large])
    }

    private func infoBox(_ text: String) -> some View {
        Text(text).font(F.xs).foregroundStyle(theme.p.s700)
            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                .stroke(theme.p.s200, lineWidth: 1))
    }
}

// MARK: - Notifications

struct TaskNotificationsCard: View {
    @EnvironmentObject var theme: Theme
    @State private var items: [TaskNotificationRow] = []

    var body: some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L.t("tasks.notif.title")).font(F.sans(12, .semibold)).foregroundStyle(theme.p.s900)
                    ForEach(items) { n in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "bell.fill").font(.system(size: 11)).foregroundStyle(theme.p.s700)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L.t("tasks.notif.\(n.type.replacingOccurrences(of: "task_", with: ""))"))
                                    .font(F.sans(11, .semibold)).foregroundStyle(theme.p.s900)
                                Text(n.title).font(F.text11).foregroundStyle(theme.p.s600)
                            }
                            Spacer(minLength: 0)
                            Button {
                                Task { await SupabaseAPI.markNotificationRead(n.id); await reload() }
                            } label: {
                                Text(L.t("tasks.notif.mark_read")).font(F.sans(10, .semibold))
                                    .foregroundStyle(theme.p.s700)
                            }
                        }
                    }
                }
                .padding(16)
                .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                    .stroke(.black.opacity(0.05), lineWidth: 1))
            }
        }
        .task { await reload() }
    }

    private func reload() async { items = await SupabaseAPI.taskNotifications() }
}
