import Foundation

/// Home dashboard copy (redesigned Today view).
extension L {
    static let homeStrings: [String: [String: String]] = [
        "en": [
            "home2.greeting": "{g}, {name}!",
            "home2.streak": "{n}-day streak",
            "home2.streak_none": "Hit your goal today to start a streak",
            "home2.steps_of": "{s} / {g} steps",
            "home2.daily_goal": "of {g} daily step goal",
            "home2.minutes": "{n} min",
            "home2.quote": "Quote of the day",
            "home2.goal_reached": "Goal reached",
            "home2.earned": "Earned screen time",
            "home2.remaining": "Remaining screen time",
            "home2.time_up": "Time's up for today",
            "home2.challenge_bonus": "Challenge bonus",
            "home2.parent_gift": "Gift from parent",
            "home2.rollover": "Rollover from yesterday",
            "home2.distance": "Distance",
            "home2.energy": "Energy",
            "home2.family": "Family",
            "home2.your_parent": "Your parent",
            "home2.no_children": "No children added yet.",
            "home2.add_child": "Add Child",
            "home2.view_family": "View Family",
            "home2.friends": "Friends today",
            "home2.no_friends": "No friends added yet.",
            "home2.no_friends_sub": "Add a friend and see who walks the most today.",
            "home2.add_friend": "Add Friend",
            "home2.view_friends": "View Friends",
            "home2.you": "You",
            "home2.steps_unit": "steps",
            "home2.recent_wins": "Recent Wins",
            "home2.no_badges": "No badges earned yet.",
            "home2.no_badges_sub": "Keep moving and completing challenges to unlock your first badge!",
            "home2.view_all": "View All",
            "home2.ring_a11y": "{p} percent of today's step goal",
        ],
        "sv": [
            "home2.greeting": "{g}, {name}!",
            "home2.streak": "{n} dagars svit",
            "home2.streak_none": "Nå ditt mål idag för att starta en svit",
            "home2.steps_of": "{s} / {g} steg",
            "home2.daily_goal": "av dagens stegmål på {g}",
            "home2.minutes": "{n} min",
            "home2.quote": "Dagens citat",
            "home2.goal_reached": "Målet nått",
            "home2.earned": "Intjänad skärmtid",
            "home2.remaining": "Återstående skärmtid",
            "home2.time_up": "Tiden är slut för idag",
            "home2.challenge_bonus": "Utmaningsbonus",
            "home2.parent_gift": "Gåva från förälder",
            "home2.rollover": "Sparat från igår",
            "home2.distance": "Distans",
            "home2.energy": "Energi",
            "home2.family": "Familj",
            "home2.your_parent": "Din förälder",
            "home2.no_children": "Inga barn tillagda ännu.",
            "home2.add_child": "Lägg till barn",
            "home2.view_family": "Visa familj",
            "home2.friends": "Vänner idag",
            "home2.no_friends": "Inga vänner tillagda ännu.",
            "home2.no_friends_sub": "Lägg till en vän och se vem som går mest idag.",
            "home2.add_friend": "Lägg till vän",
            "home2.view_friends": "Visa vänner",
            "home2.you": "Du",
            "home2.steps_unit": "steg",
            "home2.recent_wins": "Senaste framgångar",
            "home2.no_badges": "Inga märken intjänade ännu.",
            "home2.no_badges_sub": "Fortsätt röra på dig och klara utmaningar för att låsa upp ditt första märke!",
            "home2.view_all": "Visa alla",
            "home2.ring_a11y": "{p} procent av dagens stegmål",
        ],
    ]

    static var locale: Locale { Locale(identifier: lang == "sv" ? "sv_SE" : "en_US") }

    static func number(_ n: Int) -> String {
        n.formatted(.number.locale(locale))
    }

    /// "2h 30m" / "2 tim 30 min".
    static func duration(_ minutes: Int) -> String {
        let m = max(0, minutes), h = m / 60, r = m % 60
        if lang == "sv" {
            if h == 0 { return "\(r) min" }
            return r == 0 ? "\(h) tim" : "\(h) tim \(r) min"
        }
        if h == 0 { return "\(r)m" }
        return r == 0 ? "\(h)h" : "\(h)h \(r)m"
    }
}
