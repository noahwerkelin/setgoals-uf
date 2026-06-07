import { createFileRoute, Link } from "@tanstack/react-router";
import { CheckCircle2, ChevronRight, Flame, Footprints, MapPin, Sparkles, Trophy, Zap } from "lucide-react";
import { useEffect, useMemo } from "react";
import { AppShell } from "@/components/AppShell";
import { ProgressRing } from "@/components/ProgressRing";
import { useT } from "@/lib/i18n";
import { formatDistance, useSettings, earnedMinFromSteps, formatScreenMin } from "@/lib/settings";
import { useTodaySteps } from "@/lib/steps";
import { BADGES, recordDailyActivity, tierStyle, useEarnedBadges } from "@/components/Badges";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "SetGoals — Today" },
      { name: "description", content: "Your daily steps, earned screen time, and goals." },
    ],
  }),
  component: Home,
});

const GOAL = 10000;





const HOLIDAYS: Record<string, string> = {
  "01-01": "home.greeting.newyear",
  "02-14": "home.greeting.valentines",
  "10-31": "home.greeting.halloween",
  "12-24": "home.greeting.christmas",
  "12-25": "home.greeting.christmas",
  "12-26": "home.greeting.christmas",
  "12-31": "home.greeting.nye",
};

function getLocalParts(tz: string) {
  // Timezone-aware extraction of hour + MM-DD in the user's locale timezone
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    hour: "2-digit",
    hour12: false,
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "";
  const hour = parseInt(get("hour"), 10);
  return { hour: isNaN(hour) ? new Date().getHours() : hour % 24, md: `${get("month")}-${get("day")}` };
}

