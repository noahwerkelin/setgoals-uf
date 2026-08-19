import Foundation
import Supabase

// MARK: - Extra row models used by the remaining ported screens

struct ChildRow: Codable, Identifiable {
    let id: UUID
    var name: String
    var username: String?
    var avatar: String?
    var birthday: String?
    var daily_goal: Int
    var steps_per_30: Int
    var daily_cap_hours: Int
    var auth_user_id: UUID?
    var code: String
    var invitation_status: String
}

struct TaskRow: Codable, Identifiable {
    let id: UUID
    var title: String
    var description: String?
    var reward_minutes: Int
    var status: String          // pending | submitted | approved | rejected | expired
    var due_date: String?
    var child_id: UUID
    var child_user_id: UUID?
    var parent_id: UUID?
    var repeat_schedule: String?
    var repeat_interval_days: Int?
    var priority: String?
    var proof_note: String?
    var proof_image_url: String?
    var rejection_reason: String?
    var approved_at: String?
    var updated_at: String?
}

struct UserBadgeRow: Codable {
    var badge_id: String
    var earned_at: String
}

struct RestrictionRow: Codable, Identifiable {
    let id: UUID
    var kind: String
    var identifier: String
    var label: String
    var active: Bool
}

extension SupabaseAPI {
    /// Last `days` days of activity for the signed-in user, oldest first,
    /// with missing days filled with zeroes (mirrors `useHistorySteps`).
    static func historyFilled(days: Int) async -> [(day: String, steps: Int, distance: Double)] {
        let rows = (try? await history(days: days)) ?? []
        var byDay: [String: ActivityStepsRow] = [:]
        for r in rows { byDay[r.day] = r }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        var out: [(String, Int, Double)] = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            let d = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let key = f.string(from: d)
            let r = byDay[key]
            out.append((key, r?.steps ?? 0, r?.distance_km ?? 0))
        }
        return out
    }

    /// Full per-day totals (steps, distance, calories, exercise) — the native
    /// equivalent of the web `DayTotals` used by challenges and statistics.
    static func historyTotals(days: Int) async -> [DayTotals] {
        let rows = (try? await history(days: days)) ?? []
        var byDay: [String: ActivityStepsRow] = [:]
        for r in rows { byDay[r.day] = r }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        var out: [DayTotals] = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            let d = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let key = f.string(from: d)
            let r = byDay[key]
            out.append(DayTotals(day: key, steps: r?.steps ?? 0, distanceKm: r?.distance_km ?? 0,
                                 calories: r?.calories ?? 0, exerciseMinutes: r?.exercise_minutes ?? 0))
        }
        return out
    }

    static func weekTotals() async -> [DayTotals] { await historyTotals(days: 7) }

    static func weekSteps() async -> [(day: String, steps: Int)] {
        await historyFilled(days: 7).map { ($0.day, $0.steps) }
    }


    static func children() async throws -> [ChildRow] {
        guard let uid = await currentUserID() else { return [] }
        return try await supabase.from("children").select()
            .eq("parent_id", value: uid).order("created_at", ascending: true)
            .execute().value
    }

    static func stepsFor(userIDs: [UUID]) async throws -> [UUID: Int] {
        guard !userIDs.isEmpty else { return [:] }
        struct Row: Codable { let user_id: UUID; let steps: Int }
        let rows: [Row] = try await supabase.from("activity_steps")
            .select("user_id,steps").in("user_id", values: userIDs)
            .eq("day", value: todayKey).execute().value
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.user_id, $0.steps) })
    }

    static func tasks() async throws -> [TaskRow] {
        try await supabase.from("tasks").select()
            .order("created_at", ascending: false).execute().value
    }

    static func earnedBadges() async throws -> Set<String> {
        guard let uid = await currentUserID() else { return [] }
        let rows: [UserBadgeRow] = try await supabase.from("user_badges")
            .select("badge_id,earned_at").eq("user_id", value: uid).execute().value
        return Set(rows.map(\.badge_id))
    }

    /// Badge ids ordered by `earned_at`, most recent first (mirrors `RecentWins`).
    static func earnedBadgesOrdered() async -> [String] {
        guard let uid = await currentUserID() else { return [] }
        let rows: [UserBadgeRow] = (try? await supabase.from("user_badges")
            .select("badge_id,earned_at").eq("user_id", value: uid)
            .order("earned_at", ascending: false).execute().value) ?? []
        return rows.map(\.badge_id)
    }


    static func awardBadge(_ id: String) async {
        guard let uid = await currentUserID() else { return }
        try? await supabase.from("user_badges")
            .upsert(["user_id": AnyJSON.string(uid.uuidString), "badge_id": .string(id)],
                    onConflict: "user_id,badge_id")
            .execute()
    }

    static func restrictions() async throws -> [RestrictionRow] {
        guard let uid = await currentUserID() else { return [] }
        return try await supabase.from("restriction_settings").select()
            .eq("user_id", value: uid).execute().value
    }

    static func setRestriction(id: UUID, active: Bool) async throws {
        try await supabase.from("restriction_settings")
            .update(["active": active]).eq("id", value: id).execute()
    }

    static func giftScreenTime(childUserID: UUID, minutes: Int) async throws {
        guard let uid = await currentUserID() else { return }
        try await supabase.from("screentime_grants").insert([
            "parent_id": AnyJSON.string(uid.uuidString),
            "child_user_id": .string(childUserID.uuidString),
            "day": .string(todayKey),
            "minutes": .integer(minutes),
        ]).execute()
    }

    static func updateProfile(_ patch: [String: AnyJSON]) async throws {
        guard let uid = await currentUserID() else { return }
        try await supabase.from("profiles").update(patch).eq("id", value: uid).execute()
    }
}

