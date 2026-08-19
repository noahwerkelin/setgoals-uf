import Foundation

/// 1:1 port of `src/lib/challenges-catalog.ts` — same ids, targets, rewards,
/// copy and the same deterministic FNV-1a rotation (3 daily / 2 weekly).
struct Challenge: Identifiable, Hashable {
    enum Metric: String { case steps, distance, exercise, calories, earned, streak, goal }

    let id: String
    let metric: Metric
    let target: Double
    let scope: String        // "daily" | "weekly"
    let en: String
    let sv: String
    let descEn: String
    let descSv: String
    let rewardMin: Int

    var title: String { L.lang == "sv" ? sv : en }
    var detail: String { L.lang == "sv" ? descSv : descEn }
}

enum ChallengeCatalog {
    static let dailyPool: [Challenge] = [
        Challenge(id: "d_steps_5k", metric: .steps, target: 5000, scope: "daily",
                  en: "Walk 5,000 steps", sv: "Gå 5 000 steg",
                  descEn: "Log at least 5,000 steps today. Progress updates automatically from your activity data.",
                  descSv: "Logga minst 5 000 steg idag. Framstegen uppdateras automatiskt från din aktivitet.",
                  rewardMin: 15),
        Challenge(id: "d_steps_8k", metric: .steps, target: 8000, scope: "daily",
                  en: "Walk 8,000 steps", sv: "Gå 8 000 steg",
                  descEn: "Hit 8,000 steps by end of day. Every step counts — automatically tracked.",
                  descSv: "Nå 8 000 steg innan dagen är slut. Varje steg räknas — spåras automatiskt.",
                  rewardMin: 30),
        Challenge(id: "d_steps_goal", metric: .goal, target: 1, scope: "daily",
                  en: "Reach your daily step goal", sv: "Nå ditt dagliga stegmål",
                  descEn: "Complete your personal daily step goal set in Settings.",
                  descSv: "Nå ditt personliga dagliga stegmål som du satt i Inställningar.",
                  rewardMin: 20),
        Challenge(id: "d_dist_3k", metric: .distance, target: 3, scope: "daily",
                  en: "Cover 3 km today", sv: "Tillryggalägg 3 km idag",
                  descEn: "Cover 3 kilometers on foot. Distance is measured from your logged activity.",
                  descSv: "Tillryggalägg 3 kilometer till fots. Sträckan mäts från din loggade aktivitet.",
                  rewardMin: 15),
        Challenge(id: "d_dist_5k", metric: .distance, target: 5, scope: "daily",
                  en: "Cover 5 km today", sv: "Tillryggalägg 5 km idag",
                  descEn: "Cover 5 kilometers today. A great mid-length walk or run.",
                  descSv: "Tillryggalägg 5 kilometer idag. En bra medellång promenad eller löprunda.",
                  rewardMin: 25),
        Challenge(id: "d_exercise_30", metric: .exercise, target: 30, scope: "daily",
                  en: "30 active minutes", sv: "30 aktiva minuter",
                  descEn: "Log 30 minutes of activity today.",
                  descSv: "Logga 30 minuters aktivitet idag.",
                  rewardMin: 20),
        Challenge(id: "d_exercise_60", metric: .exercise, target: 60, scope: "daily",
                  en: "60 active minutes", sv: "60 aktiva minuter",
                  descEn: "Reach a full hour of activity today.",
                  descSv: "Nå en hel timmes aktivitet idag.",
                  rewardMin: 35),
        Challenge(id: "d_earn_60", metric: .earned, target: 60, scope: "daily",
                  en: "Earn 1 hour of screen time", sv: "Tjäna 1 timmes skärmtid",
                  descEn: "Earn 60 minutes of screen time by walking, using your current earning rules.",
                  descSv: "Tjäna 60 minuters skärmtid genom att gå, enligt dina intjäningsregler.",
                  rewardMin: 10),
        Challenge(id: "d_earn_90", metric: .earned, target: 90, scope: "daily",
                  en: "Earn 90 minutes of screen time", sv: "Tjäna 90 minuters skärmtid",
                  descEn: "Earn 90 minutes of screen time today.",
                  descSv: "Tjäna 90 minuters skärmtid idag.",
                  rewardMin: 15),
        Challenge(id: "d_calories_300", metric: .calories, target: 300, scope: "daily",
                  en: "Burn 300 calories", sv: "Bränn 300 kalorier",
                  descEn: "Burn 300 active calories today.",
                  descSv: "Bränn 300 aktiva kalorier idag.",
                  rewardMin: 15),
    ]

