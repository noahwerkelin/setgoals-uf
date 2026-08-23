import Foundation

/// Grants the screen-time reward printed on each challenge card once the
/// challenge is completed. Daily challenges pay out once per day, weekly ones
/// once per ISO week — the claim ledger is stored locally and the minutes are
/// written to today's `earned_balances.bonus_min`, the same field parents use
/// when gifting screen time.
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
                               settings: SettingsStore) async -> Int {
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

        guard minutes > 0 else { return 0 }
        do {
            let total = try await SupabaseAPI.addOwnBonusMinutes(minutes)
            settings.bonusMin = total
            ledger.formUnion(newKeys)
            claimed = ledger
            return minutes
        } catch {
            return 0
        }
    }
}
