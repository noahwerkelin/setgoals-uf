import Foundation

/// Native port of `recordSteps` in `src/lib/settings.tsx`.
/// Adds a day to the streak the first time today's steps reach the daily goal,
/// keeps it alive while days are consecutive, and resets it to 0 once a day
/// has been missed. Also mirrors the result into `SettingsStore` so the
/// profile / home UI updates immediately.
@MainActor
enum StreakSync {
    private static func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: date)
    }

    private static func date(_ key: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.date(from: key)
    }

    private static func daysBetween(_ a: String, _ b: String) -> Int {
        guard let da = date(a), let db = date(b) else { return 99 }
        return Calendar.current.dateComponents([.day], from: da, to: db).day ?? 99
    }

    /// Call after today's step total is known (HealthKit refresh, app launch).
    static func record(steps: Int, goal: Int) async {
        guard goal > 0, let uid = await SupabaseAPI.currentUserID() else { return }
        let today = SupabaseAPI.todayKey

        let current = (try? await SupabaseAPI.streak()) ?? nil
        var count = current?.count ?? 0
        var best = current?.best ?? 0
        var last = current?.last_goal_met_date
        let before = (count, best, last)

        if steps >= goal {
            if last == today {
                // Already counted today — nothing to change.
            } else if let last, daysBetween(last, today) == 1 {
                count += 1
                best = max(best, count)
            } else {
                count = 1
                best = max(best, 1)
            }
            last = today
        } else if let l = last, daysBetween(l, today) >= 2 {
            count = 0
        }

        // Keep the in-memory settings truthful even when nothing was written.
        SettingsStore.shared.streakCount = count
        SettingsStore.shared.streakBest = best
        SettingsStore.shared.lastGoalMetDate = last

        guard (count, best, last) != before else { return }

        try? await supabase.from("streaks").upsert([
            "user_id": AnyJSON.string(uid.uuidString),
            "count": .integer(count),
            "best": .integer(best),
            "last_goal_met_date": last.map { AnyJSON.string($0) } ?? .null,
        ], onConflict: "user_id").execute()
    }

    /// Convenience: uses the live HealthKit total and the user's daily goal.
    static func syncFromHealthKit() async {
        await record(steps: HealthKitService.shared.steps,
                     goal: SettingsStore.shared.dailyGoal)
    }
}
