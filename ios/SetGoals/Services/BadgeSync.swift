import Foundation

/// Native port of the badge rules in `src/lib/badges.ts`.
/// Awards activity badges from the user's real recorded movement:
/// today's HealthKit totals, the all-time sums stored in `activity_steps`
/// and the hourly buckets used by Early Bird / Night Owl.
@MainActor
enum BadgeSync {
    static let earlyBirdThreshold = 2000
    static let nightOwlThreshold = 2000

    /// Awards every badge whose criteria the user now meets. Already-earned
    /// badges are skipped, so each badge can only be won once.
    static func run() async {
        let earned = (try? await SupabaseAPI.earnedBadges()) ?? []
        var ids: [String] = []

        let hk = HealthKitService.shared
        let steps = hk.steps
        let km = hk.distanceKm

        if steps > 0 {
            if steps >= 1000 { ids.append("first_steps") }
            if steps >= 5000 { ids.append("daily_walker") }
            if km >= 10 { ids.append("ten_k_club") }
            let early = hk.hourlySteps.prefix(8).reduce(0, +)
            let night = hk.hourlySteps.suffix(3).reduce(0, +)
            if early >= earlyBirdThreshold { ids.append("early_bird") }
            if night >= nightOwlThreshold { ids.append("night_owl") }
        }

        let history = await SupabaseAPI.historyFilled(days: 365)
        let totalKm = history.reduce(0.0) { $0 + $1.distance }
        if totalKm >= 10 { ids.append("explorer") }
        if totalKm >= 100 { ids.append("adventurer") }
        if totalKm >= 500 { ids.append("pathfinder") }

        // Streak badges use the same best-streak value the web app tracks.
        let best = max(SettingsStore.shared.streakBest, SettingsStore.shared.streakCount)
        if best >= 7 { ids.append("consistency_king") }
        if best >= 30 { ids.append("impressive") }
        if best >= 100 { ids.append("unstoppable") }

        if SettingsStore.shared.isPro { ids.append("earned_elite") }

        var newlyEarned = earned
        for id in ids where !newlyEarned.contains(id) {
            await SupabaseAPI.awardBadge(id)
            newlyEarned.insert(id)
        }

        // "Unlocker" is only won once every other badge is in hand.
        let others = BADGES.map(\.id).filter { $0 != "unlocker" }
        if others.allSatisfy(newlyEarned.contains), !newlyEarned.contains("unlocker") {
            await SupabaseAPI.awardBadge("unlocker")
        }
        await BadgeStore.shared.reload()
    }

    /// Leaderboard badges — mirrors `recordLeaderboardBadges`.
    static func leaderboard(scope: String, rank: Int, steps: Int, participants: Int) async {
        guard rank >= 1, steps > 0 else { return }
        var ids: [String] = []
        if scope == "local" {
            if rank <= 10 && participants >= 10 { ids.append("local_elite") }
            if rank == 1 && participants >= 10 { ids.append("local_legend") }
        } else {
            if rank <= 100 && participants >= 100 { ids.append("national_contender") }
            if rank <= 10 && participants >= 100 { ids.append("national_elite") }
            if rank == 1 && participants >= 100 { ids.append("national_champion") }
        }
        guard !ids.isEmpty else { return }
        let earned = (try? await SupabaseAPI.earnedBadges()) ?? []
        let missing = ids.filter { !earned.contains($0) }
        for id in missing { await SupabaseAPI.awardBadge(id) }
        if !missing.isEmpty { await BadgeStore.shared.reload() }
    }
}


/// App-wide badge cache. Loaded once at launch and refreshed only when a new
/// badge is awarded, so badge views render instantly without refetching.
@MainActor
final class BadgeStore: ObservableObject {
    static let shared = BadgeStore()
    /// Most recently earned first.
    @Published private(set) var ordered: [String] = []
    /// badge id -> original earned date.
    @Published private(set) var earnedAt: [String: Date] = [:]
    var earned: Set<String> { Set(ordered) }
    private var syncing = false

    func reload() async {
        let rows = await SupabaseAPI.earnedBadgeRows()
        ordered = rows.map(\.badge_id)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        var map: [String: Date] = [:]
        for r in rows { if let d = iso.date(from: r.earned_at) ?? plain.date(from: r.earned_at) { map[r.badge_id] = d } }
        earnedAt = map
    }

    /// Load cached badges, then award anything new in the background.
    func preload() async {
        guard !syncing else { return }
        syncing = true
        defer { syncing = false }
        await reload()
        await BadgeSync.run()
    }
}
