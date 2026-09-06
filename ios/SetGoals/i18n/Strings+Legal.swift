import Foundation

/// Legal & Privacy copy. The document bodies use "## " to start a section
/// heading; every other line is a paragraph. Replace the bodies with the
/// final approved documents — the UI needs no changes when you do.
extension L {
    static let legalStrings: [String: [String: String]] = [
        "en": [
            "legal.title": "Legal & Privacy",
            "legal.sub": "Read the documents that apply to your SetGoals account.",
            "legal.updated": "Last updated {date}",
            "legal.close": "Close",
            "legal.draft_note": "This is placeholder text and not the final document.",

            "legal.privacy.title": "Privacy Policy",
            "legal.terms.title": "Terms of Use",
            "legal.subs.title": "Subscription & Payment Terms",
            "legal.community.title": "Community Guidelines",

            "auth.accept_pre": "I accept the",
            "auth.accept_and": "and",
            "auth.accept_terms": "Terms of Use",
            "auth.accept_privacy": "Privacy Policy",
            "auth.accept_required": "You must accept the Terms of Use and Privacy Policy.",

            "legal.privacy.body": """
## What we collect
Account details you give us (name, username, email, birthday), your step and \
distance activity, screen-time settings and, if you allow it, your approximate location.
## How we use it
To show your progress, run streaks, badges, challenges and leaderboards, and to \
let a parent manage a linked child account.
## Sharing
We do not sell your data. Leaderboards show your name or an anonymous label \
depending on your privacy setting.
## Your choices
You can change your privacy settings, turn location sharing off, or delete your \
account and all related data at any time from Settings.
""",

            "legal.terms.body": """
## Using SetGoals
You need an account to use SetGoals. Keep your login details safe and give us \
accurate information.
## Your content
You are responsible for what you upload, including photos used as task proof or \
profile pictures.
## Health information
SetGoals is a motivation tool, not medical advice. Always listen to your body.
## Ending your use
You can stop using SetGoals and delete your account at any time. We may suspend \
accounts that break these terms or the Community Guidelines.
""",

            "legal.subs.body": """
## Plans
SetGoals PRO and PRO Family are paid subscriptions billed monthly or yearly.
## Renewal
Subscriptions renew automatically until you cancel. Cancelling keeps your access \
until the end of the current billing period.
## PRO Family
PRO Family extends PRO features to the child accounts linked to your account. \
Access ends for those children when the subscription period ends.
## Refunds
Payments are handled by the app store or payment provider you purchased through, \
and their refund rules apply.
""",

            "legal.community.body": """
## Be honest
Do not fake steps or activity to climb leaderboards or earn rewards.
## Be respectful
Choose names, usernames and pictures that are appropriate for all ages.
## Protect children
Parents are responsible for the child accounts they create and manage.
## Reporting
Use "Report a problem" in Settings to tell us about anything that breaks these \
guidelines.
""",
        ],
        "sv": [
            "legal.title": "Juridik & integritet",
            "legal.sub": "Läs dokumenten som gäller för ditt SetGoals-konto.",
            "legal.updated": "Senast uppdaterad {date}",
            "legal.close": "Stäng",
            "legal.draft_note": "Detta är en platshållartext och inte det slutgiltiga dokumentet.",

            "legal.privacy.title": "Integritetspolicy",
            "legal.terms.title": "Användarvillkor",
            "legal.subs.title": "Prenumerations- och betalningsvillkor",
            "legal.community.title": "Communityregler",

            "auth.accept_pre": "Jag godkänner",
            "auth.accept_and": "och",
            "auth.accept_terms": "Användarvillkoren",
            "auth.accept_privacy": "Integritetspolicyn",
            "auth.accept_required": "Du måste godkänna användarvillkoren och integritetspolicyn.",

            "legal.privacy.body": """
## Vad vi samlar in
Kontouppgifter du anger (namn, användarnamn, e-post, födelsedatum), dina steg och \
din distans, inställningar för skärmtid och, om du tillåter det, din ungefärliga plats.
## Hur vi använder det
För att visa dina framsteg, sköta streaks, märken, utmaningar och topplistor, och \
för att en förälder ska kunna hantera ett kopplat barnkonto.
## Delning
Vi säljer inte dina uppgifter. Topplistor visar ditt namn eller en anonym etikett \
beroende på din integritetsinställning.
## Dina val
Du kan när som helst ändra dina integritetsinställningar, stänga av platsdelning \
eller radera ditt konto och all tillhörande data i Inställningar.
""",

            "legal.terms.body": """
## Att använda SetGoals
Du behöver ett konto för att använda SetGoals. Håll dina inloggningsuppgifter \
säkra och lämna korrekta uppgifter.
## Ditt innehåll
Du ansvarar för det du laddar upp, inklusive foton som bevis för uppdrag eller \
som profilbild.
## Hälsoinformation
SetGoals är ett motivationsverktyg, inte medicinsk rådgivning. Lyssna alltid på \
din kropp.
## Avsluta
Du kan sluta använda SetGoals och radera ditt konto när som helst. Vi kan stänga \
av konton som bryter mot villkoren eller communityreglerna.
""",

            "legal.subs.body": """
## Planer
SetGoals PRO och PRO Family är betalda prenumerationer som faktureras månadsvis \
eller årsvis.
## Förnyelse
Prenumerationer förnyas automatiskt tills du säger upp dem. Vid uppsägning \
behåller du åtkomsten till slutet av den pågående perioden.
## PRO Family
PRO Family ger PRO-funktioner till barnkonton som är kopplade till ditt konto. \
Åtkomsten upphör för barnen när prenumerationsperioden tar slut.
## Återbetalning
Betalningar hanteras av den appbutik eller betalleverantör du köpte via, och \
deras regler för återbetalning gäller.
""",

            "legal.community.body": """
## Var ärlig
Fejka inte steg eller aktivitet för att klättra på topplistor eller få belöningar.
## Visa respekt
Välj namn, användarnamn och bilder som passar alla åldrar.
## Skydda barn
Föräldrar ansvarar för de barnkonton de skapar och hanterar.
## Rapportera
Använd "Rapportera ett problem" i Inställningar för att berätta om något som \
bryter mot dessa regler.
""",
        ],
    ]
}
