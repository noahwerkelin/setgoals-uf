import SwiftUI
import PhotosUI
import UIKit

/// 1:1 port of `src/components/TasksChild.tsx` — child-side task list with
/// submit-for-approval flow. Renders nothing when there are no tasks.
struct MyTasksCard: View {
    @EnvironmentObject var theme: Theme

    @State private var tasks: [TaskRow] = []
    @State private var submitting: TaskRow?

    private var mine: [TaskRow] { tasks }
    private var open: [TaskRow] { mine.filter { $0.status != "approved" && $0.status != "expired" } }
    private var done: [TaskRow] { mine.filter { $0.status == "approved" } }
    private var earned: Int { done.reduce(0) { $0 + $1.reward_minutes } }

    var body: some View {
        Group {
            if !mine.isEmpty {
                CardSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet.clipboard")
                                .font(.system(size: 14)).foregroundStyle(theme.p.s700)
                            Text(L.t("tasks.child.title"))
                                .font(F.sans(14, .semibold)).foregroundStyle(theme.foreground)
                            Spacer(minLength: 0)
                            if earned > 0 {
                                Text(L.t("tasks.child.earned", ["m": "\(earned)"]))
                                    .font(F.sans(10, .semibold))
                                    .foregroundStyle(Color(red: 0.02, green: 0.47, blue: 0.34))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color(red: 0.82, green: 0.96, blue: 0.90), in: Capsule())
                            }
                        }
                        VStack(spacing: 8) {
                            ForEach(open.isEmpty ? done : open) { row($0) }
                        }
                    }
                }
            }
        }
        .task { await reload() }
        .sheet(item: $submitting) { task in
            TaskSubmitDialog(task: task) {
                submitting = nil
                Task { await reload() }
            }
            .environmentObject(theme)
        }
    }

    private func row(_ task: TaskRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(F.sans(14, .semibold)).foregroundStyle(theme.p.s900)
                        .lineLimit(1)
                    if let d = task.description, !d.isEmpty {
                        Text(d).font(F.sans(11, .regular)).foregroundStyle(theme.p.s600)
                    }
                    Text("+\(ChildTasksSection.formatReward(task.reward_minutes))"
                         + (task.due_date.map { " · \($0)" } ?? ""))
                        .font(F.sans(11, .medium)).foregroundStyle(theme.p.s700)
                    if task.status == "rejected", let r = task.rejection_reason, !r.isEmpty {
                        Text(r).font(F.sans(11, .regular)).foregroundStyle(.red)
                    }
                }
                Spacer(minLength: 0)
                StatusPill(status: task.status, overdue: ChildTasksSection.isOverdue(task))
            }
            if task.status == "pending" || task.status == "rejected" {
                Button { submitting = task } label: {
                    Text(L.t("tasks.child.complete"))
                        .font(F.sans(11, .semibold))
                        .foregroundStyle(theme.primaryForeground)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(theme.p.s600, in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
                }
            } else if task.status == "submitted" {
                Text(L.t("tasks.child.waiting"))
                    .font(F.sans(11, .regular)).foregroundStyle(theme.p.s600)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                .strokeBorder(theme.p.s200, lineWidth: 1)
        )
    }

    private func reload() async {
        guard let me = await SupabaseAPI.currentUserID() else { return }
        let all = (try? await SupabaseAPI.tasks()) ?? []
        tasks = all.filter { $0.child_user_id == me }
    }
}

// MARK: - Submit dialog

private struct TaskSubmitDialog: View {
    @EnvironmentObject var theme: Theme
    let task: TaskRow
    var onClose: () -> Void

    @State private var note = ""
    @State private var photo: String?
    @State private var photoImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var busy = false

    var body: some View {
        AppDialog(
            title: L.t("tasks.child.submit_title"),
            description: L.t("tasks.child.submit_sub", ["title": task.title])
        ) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.t("tasks.child.note")).font(F.sans(12, .medium))
                        .foregroundStyle(theme.p.s700)
                    TextField("", text: $note).fieldStyle()
                }
                if let img = photoImage {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera").font(.system(size: 14))
                        Text(L.t("tasks.child.photo")).font(F.sans(12, .semibold))
                    }
                    .foregroundStyle(theme.p.s700)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: R.md, style: .continuous)
                            .strokeBorder(theme.p.s200, lineWidth: 1)
                    )
                }
            }
        } footer: {
            HStack(spacing: 8) {
                Button(L.t("settings.cancel")) { onClose() }
                    .font(F.sans(14, .semibold)).foregroundStyle(theme.p.s700)
                Spacer()
                Button { Task { await send() } } label: {
                    Text(L.t("tasks.child.send"))
                        .font(F.sans(14, .semibold))
                        .foregroundStyle(theme.primaryForeground)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(theme.p.s600, in: Capsule())
                }
                .disabled(busy)
                .opacity(busy ? 0.5 : 1)
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    photoImage = image
                    photo = ProfileView.squareDataURL(image, size: 480)
                }
            }
        }
    }

    private func send() async {
        busy = true
        defer { busy = false }
        try? await SupabaseAPI.submitTask(task.id,
                                          note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                          imageDataURL: photo)
        onClose()
    }
}

// MARK: - Notifications

/// 1:1 port of `src/components/TaskNotifications.tsx`.
struct TaskNotificationsCard: View {
    @EnvironmentObject var theme: Theme
    @State private var items: [TaskNotificationRow] = []

    private var unread: Int { items.filter { $0.read_at == nil }.count }

    var body: some View {
        Group {
            if !items.isEmpty {
                CardSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell").font(.system(size: 14))
                                .foregroundStyle(theme.p.s700)
                            Text(L.t("tasks.notif.title"))
                                .font(F.sans(14, .semibold)).foregroundStyle(theme.foreground)
                            if unread > 0 {
                                Text("\(unread)")
                                    .font(F.sans(10, .semibold))
                                    .foregroundStyle(theme.primaryForeground)
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(theme.p.s600, in: Capsule())
                            }
                            Spacer(minLength: 0)
                            if unread > 0 {
                                Button {
                                    Task { await markAllRead() }
                                } label: {
                                    Text(L.t("tasks.notif.mark_read"))
                                        .font(F.sans(11, .semibold)).foregroundStyle(theme.p.s700)
                                }
                            }
                        }
                        VStack(spacing: 8) {
                            ForEach(items.prefix(6)) { n in
                                Text(Self.line(n))
                                    .font(F.xs)
                                    .foregroundStyle(n.read_at == nil ? theme.p.s900 : theme.p.s600)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(n.read_at == nil ? theme.p.s50 : theme.card,
                                                in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                                            .strokeBorder(n.read_at == nil ? theme.p.s200 : theme.p.s100,
                                                          lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }
        }
        .task { items = await SupabaseAPI.taskNotifications() }
    }

    static func line(_ n: TaskNotificationRow) -> String {
        switch n.type {
        case "task_assigned": return L.t("tasks.notif.assigned", ["title": n.title])
        case "task_submitted": return L.t("tasks.notif.submitted", ["name": n.body ?? "", "title": n.title])
        case "task_approved": return L.t("tasks.notif.approved", ["title": n.title, "m": n.body ?? "0"])
        case "task_rejected":
            if let b = n.body, !b.isEmpty {
                return L.t("tasks.notif.rejected_reason", ["title": n.title, "reason": b])
            }
            return L.t("tasks.notif.rejected", ["title": n.title])
        default: return n.title
        }
    }

    private func markAllRead() async {
        for n in items where n.read_at == nil {
            await SupabaseAPI.markNotificationRead(n.id)
        }
        items = await SupabaseAPI.taskNotifications()
    }
}
