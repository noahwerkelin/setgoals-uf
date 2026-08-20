import Foundation
import Supabase

/// Same project the web app talks to (`src/integrations/supabase/client.ts`).
/// The publishable/anon key is safe to ship in the client; RLS enforces access.
enum SupabaseConfig {
    static let url = URL(string: "https://xirdmgwmuwffevgqxqxl.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhpcmRtZ3dtdXdmZmV2Z3F4cXhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4NjAxNzQsImV4cCI6MjA5NjQzNjE3NH0.2OhEjp80Meo3VdCLGalflqkwPoLvS5ob9PmQitAGHBU"
}

let supabase = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)

// MARK: - Row models (mirror the tables used by the web app)

struct Profile: Codable, Identifiable {
    let id: UUID
    var username: String
    var display_name: String
    var avatar_url: String?
    var email: String?
    var birthday: String?
    var role: String
    var country_code: String
    var region: String
}

struct UserSettingsRow: Codable {
    var user_id: UUID
    var steps_per_30: Int
    var daily_cap_hours: Int
    var units: String
    var daily_goal: Int
    var theme_color: String
    var anonymous_leaderboard: Bool
    var is_pro: Bool
    var pro_plan: String
    var pro_expires_at: String?
    var pro_since: String?
    var healthkit_connected: Bool
    var googlefit_connected: Bool
    var push_on: Bool
    var share_location: String
}

struct ActivityStepsRow: Codable {
    var user_id: UUID?
    var day: String
    var steps: Int
    var distance_km: Double
    var calories: Int
    var exercise_minutes: Int
    var source: String
}

struct EarnedBalanceRow: Codable {
    var user_id: UUID
    var day: String
    var earned_min: Int
    var consumed_min: Int
    var bonus_min: Int
}

struct StreakRow: Codable {
    var user_id: UUID
    var count: Int
    var best: Int
    var last_goal_met_date: String?
}

struct FamilyMember: Codable, Identifiable {
    let member_id: String
    let name: String
    let avatar: String?
    let steps: Int
    let relation: String
    let is_self: Bool
    var id: String { member_id }
}

struct LeaderboardEntry: Codable, Identifiable {
    let user_id: UUID
    let display_name: String
    let username: String
    let avatar_url: String?
    let total_steps: Int
    let rank: Int
    var id: UUID { user_id }
}

// MARK: - Data access

enum SupabaseAPI {
    static var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date())
    }

    static func currentUserID() async -> UUID? {
        try? await supabase.auth.user().id
    }

    static func profile() async throws -> Profile? {
        guard let uid = await currentUserID() else { return nil }
        return try await supabase.from("profiles").select().eq("id", value: uid)
            .single().execute().value
    }

    static func settings() async throws -> UserSettingsRow? {
        guard let uid = await currentUserID() else { return nil }
        return try await supabase.from("user_settings").select().eq("user_id", value: uid)
            .single().execute().value
    }

    static func updateSettings(_ patch: [String: AnyJSON]) async throws {
        guard let uid = await currentUserID() else { return }
        try await supabase.from("user_settings").update(patch).eq("user_id", value: uid).execute()
    }

    /// Upserts today's HealthKit sample. Matches the web ingest shape.
    static func upsertToday(steps: Int, distanceKm: Double, calories: Int, exerciseMinutes: Int) async throws {
        guard let uid = await currentUserID() else { return }
        let row = ActivityStepsRow(
            user_id: uid, day: todayKey, steps: steps, distance_km: distanceKm,
            calories: calories, exercise_minutes: exerciseMinutes, source: "healthkit"
        )
        try await supabase.from("activity_steps")
            .upsert(row, onConflict: "user_id,day,source")
            .execute()
    }

    static func history(days: Int) async throws -> [ActivityStepsRow] {
        guard let uid = await currentUserID() else { return [] }
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -(max(1, days) - 1),
                                  to: calendar.startOfDay(for: Date())) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return try await supabase.from("activity_steps").select()
            .eq("user_id", value: uid)
            .gte("day", value: formatter.string(from: start))
            .order("day", ascending: true)
            .execute().value
    }

    static func todayBalance() async throws -> EarnedBalanceRow? {
        guard let uid = await currentUserID() else { return nil }
        return try? await supabase.from("earned_balances").select()
            .eq("user_id", value: uid).eq("day", value: todayKey)
            .single().execute().value
    }

    static func streak() async throws -> StreakRow? {
        guard let uid = await currentUserID() else { return nil }
        return try? await supabase.from("streaks").select().eq("user_id", value: uid)
            .single().execute().value
    }

    static func familyToday() async throws -> [FamilyMember] {
        try await supabase.rpc("family_today").execute().value
    }

    static func leaderboard(scope: String) async throws -> [LeaderboardEntry] {
        try await supabase.rpc("leaderboard", params: ["_scope": scope]).execute().value
    }

    static func usernameAvailable(_ username: String) async throws -> Bool {
        try await supabase.rpc("username_available", params: ["_username": username]).execute().value
    }
}
