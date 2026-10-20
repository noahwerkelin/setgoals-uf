import Foundation

/// Shared, persisted screen-time budget for the current day.
///
/// Lives in the app group so the `DeviceActivityMonitor` extension and the app
/// read and write the exact same numbers. Apple's Screen Time system is the
/// thing that measures usage (through DeviceActivity threshold events) and the
/// thing that enforces the lock (through ManagedSettings shields); this store
/// is only the shared ledger both sides agree on.
enum ScreenTimeBudget {
    static let appGroup = "group.app.setgoals.shared"

    static var store: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    private enum K {
        static let day = "budget.day"
        static let base = "budget.baseMin"       // earned from steps + parent bonus
        static let reward = "budget.rewardMin"   // earned from completed challenges
        static let used = "budget.usedMin"       // measured by DeviceActivity
        static let prevDay = "budget.prevDay"
        static let prevUsed = "budget.prevUsedMin"
    }

    /// Local calendar day key, same rule as `src/lib/day.ts`.
    static var dayKey: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// Clears yesterday's numbers at the first read of a new day.
    static func rollIfNeeded() {
        let d = store.string(forKey: K.day)
        guard d != dayKey else { return }
        // Keep the finished day's measured usage so it can be uploaded later.
        if let d { store.set(d, forKey: K.prevDay); store.set(store.integer(forKey: K.used), forKey: K.prevUsed) }
        store.set(dayKey, forKey: K.day)
        store.set(0, forKey: K.base)
        store.set(0, forKey: K.reward)
        store.set(0, forKey: K.used)
    }

    static var baseMin: Int {
        get { rollIfNeeded(); return store.integer(forKey: K.base) }
        set { rollIfNeeded(); store.set(max(0, newValue), forKey: K.base) }
    }

    /// Screen time granted by completed challenges today.
    static var rewardMin: Int {
        get { rollIfNeeded(); return store.integer(forKey: K.reward) }
        set { rollIfNeeded(); store.set(max(0, newValue), forKey: K.reward) }
    }

    static var usedMin: Int {
        get { rollIfNeeded(); return store.integer(forKey: K.used) }
        set { rollIfNeeded(); store.set(max(0, newValue), forKey: K.used) }
    }

    /// Final measured usage of the last finished day, if any.
    static var previousDay: (day: String, usedMin: Int)? {
        guard let d = store.string(forKey: K.prevDay) else { return nil }
        return (d, store.integer(forKey: K.prevUsed))
    }

    static var allowanceMin: Int { baseMin + rewardMin }

    /// Minutes left before Apple's Screen Time shields lock the managed apps.
    static var remainingMin: Int { max(0, allowanceMin - usedMin) }
}
