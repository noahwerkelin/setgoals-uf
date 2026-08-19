import Foundation

/// Port of `src/lib/i18n.tsx`. Only the keys referenced by the ported
/// screens are included; add the rest as more screens are ported.
enum L {
    /// Manual override picked in Settings (`app.lang`), else the device locale.
    static var lang: String {
        if let saved = UserDefaults.standard.string(forKey: "app.lang"), saved == "sv" || saved == "en" {
            return saved
        }
        return Locale.preferredLanguages.first?.hasPrefix("sv") == true ? "sv" : "en"
    }

    static func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        var s = pages[lang]?[key]
            ?? dict[lang]?[key]
            ?? extra[lang]?[key]
            ?? parentStrings[lang]?[key]
            ?? taskStrings[lang]?[key]
            ?? statsStrings[lang]?[key]
            ?? pages["en"]?[key]
            ?? dict["en"]?[key]
            ?? extra["en"]?[key]
            ?? parentStrings["en"]?[key]
            ?? taskStrings["en"]?[key]
            ?? statsStrings["en"]?[key]
            ?? key
        for (k, v) in vars { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
        return s
    }


    static func greeting() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        if h >= 12 && h < 17 { return t("home.greeting.afternoon") }
        if h >= 17 || h < 5 { return t("home.greeting.evening") }
        return t("home.greeting.morning")
    }

    static func quoteOfTheDay() -> String {
        let quotes = dict[lang]?["home.quotes"]?.components(separatedBy: "|") ?? []
        guard !quotes.isEmpty else { return "" }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return quotes[day % quotes.count]
    }

    static let dict: [String: [String: String]] = [
        "en": [
            "nav.home": "Home", "nav.map": "Map", "nav.goals": "Goals",
            "nav.coach": "Coach", "nav.profile": "Profile",

            "home.steps_of": "of {goal} steps",
            "home.earned": "Earned", "home.remaining": "Remaining",
            "home.energy": "Energy", "home.distance": "Distance",
            "home.bonus_gift": "+{m} gifted by your parent",
            "home.greeting.morning": "Good morning",
            "home.greeting.afternoon": "Good afternoon",
            "home.greeting.evening": "Good evening",
            "home.family": "Family today",
            "home.leaderboard": "Leaderboard",
            "home.friends_rank": "You're #{n} with friends today",
            "home.no_friends": "Add friends to compete today",
            "home.quote_eyebrow": "Today's nudge",
            "home.quotes": "Small steps, every day.|Consistency beats intensity.|A short walk still counts.",

            "auth.back": "Back", "auth.welcome": "Welcome back",
            "auth.create": "Create your account", "auth.join_title": "Join your family",
            "auth.forgot_title": "Reset password",
            "auth.sub_signin": "Sign in to keep your streak going.",
            "auth.sub_signup": "Start earning screen time with steps.",
            "auth.join_sub": "Enter the code your parent gave you.",
            "auth.forgot_sub": "We'll email you a reset link.",
            "auth.email": "Email", "auth.password": "Password",
            "auth.password_min": "Password (min 8 characters)",
            "auth.password_short": "Password must be at least 8 characters",
            "auth.display_name": "Name", "auth.username_ph": "Username",
            "auth.username_invalid": "3-20 characters, letters, numbers or _",
            "auth.username_taken": "That username is taken",
            "auth.birthday": "Birthday",
            "auth.forgot": "Forgot password?", "auth.signin": "Sign in",
            "auth.signing_in": "Signing in…", "auth.create_btn": "Create account",
            "auth.creating": "Creating…", "auth.sending": "Sending…",
            "auth.send_reset": "Send reset link",
            "auth.or": "or", "auth.google": "Continue with Google",
            "auth.apple": "Continue with Apple",
            "auth.join_code": "Join with a code",
            "auth.join_cta": "Join", "auth.joining": "Joining…",
            "auth.code_len_error": "The code is 8 characters",
            "auth.code_failed": "That code didn't work",
            "auth.no_account": "No account yet?", "auth.create_one": "Create one",

            "profile.today": "Today", "profile.progress": "Progress",
            "profile.manage": "Manage", "profile.steps": "Steps",
            "profile.earned": "Earned screen time", "profile.streak": "Streak",
            "profile.streak_days": "{n} day streak", "profile.best": "Best {n}",
            "profile.settings": "Settings", "profile.badges": "Badges",
            "profile.sign_out": "Sign out",

            "splash.tagline": "Steps in. Screen time out.",

            "st.cat.social": "Social", "st.cat.games": "Games",
            "st.cat.entertainment": "Entertainment", "st.cat.creativity": "Creativity",
            "st.cat.education": "Education", "st.cat.productivity": "Productivity",
        ],
        "sv": [
            "nav.home": "Hem", "nav.map": "Karta", "nav.goals": "Mål",
            "nav.coach": "Coach", "nav.profile": "Profil",

            "home.steps_of": "av {goal} steg",
            "home.earned": "Intjänat", "home.remaining": "Kvar",
            "home.energy": "Energi", "home.distance": "Distans",
            "home.bonus_gift": "+{m} från din förälder",
            "home.greeting.morning": "God morgon",
            "home.greeting.afternoon": "God eftermiddag",
            "home.greeting.evening": "God kväll",
            "home.family": "Familjen idag",
            "home.leaderboard": "Topplista",
            "home.friends_rank": "Du är #{n} bland vänner idag",
            "home.no_friends": "Lägg till vänner för att tävla idag",
            "home.quote_eyebrow": "Dagens knuff",
            "home.quotes": "Små steg, varje dag.|Uthållighet slår intensitet.|En kort promenad räknas också.",

            "auth.back": "Tillbaka", "auth.welcome": "Välkommen tillbaka",
            "auth.create": "Skapa ditt konto", "auth.join_title": "Gå med i familjen",
            "auth.forgot_title": "Återställ lösenord",
            "auth.sub_signin": "Logga in för att hålla din streak vid liv.",
            "auth.sub_signup": "Börja tjäna skärmtid med steg.",
            "auth.join_sub": "Ange koden du fått av din förälder.",
            "auth.forgot_sub": "Vi mejlar en återställningslänk.",
            "auth.email": "E-post", "auth.password": "Lösenord",
            "auth.password_min": "Lösenord (minst 8 tecken)",
            "auth.password_short": "Lösenordet måste vara minst 8 tecken",
            "auth.display_name": "Namn", "auth.username_ph": "Användarnamn",
            "auth.username_invalid": "3-20 tecken, bokstäver, siffror eller _",
            "auth.username_taken": "Användarnamnet är upptaget",
            "auth.birthday": "Födelsedag",
            "auth.forgot": "Glömt lösenord?", "auth.signin": "Logga in",
            "auth.signing_in": "Loggar in…", "auth.create_btn": "Skapa konto",
            "auth.creating": "Skapar…", "auth.sending": "Skickar…",
            "auth.send_reset": "Skicka länk",
            "auth.or": "eller", "auth.google": "Fortsätt med Google",
            "auth.apple": "Fortsätt med Apple",
            "auth.join_code": "Gå med via kod",
            "auth.join_cta": "Gå med", "auth.joining": "Går med…",
            "auth.code_len_error": "Koden är 8 tecken",
            "auth.code_failed": "Koden fungerade inte",
            "auth.no_account": "Inget konto än?", "auth.create_one": "Skapa ett",

            "profile.today": "Idag", "profile.progress": "Framsteg",
            "profile.manage": "Hantera", "profile.steps": "Steg",
            "profile.earned": "Intjänad skärmtid", "profile.streak": "Streak",
            "profile.streak_days": "{n} dagar i rad", "profile.best": "Bäst {n}",
            "profile.settings": "Inställningar", "profile.badges": "Märken",
            "profile.sign_out": "Logga ut",

            "splash.tagline": "Steg in. Skärmtid ut.",

            "st.cat.social": "Socialt", "st.cat.games": "Spel",
            "st.cat.entertainment": "Underhållning", "st.cat.creativity": "Kreativitet",
            "st.cat.education": "Utbildning", "st.cat.productivity": "Produktivitet",
        ],
    ]
}
