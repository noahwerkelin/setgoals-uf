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
Senast uppdaterad: 2026-09-06
Denna integritetspolicy beskriver hur SetGoals UF ("SetGoals", "vi", "oss") behandlar personuppgifter när du använder SetGoals.
Vi tar din integritet på allvar och behandlar personuppgifter i enlighet med tillämplig dataskyddslagstiftning, inklusive EU:s dataskyddsförordning (GDPR).
## 1. Personuppgiftsansvarig
Personuppgiftsansvarig är:
SetGoals UF Sverige
E-post: kontakt@setgoals.se
Om du har frågor om hur vi behandlar dina personuppgifter kan du kontakta oss på ovanstående e-postadress.
## 2. Vilka personuppgifter vi behandlar
Vilka personuppgifter som behandlas beror på vilka funktioner du använder och vilka behörigheter du ger SetGoals.
Konto- och identitetsuppgifter
Vi kan behandla:
• namn,
• användarnamn,
• e-postadress,
• födelsedatum,
• lösenord i säkerhetsmässigt skyddad form,
• profilbild,
• uppgifter som krävs för att administrera ditt konto.
Aktivitets- och hälsodata
Om du ger SetGoals tillstånd att läsa information från Apple HealthKit kan vi behandla:
• antal steg,
• distans,
• kalorier,
• träningsminuter.
Dessa uppgifter används för att tillhandahålla appens aktivitets- och skärmtidsrelaterade funktioner.
Vilka uppgifter som används eller visas kan bero på vilken typ av konto du använder. Exempelvis visas inte kalorier i barnkonton.
HealthKit-data används endast för funktioner som är relevanta för SetGoals och används inte för reklam eller marknadsföring.
Social information
För konton där sociala funktioner är tillgängliga kan vi behandla:
• vilka användare du har lagt till som vänner,
• vilka användare du har blockerat,
• ditt namn,
• ditt användarnamn,
• din profilbild,
• dagens stegantal.
Vissa av dessa uppgifter kan visas för andra användare enligt appens sociala funktioner.
Sociala funktioner är inte tillgängliga i barnkonton. Barnkonton kan därför inte använda funktioner för att söka efter, lägga till eller se andra användares aktivitetsuppgifter.
Tekniska uppgifter
Vi kan behandla tekniska uppgifter som krävs för att tillhandahålla, felsöka och säkra tjänsten, exempelvis:
• information om enhet och operativsystem,
• tekniska identifierare,
• information om appens användning,
• fel- och diagnostikuppgifter.
Exakt vilka tekniska uppgifter som behandlas beror på vilka tekniska lösningar och tjänster som används i den aktuella versionen av appen.
Plats- och rörelsedata
Vissa funktioner, inklusive AI-coachen, kan använda uppgifter om användarens plats eller rörelse när detta är relevant för användarens fråga eller den funktion som används.
Sådana uppgifter används endast när de behövs för den aktuella funktionen och i enlighet med de behörigheter som användaren har lämnat.
Köp och abonnemang
Vi kan behandla information om din abonnemangsstatus, exempelvis om du har PRO eller PRO Family.
Köp av abonnemang via Apple App Store hanteras genom Apples betalningssystem. SetGoals får normalt inte tillgång till användarens fullständiga betalningskortnummer genom sådana köp.
## 3. Varför vi behandlar personuppgifter
Vi behandlar personuppgifter för att:
• skapa och administrera användarkonton,
• tillhandahålla SetGoals funktioner,
• beräkna intjänad skärmtid,
• visa aktivitetsstatistik,
• tillhandahålla sociala funktioner där dessa är tillgängliga,
• tillhandahålla föräldrakontroller,
• tillhandahålla premiumfunktioner,
• hantera abonnemang och behörigheter,
• förebygga missbruk och otillåten användning,
• säkerställa appens tekniska funktion,
• upptäcka och felsöka tekniska problem,
• förbättra appens funktion och användarupplevelse när detta är förenligt med tillämplig lag,
• tillhandahålla AI-coachen,
• behandla plats- och rörelsedata när detta krävs för en funktion som användaren har valt att använda.
HealthKit-data används endast för de ändamål som krävs för SetGoals aktivitets- och fitnessrelaterade funktioner.
HealthKit-data används inte för reklam, marknadsföring eller försäljning av data.
## 4. HealthKit
SetGoals kan begära åtkomst till Apple HealthKit.
Beroende på vilka funktioner som används kan SetGoals läsa:
• steg,
• distans,
• kalorier,
• träningsminuter.
Vi begär endast de behörigheter som behövs för de funktioner som appen tillhandahåller.
Användaren kan när som helst ändra eller återkalla SetGoals åtkomst till HealthKit via Apples inställningar.
Om åtkomsten återkallas kan vissa SetGoals-funktioner sluta fungera eller fungera med begränsad information.
HealthKit-data används inte för:
• annonsering,
• riktad reklam,
• marknadsföring,
• försäljning av personuppgifter,
• användningsbaserad datautvinning för andra ändamål än SetGoals funktioner.
Vi delar inte HealthKit-data med annonsnätverk eller datamäklare.
## 5. Apple Screen Time och föräldrakontroller
SetGoals använder Apples FamilyControls, ManagedSettings och DeviceActivity för funktioner som hjälper användaren att hantera och begränsa användningen av appar.
Dessa funktioner kan kräva särskilda behörigheter från användaren.
Användaren kan bland annat välja vilka appkategorier som ska omfattas av SetGoals skärmtidsfunktioner och vilka appar som alltid ska vara upplåsta, beroende på vilka funktioner och inställningar som är tillgängliga i appen.
SetGoals respekterar de behörigheter och val som användaren lämnar.
Om en nödvändig behörighet återkallas kan funktioner som kräver Screen Time-behörighet sluta fungera.
## 6. Bilder och profilbilder
Om användaren väljer att lägga till en profilbild kan SetGoals använda en bild som användaren själv väljer.
SetGoals använder bilden för att tillhandahålla profilfunktionen och, för konton där sociala funktioner är tillgängliga, visa profilbilden för andra användare enligt appens funktioner.
Vi använder inte användarens bildbibliotek för att skapa en databas över bilder eller för reklam.
SetGoals strävar efter att använda Apples bildväljare och begränsade åtkomst till bilder när detta är möjligt.
## 7. Sociala funktioner
För konton där sociala funktioner är tillgängliga kan användare hitta andra användare genom användarnamn och lägga till dem som vänner.
När två användare är vänner kan följande information visas enligt appens funktioner:
• namn,
• användarnamn,
• profilbild,
• dagens stegantal.
Användaren kan ta bort vänner och blockera andra användare.
Barnkonton har inte tillgång till funktioner för att söka efter, lägga till eller se andra användare och deras aktivitetsuppgifter.
## 8. AI-coach
SetGoals kan erbjuda en AI-coach som hjälper användaren med frågor och information kopplad till appens funktioner.
För att tillhandahålla AI-coachen kan information som är relevant för användarens fråga behöva behandlas av externa tjänsteleverantörer.
Beroende på användarens fråga och vilken information som behövs för att ge ett relevant svar kan detta exempelvis omfatta:
• skärmtidsrelaterad information,
• namn,
• rörelsedata,
• platsinformation.
Endast information som behövs för den aktuella funktionen ska användas.
AI-coachen tillhandahålls med Google Gemini genom Lovable AI Gateway.
AI-coachen är ett tekniskt hjälpmedel och ersätter inte professionell medicinsk, psykologisk eller annan sakkunnig rådgivning.
SetGoals använder inte AI-coachen för att ställa medicinska diagnoser.
## 9. Tredjepartstjänster
SetGoals använder externa tjänster för att tillhandahålla, driva och utveckla appen.
Supabase
Supabase används bland annat för lagring och hantering av appens data.
Supabase kan behandla personuppgifter på uppdrag av SetGoals när detta krävs för att tillhandahålla tjänsten.
Google
Google kan användas för bland annat:
• Google Gemini i samband med AI-coachen,
• Google Maps och kartrelaterade funktioner.
Vilka Google-tjänster som behandlar information beror på vilka funktioner användaren använder och hur den aktuella versionen av appen är konfigurerad.
Lovable
Lovable används bland annat i samband med AI-coachens tekniska funktioner genom Lovable AI Gateway.
Lovable kan behandla information på uppdrag av SetGoals när detta krävs för att tillhandahålla den aktuella funktionen.
Apple
Apple används bland annat för:
• HealthKit,
• FamilyControls,
• ManagedSettings,
• DeviceActivity,
• App Store,
• betalningsinfrastruktur för köp i appen.
Användningen av Apples tjänster omfattas även av Apples egna villkor och integritetspolicy.
## 10. Rättslig grund
Vilken rättslig grund vi använder beror på vilken behandling det gäller.
Det kan exempelvis vara:
• att behandlingen är nödvändig för att fullgöra ett avtal med användaren,
• användarens samtycke,
• att behandlingen är nödvändig för att uppfylla en rättslig skyldighet,
• vårt berättigade intresse, när detta är tillåtet och användarens intressen eller grundläggande rättigheter inte väger tyngre.
För behandling som grundas på samtycke kan användaren återkalla sitt samtycke.
Återkallelse påverkar inte lagligheten av behandling som skett innan samtycket återkallades.
När behandling av barns personuppgifter kräver samtycke från förälder eller vårdnadshavare ska sådant samtycke inhämtas i enlighet med tillämpliga regler.
## 11. Barn och personuppgifter
SetGoals har en angiven minimiålder på 9 år.
Eftersom SetGoals kan användas av barn behandlar vi barns personuppgifter med särskild försiktighet och försöker begränsa insamlingen till vad som behövs för appens funktioner.
Barnkonton har begränsad funktionalitet. De har inte tillgång till appens sociala funktioner för att söka efter, lägga till eller se andra användare och deras aktivitetsuppgifter. Kalorier visas inte i barnkonton.
För användare som enligt tillämplig lag inte själva kan lämna ett giltigt samtycke ska erforderligt samtycke från förälder eller vårdnadshavare inhämtas där lagen kräver det.
SetGoals använder inte barns personuppgifter för riktad reklam baserad på känsliga uppgifter.
Vi försöker inte samla in fler personuppgifter om barn än vad som är nödvändigt för att tillhandahålla de funktioner som barnet använder.
## 12. Hur länge vi sparar uppgifter
Vi sparar personuppgifter så länge det är nödvändigt för de ändamål som beskrivs i denna policy, så länge användaren har ett aktivt konto eller så länge vi har en rättslig skyldighet att behålla uppgifterna.
När ett konto raderas kommer personuppgifter som inte längre behöver behållas att raderas eller anonymiseras inom 14 dagar, om inte längre lagring krävs eller är tillåten enligt lag.
Vissa uppgifter kan behöva sparas längre om detta krävs enligt lag eller för att fastställa, göra gällande eller försvara rättsliga anspråk.
Säkerhetskopior och tekniska loggar kan i vissa fall finnas kvar under en begränsad period efter radering innan de skrivs över eller raderas enligt våra tekniska rutiner.
## 13. Var uppgifter lagras
Personuppgifter kan lagras på servrar som tillhandahålls av våra tjänsteleverantörer, inklusive Supabase och andra leverantörer som används för att tillhandahålla SetGoals.
Vissa tjänsteleverantörer kan behandla personuppgifter utanför EU/EES.
Om personuppgifter överförs utanför EU/EES ska SetGoals använda en laglig överföringsmekanism enligt GDPR när en sådan krävs.
## 14. Säkerhet
Vi vidtar tekniska och organisatoriska säkerhetsåtgärder för att skydda personuppgifter mot obehörig åtkomst, förlust, ändring och förstöring.
Lösenord ska lagras på ett säkert sätt och inte i klartext.
Åtkomst till personuppgifter ska begränsas till vad som behövs för att tillhandahålla och administrera tjänsten.
Ingen internetbaserad tjänst kan dock garanteras vara helt säker.
## 15. Dina rättigheter
Enligt GDPR kan du, beroende på omständigheterna, ha rätt att:
• få information om hur vi behandlar dina personuppgifter,
• få tillgång till dina personuppgifter,
• få felaktiga uppgifter rättade,
• få dina personuppgifter raderade,
• få behandlingen begränsad,
• invända mot viss behandling,
• få ut vissa personuppgifter i ett strukturerat och maskinläsbart format,
• återkalla samtycke när behandlingen grundas på samtycke.
För att utöva dina rättigheter kan du kontakta: kontakt@setgoals.se
Du har även rätt att lämna klagomål till Integritetsskyddsmyndigheten (IMY) om du anser att vår behandling av personuppgifter strider mot GDPR.
## 16. Radering av konto
Användaren kan begära att sitt konto raderas.
När kontot raderas kommer personuppgifter att raderas eller anonymiseras i enlighet med våra lagringsrutiner och våra lagliga skyldigheter.
Radering av ett konto innebär inte automatiskt att information som måste behållas enligt lag omedelbart raderas.
Uppgifter som behövs för att uppfylla rättsliga skyldigheter eller fastställa, göra gällande eller försvara rättsliga anspråk kan behöva behållas under längre tid.
## 17. Ändringar av integritetspolicyn
Vi kan uppdatera denna integritetspolicy när våra tjänster, tekniska lösningar eller rättsliga krav förändras.
Vid större förändringar informerar vi användarna på lämpligt sätt.
Datumet för den senaste uppdateringen anges högst upp i denna policy.
## 18. Kontakt
För frågor om denna integritetspolicy eller SetGoals behandling av personuppgifter:
SetGoals UF Sverige
kontakt@setgoals.se
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