function Home() {
  const { t, lang } = useT();
  const { settings, recordSteps } = useSettings();
  const { data: today } = useTodaySteps();
  const stepsToday = today?.steps ?? 0;
  const distanceKm = today?.distance_km ?? 0;
  const calories = today?.calories ?? 0;
  useEffect(() => {
    if (today) {
      recordSteps(stepsToday, GOAL);
      recordDailyActivity(stepsToday, distanceKm, new Date().getHours());
    }
  }, [today, stepsToday, distanceKm, recordSteps]);
  const now = new Date();
  const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
  const { hour, md } = getLocalParts(tz);
  let greetingKey = "home.greeting.morning";
  if (hour >= 12 && hour < 17) greetingKey = "home.greeting.afternoon";
  else if (hour >= 17 || hour < 5) greetingKey = "home.greeting.evening";
  if (HOLIDAYS[md]) greetingKey = HOLIDAYS[md];
  const capMin = settings.dailyCapHours * 60;
  const earnedMin = earnedMinFromSteps(stepsToday, settings.stepsPer30, settings.dailyCapHours);
  const remainingMin = Math.max(0, capMin - earnedMin);
  const ringProgress = Math.min(1, stepsToday / GOAL);
  const date = now.toLocaleDateString(lang === "sv" ? "sv-SE" : undefined, {
    timeZone: tz,
    weekday: "long",
    month: "short",
    day: "numeric",
  });
  const distance = formatDistance(distanceKm, settings.units);
  const [distValue, distUnit] = distance.split(" ");


  return (
    <AppShell>
      <header className="flex items-end justify-between px-6 pb-4 pt-10 animate-rise">
        <div className="space-y-1">
          <p className="text-sm font-medium text-sage-600">{date}</p>
          <h1 className="text-2xl font-semibold tracking-tight">{t(greetingKey)}, {settings.displayName || "Lukas"}</h1>
        </div>
        <Link to="/profile" aria-label="Profile" className="size-10 overflow-hidden rounded-full bg-sage-200 ring-1 ring-black/5 grid place-items-center text-[10px] font-semibold uppercase tracking-widest text-sage-700">
          {settings.avatar ? (
            <img src={settings.avatar} alt="" className="size-full object-cover" />
          ) : (
            (settings.displayName || "LU").slice(0, 2).toUpperCase()
          )}
        </Link>
      </header>

      <div className="px-6 space-y-6">
        <section
          className="relative flex flex-col items-center gap-6 rounded-[28px] bg-card p-8 ring-1 ring-black/5 animate-rise"
          style={{ animationDelay: "60ms" }}
        >
          <ProgressRing progress={ringProgress} size={224}>
            <div className="text-center space-y-1">
              <span className="block text-4xl font-semibold leading-none tabular-nums">
                {stepsToday.toLocaleString()}
              </span>
              <span className="block text-sm font-medium text-sage-600">
                {t("home.steps_of", { goal: GOAL.toLocaleString() })}
              </span>
            </div>
          </ProgressRing>

          <div className="grid w-full grid-cols-2 divide-x divide-sage-950/5 text-center">
            <div className="space-y-1">
              <p className="text-[10px] font-medium uppercase tracking-wider text-sage-600">{t("home.earned")}</p>
              <p className="text-lg font-medium tabular-nums">{formatScreenMin(earnedMin)}</p>
            </div>
            <div className="space-y-1">
              <p className="text-[10px] font-medium uppercase tracking-wider text-sage-600">{t("home.remaining")}</p>
              <p className="text-lg font-medium tabular-nums text-sage-600">{formatScreenMin(remainingMin)}</p>
            </div>
          </div>
        </section>

        <section className={`grid gap-4 animate-rise ${settings.role === "child" ? "grid-cols-1" : "grid-cols-2"}`} style={{ animationDelay: "120ms" }}>
          {settings.role !== "child" && (
            <StatTile icon={<Flame className="size-4" />} label={t("home.energy")} value={String(calories)} unit="kcal" />
          )}
          <StatTile icon={<Footprints className="size-4" />} label={t("home.distance")} value={distValue} unit={distUnit} />
        </section>

        {settings.role !== "child" && settings.isPro && settings.bonusMinFromYesterday > 0 && (
          <Link
            to="/settings"
            className="flex items-center gap-3 rounded-3xl bg-sage-100 p-4 ring-1 ring-sage-200 animate-rise"
            style={{ animationDelay: "180ms" }}
          >
            <span className="grid size-10 place-items-center rounded-2xl bg-sage-600 text-primary-foreground">
              <Sparkles className="size-5" />
            </span>
            <div className="min-w-0 flex-1">
              <p className="text-[10px] font-semibold uppercase tracking-widest text-sage-700">{t("home.bonus_eyebrow")}</p>
              <p className="text-sm font-medium text-sage-900">{t("home.bonus_text", { n: settings.bonusMinFromYesterday })}</p>
            </div>
          </Link>
        )}

        <Quote />


        <RecentWins />


        <FamilyCard />

        <Link
          to="/leaderboards"
          className="flex items-center justify-between rounded-3xl bg-card p-5 ring-1 ring-black/5 animate-rise"
          style={{ animationDelay: "300ms" }}
        >
          <div className="flex items-center gap-3">
            <span className="grid size-9 place-items-center rounded-xl bg-sage-100 text-sage-700">
              <Zap className="size-4" />
            </span>
            <div>
              <p className="text-sm font-semibold">{t("home.leaderboards")}</p>
              <p className="text-xs text-sage-600">{t("home.lb_sub")}</p>
            </div>
          </div>
          <ChevronRight className="size-4 text-sage-600" />
        </Link>
      </div>
    </AppShell>
  );
}

function SectionTitle({ children }: { children: React.ReactNode }) {
  return <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{children}</h2>;
}

function StatTile({
  icon,
  label,
  value,
  unit,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  unit: string;
}) {
  return (
    <div className="space-y-3 rounded-3xl bg-card p-5 ring-1 ring-black/5">
      <div className="flex items-center gap-2">
        <span className="grid size-7 place-items-center rounded-lg bg-sage-100 text-sage-700">{icon}</span>
        <span className="text-xs font-medium text-sage-600">{label}</span>
      </div>
      <p className="text-xl font-medium tabular-nums">
        {value} <span className="text-xs text-sage-600/60">{unit}</span>
      </p>
    </div>
  );
}

