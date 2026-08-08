import Foundation

/// Port of the daily quote pool in `src/routes/index.tsx`.
struct Quote {
    let text: String
    let author: String
}

enum Quotes {
    static let en: [Quote] = [
        Quote(text: "Take care of your body. It's the only place you have to live.", author: "Jim Rohn"),
        Quote(text: "The only bad workout is the one that didn't happen.", author: "Unknown"),
        Quote(text: "Movement is a medicine for creating change in a person's physical, emotional, and mental states.", author: "Carol Welch"),
        Quote(text: "Don't limit your challenges. Challenge your limits.", author: "Jerry Dunn"),
        Quote(text: "A one-hour walk is worth more than an hour of screen time.", author: "SetGoals"),
        Quote(text: "The body achieves what the mind believes.", author: "Napoleon Hill"),
        Quote(text: "Every step you take is a step toward a healthier you.", author: "Unknown"),
        Quote(text: "Your health is an investment, not an expense.", author: "Unknown"),
        Quote(text: "Small daily improvements lead to stunning results.", author: "Unknown"),
        Quote(text: "Energy and persistence conquer all things.", author: "Benjamin Franklin"),
        Quote(text: "If it doesn't challenge you, it doesn't change you.", author: "Fred DeVito"),
        Quote(text: "The hardest part is starting. Once you're moving, momentum carries you.", author: "Unknown"),
        Quote(text: "Health is wealth.", author: "Virgil"),
        Quote(text: "You don't have to be extreme, just consistent.", author: "Unknown"),
        Quote(text: "A journey of a thousand miles begins with a single step.", author: "Lao Tzu"),
        Quote(text: "Fitness is not about being better than someone else. It's about being better than you used to be.", author: "Khloe Kardashian"),
        Quote(text: "The pain you feel today will be the strength you feel tomorrow.", author: "Arnold Schwarzenegger"),
        Quote(text: "Fall in love with taking care of yourself.", author: "Unknown"),
        Quote(text: "An active body fuels an active mind.", author: "Unknown"),
        Quote(text: "Success is the sum of small efforts repeated day in and day out.", author: "Robert Collier"),
        Quote(text: "What seems impossible today will one day become your warm-up.", author: "Unknown"),
        Quote(text: "Your only limit is you.", author: "Unknown"),
        Quote(text: "Action is the foundational key to all success.", author: "Pablo Picasso"),
        Quote(text: "Strive for progress, not perfection.", author: "Unknown"),
        Quote(text: "The best project you'll ever work on is you.", author: "Unknown"),
    ]

    static let sv: [Quote] = [
        Quote(text: "Ta hand om din kropp. Det är den enda plats du har att bo på.", author: "Jim Rohn"),
        Quote(text: "Det enda dåliga träningspasset är det som aldrig blev av.", author: "Okänd"),
        Quote(text: "Rörelse är ett läkemedel för att skapa förändring i en persons fysiska, emotionella och mentala tillstånd.", author: "Carol Welch"),
        Quote(text: "Begränsa inte dina utmaningar. Utmana dina gränser.", author: "Jerry Dunn"),
        Quote(text: "En timmes promenad är mer värd än en timmes skärmtid.", author: "SetGoals"),
        Quote(text: "Kroppen uppnår det som sinnet tror på.", author: "Napoleon Hill"),
        Quote(text: "Varje steg du tar är ett steg mot en hälsosammare du.", author: "Okänd"),
        Quote(text: "Din hälsa är en investering, inte en utgift.", author: "Okänd"),
        Quote(text: "Små dagliga förbättringar leder till fantastiska resultat.", author: "Okänd"),
        Quote(text: "Energi och uthållighet övervinner allt.", author: "Benjamin Franklin"),
        Quote(text: "Om det inte utmanar dig, förändrar det dig inte.", author: "Fred DeVito"),
        Quote(text: "Det svåraste är att börja. När du väl är igång bär momentum dig framåt.", author: "Okänd"),
        Quote(text: "Hälsa är rikedom.", author: "Virgil"),
        Quote(text: "Du behöver inte vara extrem, bara konsekvent.", author: "Okänd"),
        Quote(text: "En resa på tusen mil börjar med ett enda steg.", author: "Lao Tzu"),
        Quote(text: "Det handlar inte om att vara bättre än någon annan. Det handlar om att vara bättre än du brukade vara.", author: "Khloe Kardashian"),
        Quote(text: "Smärtan du känner idag blir styrkan du känner imorgon.", author: "Arnold Schwarzenegger"),
        Quote(text: "Förälska dig i att ta hand om dig själv.", author: "Okänd"),
        Quote(text: "En aktiv kropp bränsle till en aktiv hjärna.", author: "Okänd"),
        Quote(text: "Framgång är summan av små ansträngningar som upprepas dag ut och dag in.", author: "Robert Collier"),
        Quote(text: "Det som verkar omöjligt idag blir en dag din uppvärmning.", author: "Okänd"),
        Quote(text: "Din enda gräns är du själv.", author: "Okänd"),
        Quote(text: "Handling är grunden till all framgång.", author: "Pablo Picasso"),
        Quote(text: "Sträva efter framsteg, inte perfektion.", author: "Okänd"),
        Quote(text: "Det bästa projektet du någonsin arbetar med är du själv.", author: "Okänd"),
    ]

    /// One quote per day, advancing through the pool like the web version.
    static func today() -> Quote {
        let pool = L.lang == "sv" ? sv : en
        let day = Int(Date().timeIntervalSince1970 / 86_400)
        return pool[abs(day) % pool.count]
    }
}