// MARK: - Friends (port of `src/lib/friends.functions.ts`)

struct PublicUser: Codable, Identifiable, Hashable {
    let id: UUID
    var username: String
    var name: String
}

struct FriendRow: Identifiable, Hashable {
    /// friend's user id
    let id: UUID
    /// friendship row id — used for deletion
    let friendshipID: UUID
    var username: String
    var name: String
}

extension SupabaseAPI {
    private struct ProfileLite: Codable { let id: UUID; let username: String?; let display_name: String? }
    private struct FriendshipRow: Codable { let id: UUID; let user_id: UUID; let friend_id: UUID }

    /// Confirmed friends of the signed-in user (symmetric rows).
    static func friends() async throws -> [FriendRow] {
        guard let uid = await currentUserID() else { return [] }
        let rows: [FriendshipRow] = try await supabase.from("friendships")
            .select("id,user_id,friend_id")
            .or("user_id.eq.\(uid.uuidString),friend_id.eq.\(uid.uuidString)")
            .execute().value
        guard !rows.isEmpty else { return [] }
        let ids = rows.map { $0.user_id == uid ? $0.friend_id : $0.user_id }
        let profiles: [ProfileLite] = try await supabase.from("profiles")
            .select("id,username,display_name").in("id", values: ids).execute().value
        let byID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        return rows.map { r in
            let fid = r.user_id == uid ? r.friend_id : r.user_id
            let p = byID[fid]
            return FriendRow(id: fid, friendshipID: r.id,
                             username: p?.username ?? "",
                             name: (p?.display_name?.isEmpty == false ? p!.display_name! : (p?.username ?? "")))
        }
    }

    /// Search real accounts by username (min 2 chars, max 8 results).
    static func searchUsers(_ query: String) async throws -> [PublicUser] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
            .replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "_", with: "")
        guard q.count >= 2, let uid = await currentUserID() else { return [] }
        let rows: [ProfileLite] = try await supabase.from("profiles")
            .select("id,username,display_name")
            .ilike("username", pattern: "%\(q)%")
            .neq("id", value: uid)
            .limit(8).execute().value
        return rows.map {
            PublicUser(id: $0.id, username: $0.username ?? "",
                       name: ($0.display_name?.isEmpty == false ? $0.display_name! : ($0.username ?? "")))
        }
    }

    static func addFriend(_ friendID: UUID) async throws {
        guard let uid = await currentUserID(), uid != friendID else { return }
        try await supabase.from("friendships").insert([
            "user_id": AnyJSON.string(uid.uuidString),
            "friend_id": .string(friendID.uuidString),
        ]).execute()
    }

    static func removeFriend(friendshipID: UUID) async throws {
        try await supabase.from("friendships").delete().eq("id", value: friendshipID).execute()
    }

    /// Today's step totals for a set of friends.
    static func friendsStepsToday(_ ids: [UUID]) async -> [UUID: Int] {
        ((try? await stepsFor(userIDs: ids)) ?? [:])
    }
}

// MARK: - PRO Family status for child accounts

struct ParentFamilyStatus: Codable {
    let active: Bool
    let cancelling: Bool
    let ends_at: String?
    let environment: String?
    let status: String?
}

extension SupabaseAPI {
    static func parentFamilyStatus() async throws -> ParentFamilyStatus? {
        let rows: [ParentFamilyStatus] = try await supabase.rpc("parent_family_pro_status")
            .execute().value
        return rows.first
    }
}