function Badge({ icon, label }: { icon: React.ReactNode; label: string }) {
  return (
    <div className="flex flex-col items-center gap-2 rounded-2xl bg-card p-4 ring-1 ring-black/5">
      <span className="grid size-10 place-items-center rounded-full bg-sage-100 text-sage-700">{icon}</span>
      <span className="text-center text-[11px] font-medium leading-tight text-sage-900">{label}</span>
    </div>
  );
}

const QUOTES: Record<string, { text: string; author: string }[]> = {
  en: [
    { text: "Take care of your body. It's the only place you have to live.", author: "Jim Rohn" },
    { text: "The only bad workout is the one that didn't happen.", author: "Unknown" },
    { text: "Movement is a medicine for creating change in a person's physical, emotional, and mental states.", author: "Carol Welch" },
    { text: "Don't limit your challenges. Challenge your limits.", author: "Jerry Dunn" },
    { text: "A one-hour walk is worth more than an hour of screen time.", author: "SetGoals" },
    { text: "The body achieves what the mind believes.", author: "Napoleon Hill" },
    { text: "Every step you take is a step toward a healthier you.", author: "Unknown" },
    { text: "Your health is an investment, not an expense.", author: "Unknown" },
    { text: "Small daily improvements lead to stunning results.", author: "Unknown" },
    { text: "Energy and persistence conquer all things.", author: "Benjamin Franklin" },
    { text: "If it doesn't challenge you, it doesn't change you.", author: "Fred DeVito" },
    { text: "The hardest part is starting. Once you're moving, momentum carries you.", author: "Unknown" },
    { text: "Health is wealth.", author: "Virgil" },
    { text: "You don't have to be extreme, just consistent.", author: "Unknown" },
    { text: "A journey of a thousand miles begins with a single step.", author: "Lao Tzu" },
    { text: "Fitness is not about being better than someone else. It's about being better than you used to be.", author: "Khloe Kardashian" },
    { text: "The pain you feel today will be the strength you feel tomorrow.", author: "Arnold Schwarzenegger" },
    { text: "Fall in love with taking care of yourself.", author: "Unknown" },
    { text: "An active body fuels an active mind.", author: "Unknown" },
    { text: "Success is the sum of small efforts repeated day in and day out.", author: "Robert Collier" },
    { text: "What seems impossible today will one day become your warm-up.", author: "Unknown" },
    { text: "Your only limit is you.", author: "Unknown" },
    { text: "Action is the foundational key to all success.", author: "Pablo Picasso" },
    { text: "Strive for progress, not perfection.", author: "Unknown" },
    { text: "The best project you'll ever work on is you.", author: "Unknown" },
  ],
  sv: [
    { text: "Ta hand om din kropp. Det är den enda plats du har att bo på.", author: "Jim Rohn" },
    { text: "Det enda dåliga träningspasset är det som aldrig blev av.", author: "Okänd" },
    { text: "Rörelse är ett läkemedel för att skapa förändring i en persons fysiska, emotionella och mentala tillstånd.", author: "Carol Welch" },
    { text: "Begränsa inte dina utmaningar. Utmana dina gränser.", author: "Jerry Dunn" },
    { text: "En timmes promenad är mer värd än en timmes skärmtid.", author: "SetGoals" },
    { text: "Kroppen uppnår det som sinnet tror på.", author: "Napoleon Hill" },
    { text: "Varje steg du tar är ett steg mot en hälsosammare du.", author: "Okänd" },
    { text: "Din hälsa är en investering, inte en utgift.", author: "Okänd" },
    { text: "Små dagliga förbättringar leder till fantastiska resultat.", author: "Okänd" },
    { text: "Energi och uthållighet övervinner allt.", author: "Benjamin Franklin" },
    { text: "Om det inte utmanar dig, förändrar det dig inte.", author: "Fred DeVito" },
    { text: "Det svåraste är att börja. När du väl är igång bär momentum dig framåt.", author: "Okänd" },
    { text: "Hälsa är rikedom.", author: "Virgil" },
    { text: "Du behöver inte vara extrem, bara konsekvent.", author: "Okänd" },
    { text: "En resa på tusen mil börjar med ett enda steg.", author: "Lao Tzu" },
    { text: "Det handlar inte om att vara bättre än någon annan. Det handlar om att vara bättre än du brukade vara.", author: "Khloe Kardashian" },
    { text: "Smärtan du känner idag blir styrkan du känner imorgon.", author: "Arnold Schwarzenegger" },
    { text: "Förälska dig i att ta hand om dig själv.", author: "Okänd" },
    { text: "En aktiv kropp bränsle till en aktiv hjärna.", author: "Okänd" },
    { text: "Framgång är summan av små ansträngningar som upprepas dag ut och dag in.", author: "Robert Collier" },
    { text: "Det som verkar omöjligt idag blir en dag din uppvärmning.", author: "Okänd" },
    { text: "Din enda gräns är du själv.", author: "Okänd" },
    { text: "Handling är grunden till all framgång.", author: "Pablo Picasso" },
    { text: "Sträva efter framsteg, inte perfektion.", author: "Okänd" },
    { text: "Det bästa projektet du någonsin arbetar med är du själv.", author: "Okänd" },
  ],
};

