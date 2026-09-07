import Foundation

/// Grants the screen-time reward printed on each challenge card once the
/// challenge is completed. Daily challenges pay out once per day, weekly ones
/// once per ISO week.
///
/// The reward is only ever marked as claimed after Apple's Screen Time system
/// has actually granted it (`ScreenTimeService.grant`), so the UI can never
/// claim a reward that did not take effect.
struct ChallengeClaim {
    var minutes: Int = 0
    var failed: Bool = false
}

enum ChallengeRewards {
    private static let key = "challenges.claimed"

    private static var claimed: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: key) }
    }

    private static func periodKey(_ c: Challenge) -> String {
        if c.scope == "daily" { return "\(c.id)@\(SupabaseAPI.todayKey)" }
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let now = Date()
        return "\(c.id)@\(cal.component(.yearForWeekOfYear, from: now))-W\(cal.component(.weekOfYear, from: now))"
    }

    /// Awards every newly completed challenge and returns the minutes granted.
    @MainActor
    @discardableResult
    static func claimCompleted(week: [DayTotals],
                               today: HealthKitService,
                               settings: SettingsStore) async -> ChallengeClaim {
        let all = ChallengeCatalog.todaysDaily + ChallengeCatalog.thisWeeksWeekly
        var ledger = claimed
        var minutes = 0
        var newKeys: [String] = []

        for c in all {
            let k = periodKey(c)
            guard !ledger.contains(k) else { continue }
            let p = ChallengeCatalog.progress(c, today: today, week: week, settings: settings)
            guard p.done else { continue }
            minutes += c.rewardMin
            newKeys.append(k)
        }

        guard minutes > 0 else { return ChallengeClaim() }

        do {
            // Apple's Screen Time system is the source of truth: only when this
            // succeeds is the reward real.
            try ScreenTimeService.shared.grant(minutes: minutes)
        } catch {
            return ChallengeClaim(minutes: 0, failed: true)
        }

        ledger.formUnion(newKeys)
        claimed = ledger
        return ChallengeClaim(minutes: minutes, failed: false)
    }
}