    static let weeklyPool: [Challenge] = [
        Challenge(id: "w_steps_40k", metric: .steps, target: 40000, scope: "weekly",
                  en: "40,000 steps this week", sv: "40 000 steg denna vecka",
                  descEn: "Accumulate 40,000 steps across the week. Averages about 5,700 steps a day.",
                  descSv: "Samla 40 000 steg under veckan. Motsvarar cirka 5 700 steg per dag.",
                  rewardMin: 60),
        Challenge(id: "w_steps_60k", metric: .steps, target: 60000, scope: "weekly",
                  en: "60,000 steps this week", sv: "60 000 steg denna vecka",
                  descEn: "Reach 60,000 steps this week — around 8,600 a day.",
                  descSv: "Nå 60 000 steg denna vecka — cirka 8 600 per dag.",
                  rewardMin: 90),
        Challenge(id: "w_dist_25", metric: .distance, target: 25, scope: "weekly",
                  en: "25 km this week", sv: "25 km denna vecka",
                  descEn: "Cover 25 kilometers across the week.",
                  descSv: "Tillryggalägg 25 kilometer under veckan.",
                  rewardMin: 60),
        Challenge(id: "w_dist_40", metric: .distance, target: 40, scope: "weekly",
                  en: "40 km this week", sv: "40 km denna vecka",
                  descEn: "Cover 40 kilometers across the week.",
                  descSv: "Tillryggalägg 40 kilometer under veckan.",
                  rewardMin: 90),
        Challenge(id: "w_exercise_150", metric: .exercise, target: 150, scope: "weekly",
                  en: "150 active minutes", sv: "150 aktiva minuter",
                  descEn: "Log 150 minutes of activity this week — the WHO baseline.",
                  descSv: "Logga 150 aktiva minuter i veckan — WHO:s rekommendation.",
                  rewardMin: 75),
        Challenge(id: "w_streak_5", metric: .streak, target: 5, scope: "weekly",
                  en: "Keep a 5-day streak", sv: "Håll en 5-dagars svit",
                  descEn: "Reach your daily goal on 5 different days to keep a streak of 5.",
                  descSv: "Nå ditt dagsmål 5 olika dagar för att hålla en 5-dagars svit.",
                  rewardMin: 60),
        Challenge(id: "w_earn_10h", metric: .earned, target: 600, scope: "weekly",
                  en: "Earn 10h screen time", sv: "Tjäna 10h skärmtid",
                  descEn: "Earn 10 hours of screen time across the week from your activity.",
                  descSv: "Tjäna 10 timmars skärmtid under veckan från din aktivitet.",
                  rewardMin: 60),
    ]

    // MARK: Deterministic selection — same FNV-1a hash as the web helper.

    private static func hash(_ s: String) -> UInt32 {
        var h: UInt32 = 2166136261
        for u in s.unicodeScalars {
            h ^= UInt32(UInt16(truncatingIfNeeded: u.value))
            h = h &* 16777619
        }
        return h
    }

    private static func pick(_ pool: [Challenge], seed: String, n: Int) -> [Challenge] {
        pool.map { (c: $0, s: hash(seed + ":" + $0.id)) }
            .sorted { $0.s < $1.s }
            .prefix(n)
            .map(\.c)
    }

    private static func dayKey(_ d: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    private static func isoWeekKey(_ d: Date = Date()) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let week = cal.component(.weekOfYear, from: d)
        let year = cal.component(.yearForWeekOfYear, from: d)
        return "\(year)-W\(week)"
    }

    static var todaysDaily: [Challenge] { pick(dailyPool, seed: "daily:" + dayKey(), n: 3) }
    static var thisWeeksWeekly: [Challenge] { pick(weeklyPool, seed: "weekly:" + isoWeekKey(), n: 2) }

    // MARK: Progress

    struct Progress { let current: Double; let target: Double; var done: Bool { current >= target } }

    static func progress(_ c: Challenge, today: HealthKitService, week: [DayTotals],
                         settings: SettingsStore) -> Progress {
        var current: Double = 0
        if c.scope == "daily" {
            switch c.metric {
            case .steps: current = Double(today.steps)
            case .distance: current = today.distanceKm
            case .exercise: current = Double(today.exerciseMinutes)
            case .calories: current = Double(today.calories)
            case .earned: current = Double(settings.earnedMin(from: today.steps))
            case .goal:
                current = today.steps >= settings.dailyGoal
                    ? 1 : Double(today.steps) / Double(max(1, settings.dailyGoal))
            case .streak: current = Double(settings.streakCount)
            }
        } else {
            switch c.metric {
            case .steps: current = Double(week.reduce(0) { $0 + $1.steps })
            case .distance: current = week.reduce(0) { $0 + $1.distanceKm }
            case .exercise: current = Double(week.reduce(0) { $0 + $1.exerciseMinutes })
            case .calories: current = Double(week.reduce(0) { $0 + $1.calories })
            case .earned: current = Double(week.reduce(0) { $0 + settings.earnedMin(from: $1.steps) })
            case .streak: current = Double(settings.streakCount)
            case .goal: current = 0
            }
        }
        return Progress(current: current, target: c.target)
    }

    /// Port of `formatMetric`.
    static func format(_ v: Double, _ metric: Challenge.Metric) -> String {
        switch metric {
        case .steps: return "\(Int(v.rounded(.down)).formatted()) \(L.t("challenges.unit.steps"))"
        case .distance: return String(format: "%.1f km", v)
        case .exercise: return "\(Int(v)) min"
        case .calories: return "\(Int(v)) kcal"
        case .earned:
            let m = Int(v)
            let h = m / 60, r = m % 60
            return h > 0 ? "\(h)h \(r)m" : "\(r)m"
        case .streak: return "\(Int(v)) \(L.t("challenges.unit.days"))"
        case .goal: return v >= 1 ? L.t("challenges.unit.complete") : "\(Int((v * 100).rounded()))%"
        }
    }
}