type QuoteState = { lastDate: string; index: number };
const QUOTE_KEY = "sg.quoteState";

function getDailyQuote(lang: string) {
  const pool = QUOTES[lang] ?? QUOTES.en;
  const today = new Date().toISOString().split("T")[0];
  let state: QuoteState = { lastDate: "", index: -1 };
  try {
    const raw = localStorage.getItem(QUOTE_KEY);
    if (raw) state = JSON.parse(raw);
  } catch {}

  if (state.lastDate !== today) {
    state.index = (state.index + 1) % pool.length;
    state.lastDate = today;
    try { localStorage.setItem(QUOTE_KEY, JSON.stringify(state)); } catch {}
  }

  return pool[state.index];
}

function Quote() {
  const { t, lang } = useT();
  const quote = getDailyQuote(lang);
  return (
    <section
      className="rounded-3xl bg-sage-600 p-6 text-primary-foreground ring-1 ring-sage-700/40 animate-rise"
      style={{ animationDelay: "210ms" }}
    >
      <p className="text-[10px] font-medium uppercase tracking-widest text-white/70">{t("home.quote_eyebrow")}</p>
      <p className="mt-2 text-pretty text-[17px] font-medium leading-snug text-white">
        "{quote.text}"
      </p>
      <p className="mt-2 text-xs text-white/80">— {quote.author}</p>
    </section>
  );
}

function FamilyCard() {
  const { t } = useT();
  const rows = [
    { name: "Maja", steps: 8420 },
    { name: "Lukas", steps: 7240 },
    { name: "Dad", steps: 6105 },
  ];
  return (
    <section className="rounded-3xl bg-card p-5 ring-1 ring-black/5 animate-rise" style={{ animationDelay: "270ms" }}>
      <div className="mb-4 flex items-center justify-between">
        <h2 className="text-sm font-semibold">{t("home.family")}</h2>
        <span className="text-[10px] font-medium uppercase tracking-widest text-sage-600">{t("home.today")}</span>
      </div>
      <div className="space-y-4">
        {rows.map((r) => (
          <div key={r.name} className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="size-8 rounded-full bg-sage-100 ring-1 ring-black/5 grid place-items-center text-[10px] font-semibold uppercase text-sage-700">
                {r.name.slice(0, 2)}
              </span>
              <span className="text-sm font-medium">{r.name}</span>
            </div>
            <span className="text-sm font-medium tabular-nums">{r.steps.toLocaleString()}</span>
          </div>
        ))}
      </div>
    </section>
  );
}
