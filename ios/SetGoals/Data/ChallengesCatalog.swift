import Foundation

/// Port of `src/lib/challenges-catalog.ts`.
/// The same deterministic rotation: 3 daily challenges per day, 2 weekly
/// per ISO week, picked from the full catalog by day/week index.
struct Challenge: Identifiable, Hashable {
    enum Metric: String { case steps, distance, calories, exercise, screenSaved, weekSteps, weekDistance, activeDays }
    let id: String
    let en: String
    let sv: String
    let descEn: String
    let descSv: String
    let metric: Metric
    let target: Double
    let cadence: String   // "daily" | "weekly"

    var title: String { L.lang == "sv" ? sv : en }
    var detail: String { L.lang == "sv" ? descSv : descEn }
}

enum ChallengeCatalog {
    static let all: [Challenge] = [
        // Daily
        Challenge(id: "d_steps_6k", en: "Walk 6,000 steps", sv: "Gå 6 000 steg", descEn: "Reach 6,000 steps before midnight.", descSv: "Nå 6 000 steg innan midnatt.", metric: .steps, target: 6000, cadence: "daily"),
        Challenge(id: "d_steps_10k", en: "Walk 10,000 steps", sv: "Gå 10 000 steg", descEn: "The classic. 10,000 steps today.", descSv: "Klassikern. 10 000 steg idag.", metric: .steps, target: 10000, cadence: "daily"),
        Challenge(id: "d_steps_12k", en: "Walk 12,000 steps", sv: "Gå 12 000 steg", descEn: "Push a little further today.", descSv: "Pressa lite extra idag.", metric: .steps, target: 12000, cadence: "daily"),
        Challenge(id: "d_dist_3", en: "Cover 3 km", sv: "Täck 3 km", descEn: "Move 3 kilometres today.", descSv: "Rör dig 3 kilometer idag.", metric: .distance, target: 3, cadence: "daily"),
        Challenge(id: "d_dist_5", en: "Cover 5 km", sv: "Täck 5 km", descEn: "Move 5 kilometres today.", descSv: "Rör dig 5 kilometer idag.", metric: .distance, target: 5, cadence: "daily"),
        Challenge(id: "d_cal_400", en: "Burn 400 kcal", sv: "Bränn 400 kcal", descEn: "Burn 400 active calories.", descSv: "Bränn 400 aktiva kalorier.", metric: .calories, target: 400, cadence: "daily"),
        Challenge(id: "d_cal_600", en: "Burn 600 kcal", sv: "Bränn 600 kcal", descEn: "Burn 600 active calories.", descSv: "Bränn 600 aktiva kalorier.", metric: .calories, target: 600, cadence: "daily"),
        Challenge(id: "d_ex_30", en: "30 active minutes", sv: "30 aktiva minuter", descEn: "Log 30 minutes of exercise.", descSv: "Logga 30 minuters träning.", metric: .exercise, target: 30, cadence: "daily"),
        Challenge(id: "d_ex_45", en: "45 active minutes", sv: "45 aktiva minuter", descEn: "Log 45 minutes of exercise.", descSv: "Logga 45 minuters träning.", metric: .exercise, target: 45, cadence: "daily"),
        Challenge(id: "d_earn_60", en: "Earn 60 min screen time", sv: "Tjäna 60 min skärmtid", descEn: "Walk enough to earn one hour.", descSv: "Gå tillräckligt för en timme.", metric: .screenSaved, target: 60, cadence: "daily"),
        Challenge(id: "d_earn_90", en: "Earn 90 min screen time", sv: "Tjäna 90 min skärmtid", descEn: "Walk enough to earn 90 minutes.", descSv: "Gå tillräckligt för 90 minuter.", metric: .screenSaved, target: 90, cadence: "daily"),
        // Weekly
        Challenge(id: "w_steps_50k", en: "50,000 steps this week", sv: "50 000 steg denna vecka", descEn: "Total 50,000 steps across the week.", descSv: "Totalt 50 000 steg under veckan.", metric: .weekSteps, target: 50000, cadence: "weekly"),
        Challenge(id: "w_steps_70k", en: "70,000 steps this week", sv: "70 000 steg denna vecka", descEn: "Total 70,000 steps across the week.", descSv: "Totalt 70 000 steg under veckan.", metric: .weekSteps, target: 70000, cadence: "weekly"),
        Challenge(id: "w_dist_25", en: "25 km this week", sv: "25 km denna vecka", descEn: "Cover 25 kilometres in seven days.", descSv: "Täck 25 kilometer på sju dagar.", metric: .weekDistance, target: 25, cadence: "weekly"),
        Challenge(id: "w_dist_40", en: "40 km this week", sv: "40 km denna vecka", descEn: "Cover 40 kilometres in seven days.", descSv: "Täck 40 kilometer på sju dagar.", metric: .weekDistance, target: 40, cadence: "weekly"),
        Challenge(id: "w_active_5", en: "Hit your goal 5 days", sv: "Nå målet 5 dagar", descEn: "Reach your daily step goal on five days.", descSv: "Nå ditt dagliga stegmål fem dagar.", metric: .activeDays, target: 5, cadence: "weekly"),
        Challenge(id: "w_active_7", en: "Hit your goal every day", sv: "Nå målet varje dag", descEn: "A perfect week — all seven days.", descSv: "En perfekt vecka — alla sju dagar.", metric: .activeDays, target: 7, cadence: "weekly"),
    ]

    static var todaysDaily: [Challenge] {
        let pool = all.filter { $0.cadence == "daily" }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return (0..<3).map { pool[(day * 3 + $0) % pool.count] }
    }

    static var thisWeeksWeekly: [Challenge] {
        let pool = all.filter { $0.cadence == "weekly" }
        let week = Calendar.current.component(.weekOfYear, from: Date())
        return (0..<2).map { pool[(week * 2 + $0) % pool.count] }
    }

    struct Progress { let current: Double; let target: Double; var done: Bool { target > 0 && current >= target } }

    static func progress(_ c: Challenge, today: HealthKitService, week: [(day: String, steps: Int)],
                         settings: SettingsStore) -> Progress {
        let value: Double
        switch c.metric {
        case .steps: value = Double(today.steps)
        case .distance: value = today.distanceKm
        case .calories: value = Double(today.calories)
        case .exercise: value = Double(today.exerciseMinutes)
        case .screenSaved: value = Double(settings.earnedMin(from: today.steps))
        case .weekSteps: value = Double(week.reduce(0) { $0 + $1.steps })
        case .weekDistance: value = today.distanceKm  // per-day distance history is summed server-side
        case .activeDays: value = Double(week.filter { $0.steps >= settings.dailyGoal }.count)
        }
        return Progress(current: value, target: c.target)
    }

    static func format(_ v: Double, _ metric: Challenge.Metric) -> String {
        switch metric {
        case .distance, .weekDistance: return String(format: "%.1f km", v)
        case .screenSaved, .exercise: return "\(Int(v)) min"
        case .activeDays: return "\(Int(v))"
        default: return Int(v).formatted()
        }
    }
}
