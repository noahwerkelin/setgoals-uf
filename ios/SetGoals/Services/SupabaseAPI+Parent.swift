import Foundation
import Supabase

/// Parent dashboard data access — 1:1 port of `src/lib/children.functions.ts`
/// and `src/lib/tasks.functions.ts` (the writes all run as the signed-in
/// parent, exactly like the web server functions do).

struct ChildDayStats {
    var steps: Int = 0
    var usedMin: Int = 0
    var bonusMin: Int = 0
}

struct TaskNotificationRow: Codable, Identifiable {
    let id: UUID
    var type: String
    var title: String
    var body: String?
    var read_at: String?
    var created_at: String
}

enum ParentAPIError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(m) = self { return m }; return nil }
}

extension SupabaseAPI {
    // MARK: - Days

    static func dayKey(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: d)
    }

    static var localToday: String { dayKey(Date()) }

    // MARK: - Child activity (today + last 7 days)

    /// Mirrors the parent page loader: today's steps / used / gifted minutes
    /// plus a 7-day map used by the weekly summary bars.
    static func childActivity(
        _ ids: [UUID]
    ) async -> (today: [UUID: ChildDayStats], week: [UUID: [String: (steps: Int, usedMin: Int)]]) {
        guard !ids.isEmpty else { return ([:], [:]) }
        let today = localToday
        let weekStart = dayKey(Calendar.current.date(byAdding: .day, value: -6, to: Date())!)

        struct Act: Codable { let user_id: UUID; let day: String; let steps: Int? }
        struct Bal: Codable { let user_id: UUID; let day: String; let consumed_min: Int?; let bonus_min: Int? }

        let acts: [Act] = (try? await supabase.from("activity_steps")
            .select("user_id,day,steps").gte("day", value: weekStart).lte("day", value: today)
            .in("user_id", values: ids).execute().value) ?? []
        let bals: [Bal] = (try? await supabase.from("earned_balances")
            .select("user_id,day,consumed_min,bonus_min").gte("day", value: weekStart).lte("day", value: today)
            .in("user_id", values: ids).execute().value) ?? []

        var map: [UUID: ChildDayStats] = [:]
        var week: [UUID: [String: (steps: Int, usedMin: Int)]] = [:]
        for id in ids { map[id] = ChildDayStats(); week[id] = [:] }

        for r in acts {
            var cell = week[r.user_id]?[r.day] ?? (steps: 0, usedMin: 0)
            cell.steps += r.steps ?? 0
            week[r.user_id, default: [:]][r.day] = cell
            if r.day == today { map[r.user_id, default: ChildDayStats()].steps += r.steps ?? 0 }
        }
        for r in bals {
            var cell = week[r.user_id]?[r.day] ?? (steps: 0, usedMin: 0)
            cell.usedMin = r.consumed_min ?? 0
            week[r.user_id, default: [:]][r.day] = cell
            if r.day == today {
                map[r.user_id, default: ChildDayStats()].usedMin = r.consumed_min ?? 0
                map[r.user_id, default: ChildDayStats()].bonusMin = r.bonus_min ?? 0
            }
        }
        return (map, week)
    }

    // MARK: - Child CRUD

    private static let codeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generateChildCode() -> String {
        let chars = (0..<8).map { _ in codeAlphabet.randomElement()! }
        return "\(String(chars[0..<4]))-\(String(chars[4..<8]))"
    }

    /// Creates a child profile with a fresh invitation code (7-day TTL).
    static func createChild(
        name: String, username: String, avatar: String, birthday: String,
        dailyGoal: Int, stepsPer30: Int, dailyCapHours: Int
    ) async throws {
        guard let uid = await currentUserID() else { throw ParentAPIError.message("Not signed in") }
        let expires = ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 86_400))
        try await supabase.from("children").insert([
            "parent_id": AnyJSON.string(uid.uuidString),
            "name": .string(name),
            "username": .string(username),
            "avatar": .string(avatar),
            "birthday": birthday.isEmpty ? .null : .string(birthday),
            "daily_goal": .integer(dailyGoal),
            "steps_per_30": .integer(stepsPer30),
            "daily_cap_hours": .integer(dailyCapHours),
            "code": .string(generateChildCode()),
            "invitation_status": .string("pending"),
            "invitation_expires_at": .string(expires),
        ]).execute()
    }

    static func updateChild(_ id: UUID, _ patch: [String: AnyJSON]) async throws {
        try await supabase.from("children").update(patch).eq("id", value: id).execute()
    }

    static func updateChildScreenTime(_ id: UUID, stepsPer30: Int, dailyCapHours: Int) async throws {
        try await updateChild(id, [
            "steps_per_30": .integer(stepsPer30),
            "daily_cap_hours": .integer(dailyCapHours),
        ])
    }

    /// Re-issues a single-use invitation code (parent only, not yet joined).
    @discardableResult
    static func issueChildCode(_ id: UUID) async throws -> String {
        let code = generateChildCode()
        let expires = ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 86_400))
        try await updateChild(id, [
            "code": .string(code),
            "invitation_status": .string("pending"),
            "invitation_expires_at": .string(expires),
        ])
        return code
    }

    /// Deletes a child after re-authenticating the parent with their password.
    static func deleteChild(_ id: UUID, password: String) async throws {
        guard let email = try? await supabase.auth.user().email, !email.isEmpty else {
            throw ParentAPIError.message(L.t("delete.wrong_password"))
        }
        do {
            _ = try await supabase.auth.signIn(email: email, password: password)
        } catch {
            throw ParentAPIError.message(L.t("delete.wrong_password"))
        }
        try await supabase.from("children").delete().eq("id", value: id).execute()
    }

    /// Gift bonus minutes to a linked child for today (same math as the web
    /// `grantScreenTime` server function).
    static func giftScreenTime(childID: UUID, childUserID: UUID, minutes: Int, note: String?) async throws {
        guard let uid = await currentUserID() else { throw ParentAPIError.message("Not signed in") }
        let day = localToday
        struct Bal: Codable { let bonus_min: Int? }
        let existing: Bal? = try? await supabase.from("earned_balances")
            .select("bonus_min").eq("user_id", value: childUserID).eq("day", value: day)
            .single().execute().value
        let bonus = (existing?.bonus_min ?? 0) + minutes
        if existing != nil {
            try await supabase.from("earned_balances")
                .update(["bonus_min": AnyJSON.integer(bonus)])
                .eq("user_id", value: childUserID).eq("day", value: day).execute()
        } else {
            try await supabase.from("earned_balances").insert([
                "user_id": AnyJSON.string(childUserID.uuidString),
                "day": .string(day),
                "bonus_min": .integer(bonus),
            ]).execute()
        }
        try await supabase.from("screentime_grants").insert([
            "parent_id": AnyJSON.string(uid.uuidString),
            "child_user_id": .string(childUserID.uuidString),
            "day": .string(day),
            "minutes": .integer(minutes),
            "note": note.map { AnyJSON.string($0) } ?? .null,
        ]).execute()
        _ = childID
    }

    // MARK: - Tasks

    static func tasks(childID: UUID) async -> [TaskRow] {
        (try? await supabase.from("tasks").select()
            .eq("child_id", value: childID)
            .order("created_at", ascending: false).execute().value) ?? []
    }

    static func createTask(
        parentID: UUID, childID: UUID, title: String, description: String,
        rewardMinutes: Int, dueDate: String?, repeatSchedule: String,
        repeatIntervalDays: Int, priority: String
    ) async throws {
        try await supabase.from("tasks").insert([
            "parent_id": AnyJSON.string(parentID.uuidString),
            "child_id": .string(childID.uuidString),
            "title": .string(title),
            "description": description.isEmpty ? .null : .string(description),
            "reward_minutes": .integer(rewardMinutes),
            "due_date": dueDate.map { AnyJSON.string($0) } ?? .null,
            "repeat_schedule": .string(repeatSchedule),
            "repeat_interval_days": repeatSchedule == "custom" ? .integer(repeatIntervalDays) : .null,
            "priority": .string(priority),
        ]).execute()
    }

    static func updateTask(_ id: UUID, _ patch: [String: AnyJSON]) async throws {
        try await supabase.from("tasks").update(patch).eq("id", value: id).execute()
    }

    static func deleteTask(_ id: UUID) async throws {
        try await supabase.from("tasks").delete().eq("id", value: id).execute()
    }

    /// Approve a submitted task: grants the reward minutes and regenerates a
    /// recurring task for its next occurrence.
    @discardableResult
    static func approveTask(_ task: TaskRow) async throws -> Int {
        guard let uid = await currentUserID() else { throw ParentAPIError.message("Not signed in") }
        guard task.status == "submitted" else {
            throw ParentAPIError.message(L.t("tasks.status.submitted"))
        }
        guard let childUserID = task.child_user_id else {
            throw ParentAPIError.message(L.t("tasks.needs_join"))
        }
        try await updateTask(task.id, [
            "status": .string("approved"),
            "approved_at": .string(ISO8601DateFormatter().string(from: Date())),
            "rejection_reason": .null,
        ])
        if task.reward_minutes > 0 {
            try await giftScreenTime(childID: task.child_id, childUserID: childUserID,
                                     minutes: task.reward_minutes, note: "Task: \(task.title)")
        }
        let schedule = task.repeat_schedule ?? "none"
        if schedule != "none" {
            let days = schedule == "daily" ? 1 : schedule == "weekly" ? 7 : (task.repeat_interval_days ?? 1)
            let base = task.due_date.flatMap { d -> Date? in
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
                return f.date(from: d)
            } ?? Date()
            let next = dayKey(Calendar.current.date(byAdding: .day, value: days, to: base)!)
            try await createTask(parentID: uid, childID: task.child_id, title: task.title,
                                 description: task.description ?? "", rewardMinutes: task.reward_minutes,
                                 dueDate: next, repeatSchedule: schedule,
                                 repeatIntervalDays: task.repeat_interval_days ?? 1,
                                 priority: task.priority ?? "normal")
        }
        return task.reward_minutes
    }

    static func rejectTask(_ task: TaskRow, reason: String?) async throws {
        try await updateTask(task.id, [
            "status": .string("rejected"),
            "rejection_reason": (reason?.isEmpty == false) ? .string(reason!) : .null,
        ])
    }

    /// Child-side: submit a pending task for approval.
    static func submitTask(_ id: UUID, note: String?, imageDataURL: String?) async throws {
        try await supabase.from("tasks").update([
            "status": AnyJSON.string("submitted"),
            "proof_note": note.map { AnyJSON.string($0) } ?? .null,
            "proof_image_url": imageDataURL.map { AnyJSON.string($0) } ?? .null,
        ]).eq("id", value: id).execute()
    }

    // MARK: - Task notifications

    static func taskNotifications() async -> [TaskNotificationRow] {
        guard let uid = await currentUserID() else { return [] }
        return (try? await supabase.from("task_notifications")
            .select("id,type,title,body,read_at,created_at")
            .eq("user_id", value: uid).is("read_at", value: nil)
            .order("created_at", ascending: false).limit(6)
            .execute().value) ?? []
    }

    static func markNotificationRead(_ id: UUID) async {
        try? await supabase.from("task_notifications")
            .update(["read_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id).execute()
    }
}
