import Foundation

/// Strings for the statistics PRO insights block and the challenge detail
/// sheet — copied from `src/lib/i18n.tsx`.
extension L {
    static let statsStrings: [String: [String: String]] = [
        "en": [
            "stats.pro_title": "Deeper insights",
            "stats.pro_sub": "Personal patterns, trends, and a forecast built from your activity.",
            "stats.pro.score": "Activity score",
            "stats.pro.score_sub": "out of 100",
            "stats.pro.messages": "For you",
            "stats.pro.trends": "Trends",
            "stats.pro.trend7": "7-day",
            "stats.pro.trend30": "30-day",
            "stats.pro.trend90": "90-day",
            "stats.pro.forecast": "Estimated tomorrow",
            "stats.pro.forecast_sub": "based on your last 30 days",
            "stats.pro.locked": "Unlock personal insights, trends, and a next-day forecast.",

            "challenges.detail.progress": "Progress",
            "challenges.detail.reward": "Reward",
            "challenges.detail.resets": "Resets",
            "challenges.detail.resets_daily": "End of day",
            "challenges.detail.resets_weekly": "End of week",
            "challenges.detail.done": "Challenge complete!",
            "challenges.detail.hint": "Finish this challenge to bank the reward minutes.",
            "challenges.unit.steps": "steps",
            "challenges.unit.days": "days",
            "challenges.unit.complete": "Complete",

            "insights.msg.best_day": "You're hitting more steps on {d}.",
            "insights.msg.weekend_more": "You tend to use more screen time on weekends (+{pct}%).",
            "insights.msg.weekend_less": "You use less screen time on weekends ({pct}%).",
            "insights.msg.trend_up": "You're trending up — +{pct}% over the last 30 days.",
            "insights.msg.trend_down": "Activity is down {pct}% this month.",
            "insights.msg.strong_month": "Strong month — {n}/30 goal days hit.",
            "insights.msg.quietest": "Your quietest day is usually {d}.",
        ],
        "sv": [
            "stats.pro_title": "Djupare insikter",
            "stats.pro_sub": "Personliga mönster, trender och prognos baserat på din aktivitet.",
            "stats.pro.score": "Aktivitetspoäng",
            "stats.pro.score_sub": "av 100",
            "stats.pro.messages": "För dig",
            "stats.pro.trends": "Trender",
            "stats.pro.trend7": "7 dagar",
            "stats.pro.trend30": "30 dagar",
            "stats.pro.trend90": "90 dagar",
            "stats.pro.forecast": "Prognos för imorgon",
            "stats.pro.forecast_sub": "baserat på senaste 30 dagarna",
            "stats.pro.locked": "Lås upp personliga insikter, trender och morgondagens prognos.",

            "challenges.detail.progress": "Framsteg",
            "challenges.detail.reward": "Belöning",
            "challenges.detail.resets": "Återställs",
            "challenges.detail.resets_daily": "Vid dagens slut",
            "challenges.detail.resets_weekly": "Vid veckans slut",
            "challenges.detail.done": "Utmaning klar!",
            "challenges.detail.hint": "Klara utmaningen för att få belöningsminuterna.",
            "challenges.unit.steps": "steg",
            "challenges.unit.days": "dagar",
            "challenges.unit.complete": "Klar",

            "insights.msg.best_day": "Du når flest steg på {d}.",
            "insights.msg.weekend_more": "Du tenderar att använda mer skärmtid på helgerna (+{pct}%).",
            "insights.msg.weekend_less": "Du använder mindre skärmtid på helgerna ({pct}%).",
            "insights.msg.trend_up": "Trenden pekar uppåt — +{pct}% de senaste 30 dagarna.",
            "insights.msg.trend_down": "Aktiviteten har minskat {pct}% senaste månaden.",
            "insights.msg.strong_month": "Stark månad — {n}/30 måldagar klarade.",
            "insights.msg.quietest": "Ditt lugnaste dygn är oftast {d}.",
        ],
    ]

    /// Weekday names used by the insight messages (plural, like the web copy).
    static let weekdayNamesEN = ["Sundays", "Mondays", "Tuesdays", "Wednesdays",
                                 "Thursdays", "Fridays", "Saturdays"]
    static let weekdayNamesSV = ["söndagar", "måndagar", "tisdagar", "onsdagar",
                                 "torsdagar", "fredagar", "lördagar"]

    static func weekdayPlural(_ index: Int) -> String {
        guard index >= 0 && index < 7 else { return "—" }
        return lang == "sv" ? weekdayNamesSV[index] : weekdayNamesEN[index]
    }
}
