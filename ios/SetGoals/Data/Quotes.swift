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
        Quote(text: "Walking is the best possible exercise. Habituate yourself to walk very far.", author: "Thomas Jefferson"),
        Quote(text: "It does not matter how slowly you go as long as you do not stop.", author: "Confucius"),
        Quote(text: "The groundwork of all happiness is health.", author: "Leigh Hunt"),
        Quote(text: "Motivation gets you started. Habit keeps you going.", author: "Jim Ryun"),
        Quote(text: "The best time to plant a tree was twenty years ago. The second best time is now.", author: "Chinese proverb"),
        Quote(text: "Walk as if you are kissing the Earth with your feet.", author: "Thich Nhat Hanh"),
        Quote(text: "Everywhere is walking distance if you have the time.", author: "Steven Wright"),
        Quote(text: "To keep the body in good health is a duty.", author: "Buddha"),
        Quote(text: "One step at a time is good walking.", author: "Chinese proverb"),
        Quote(text: "The reason I exercise is for the quality of life I enjoy.", author: "Kenneth H. Cooper"),
        Quote(text: "Do something today that your future self will thank you for.", author: "Unknown"),
        Quote(text: "An early-morning walk is a blessing for the whole day.", author: "Henry David Thoreau"),
        Quote(text: "Discipline is choosing what you want most over what you want now.", author: "Unknown"),
        Quote(text: "A little progress each day adds up to big results.", author: "Unknown"),
        Quote(text: "Take a walk outside — it will clear your mind and move your body.", author: "Unknown"),
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
        Quote(text: "Promenader är den bästa möjliga motionen. Vänj dig vid att gå långt.", author: "Thomas Jefferson"),
        Quote(text: "Det spelar ingen roll hur långsamt du går, så länge du inte stannar.", author: "Konfucius"),
        Quote(text: "Grunden till all lycka är hälsa.", author: "Leigh Hunt"),
        Quote(text: "Motivation får dig att börja. Vanor håller dig igång.", author: "Jim Ryun"),
        Quote(text: "Den bästa tiden att plantera ett träd var för tjugo år sedan. Den näst bästa tiden är nu.", author: "Kinesiskt ordspråk"),
        Quote(text: "Gå som om du kysser jorden med dina fötter.", author: "Thich Nhat Hanh"),
        Quote(text: "Allt är gångavstånd om du har tid.", author: "Steven Wright"),
        Quote(text: "Att hålla kroppen frisk är en plikt.", author: "Buddha"),
        Quote(text: "Ett steg i taget är bra gång.", author: "Kinesiskt ordspråk"),
        Quote(text: "Anledningen till att jag tränar är livskvaliteten jag får.", author: "Kenneth H. Cooper"),
        Quote(text: "Gör något idag som ditt framtida jag kommer att tacka dig för.", author: "Okänd"),
        Quote(text: "En tidig morgonpromenad är en välsignelse för hela dagen.", author: "Henry David Thoreau"),
        Quote(text: "Disciplin är att välja det du vill ha mest framför det du vill ha nu.", author: "Okänd"),
        Quote(text: "Lite framsteg varje dag blir stora resultat.", author: "Okänd"),
        Quote(text: "Ta en promenad utomhus – det klarnar sinnet och rör på kroppen.", author: "Okänd"),
    ]

    /// One quote per day, advancing through the pool like the web version.
    static func today() -> Quote {
        let pool = L.lang == "sv" ? sv : en
        let day = Int(Date().timeIntervalSince1970 / 86_400)
        return pool[abs(day) % pool.count]
    }
}
