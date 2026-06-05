import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import { CheckCircle2, Circle, Flame, Lock, MapPin, Globe2, Users } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Badges, recordLeaderboardRank } from "@/components/Badges";
import { useT } from "@/lib/i18n";
import { useSettings } from "@/lib/settings";
import { useUserLocation } from "@/lib/location";
import { useFriends } from "@/lib/friends";
import { ProUpgradeDialog } from "@/components/Pro";
import { toast } from "sonner";

type LbTab = "Friends" | "Local" | "National";
const LB_TABS: LbTab[] = ["Friends", "Local", "National"];

// Realistic name pools for plausible cohort generation.
const NAME_POOLS: Record<string, string[]> = {
  SE: [
    "Maja", "Erik", "Sofia", "Anton", "Olivia", "Noah", "Linnea", "Liam",
    "Alma", "Hugo", "Wilma", "Lucas", "Ebba", "Elias", "Astrid", "Oskar",
    "Saga", "Axel", "Freja", "Viktor", "Selma", "Arvid", "Nora", "Vincent",
    "Tuva", "Isak", "Klara", "Felix", "Iris", "Theo", "Maja_S", "Emil",
  ],
  US: [
    "Liam", "Olivia", "Noah", "Emma", "Oliver", "Ava", "Elijah", "Sophia",
    "Mateo", "Isabella", "Lucas", "Mia", "Levi", "Amelia", "Ethan", "Harper",
    "James", "Evelyn", "Benjamin", "Luna", "Henry", "Ella", "Theodore", "Aria",
  ],
  DEFAULT: [
    "Alex", "Sam", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Quinn",
    "Avery", "Rowan", "Sky", "Jamie", "Cameron", "Drew", "Hayden", "Reese",
    "Parker", "Sage", "Eden", "Ari", "Robin", "Charlie", "Finley", "Emerson",
  ],
};

function dayOfYear(d = new Date()) {
  const start = Date.UTC(d.getUTCFullYear(), 0, 0);
  return Math.floor((d.getTime() - start) / 86400000);
}

function hashStr(s: string) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function rng(seed: number) {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let t = seed;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function getTodaySteps(fallback: number): number {
  try {
    const raw = localStorage.getItem("sg.totals");
    if (raw) {
      const t = JSON.parse(raw) as { lastDate: string | null; totalSteps: number };
      const today = new Date();
      const iso = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;
      if (t.lastDate === iso) return t.totalSteps || fallback;
    }
  } catch {}
  return fallback;
}

function buildCohort(scopeKey: string, countryCode: string, size: number, youSteps: number) {
  const pool = NAME_POOLS[countryCode] ?? NAME_POOLS.DEFAULT;
  const day = dayOfYear();
  const seed = (hashStr(scopeKey) ^ (day * 2654435761)) >>> 0;
  const r = rng(seed);
  // Step ranges scale with cohort scope.
  const base = scopeKey.startsWith("national:") ? 7000 : 5500;
  const spread = scopeKey.startsWith("national:") ? 18000 : 12000;
  const used = new Set<string>();
  const rows: { n: string; s: number }[] = [];
  let guard = 0;
  while (rows.length < size && guard++ < size * 5) {
    const name = pool[Math.floor(r() * pool.length)];
    if (used.has(name)) continue;
    used.add(name);
    rows.push({ n: name, s: Math.round(base + r() * spread) });
  }
  rows.push({ n: "__you__", s: youSteps });
  rows.sort((a, b) => b.s - a.s);
  const youRank = rows.findIndex((x) => x.n === "__you__") + 1;
  return { rows, youRank };
}


type ChallengesTab = "goals" | "badges" | "lb";

export const Route = createFileRoute("/challenges")({
  validateSearch: (search: Record<string, unknown>): { tab?: ChallengesTab } => {
    const tab = search.tab;
    if (tab === "goals" || tab === "badges" || tab === "lb") return { tab };
    return {};
  },
  head: () => ({
    meta: [
      { title: "Goals & Challenges — SetGoals UF" },
      { name: "description", content: "Daily challenges and step goals to earn more screen time." },
    ],
  }),
  component: Page,
});

const TODAY = [
  { key: "t1", progress: 0.88, done: false },
  { key: "t2", progress: 0, done: false },
  { key: "t3", progress: 1, done: true },
];

const WEEKLY = [
  { key: "w1", progress: 0.6 },
  { key: "w2", progress: 0.66 },
];

function Page() {
  const { t } = useT();
  const { settings } = useSettings();
  const [proOpen, setProOpen] = useState(false);
  const search = Route.useSearch();
  const navigate = useNavigate({ from: Route.fullPath });
  const tab: ChallengesTab = search.tab ?? "goals";
  return (
    <AppShell>
      <PageHeader eyebrow={t("challenges.eyebrow")} title={t("challenges.title")} />
      <div className="px-6 space-y-6">
        <Tabs
          value={tab}
          onValueChange={(v) => navigate({ search: { tab: v as ChallengesTab }, replace: true })}
          className="w-full"
        >
          <TabsList className="grid w-full grid-cols-3">
            <TabsTrigger value="goals">{t("challenges.tab.goals")}</TabsTrigger>
            <TabsTrigger value="badges">{t("challenges.tab.badges")}</TabsTrigger>
            <TabsTrigger value="lb">{t("challenges.tab.lb")}</TabsTrigger>
          </TabsList>
          <TabsContent value="goals" className="space-y-6 mt-6">
            <section className="rounded-3xl bg-sage-600 p-6 text-primary-foreground ring-1 ring-sage-700/40 animate-rise">
              <div className="flex items-center gap-2 text-[10px] font-medium uppercase tracking-widest text-sage-100/80">
                <Flame className="size-3.5" /> {t("challenges.streak")}
              </div>
              <p className="mt-1 text-3xl font-semibold tabular-nums">{t("challenges.streak_days", { n: 7 })}</p>
              <p className="text-sm text-sage-100/80">{t("challenges.streak_sub")}</p>
            </section>

            <section className="space-y-3">
              <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{t("challenges.today")}</h2>
              {TODAY.map((c, i) => (
                <ChallengeRow key={c.key} title={t(`challenges.${c.key}`)} progress={c.progress} done={c.done} delay={i * 50} />
              ))}
            </section>

            <section className="space-y-3">
              <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{t("challenges.week")}</h2>
              {WEEKLY.map((c, i) => (
                <ChallengeRow key={c.key} title={t(`challenges.${c.key}`)} progress={c.progress} done={false} delay={150 + i * 50} />
              ))}
            </section>

            <section className="rounded-3xl bg-card p-5 ring-1 ring-black/5">
              <div className="flex items-center justify-between">
                <h3 className="text-sm font-semibold">{t("challenges.custom")}</h3>
                {!settings.isPro && (
                  <span className="rounded-full bg-sage-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-widest text-sage-700">
                    {t("pro.badge")}
                  </span>
                )}
              </div>
              <p className="mt-1 text-xs text-sage-600">
                {settings.isPro ? t("challenges.custom_desc") : t("challenges.pro_lock")}
              </p>
              <button
                onClick={() => {
                  if (!settings.isPro) setProOpen(true);
                  else toast(t("challenges.edit_rules"));
                }}
                className={`mt-3 inline-flex items-center gap-1.5 rounded-xl px-3 py-2 text-xs font-semibold ${
                  settings.isPro ? "bg-sage-100 text-sage-700" : "bg-sage-600 text-primary-foreground"
                }`}
              >
                {!settings.isPro && <Lock className="size-3.5" />}
                {settings.isPro ? t("challenges.edit_rules") : t("pro.unlock")}
              </button>
            </section>
          </TabsContent>

          <TabsContent value="badges" className="mt-6">
            <Badges />
          </TabsContent>

          <TabsContent value="lb" className="mt-6">
            <Leaderboard />
          </TabsContent>
        </Tabs>
      </div>
      <ProUpgradeDialog open={proOpen} onOpenChange={setProOpen} />
    </AppShell>
  );
}

function ChallengeRow({
  title, progress, done, delay = 0,
}: { title: string; progress: number; done?: boolean; delay?: number }) {
  return (
    <article
      className="flex items-center gap-4 rounded-3xl bg-card p-4 ring-1 ring-black/5 animate-rise"
      style={{ animationDelay: `${delay}ms` }}
    >
      <span className={`grid size-10 place-items-center rounded-full ${done ? "bg-sage-600 text-white" : "bg-sage-100 text-sage-700"}`}>
        {done ? <CheckCircle2 className="size-5" /> : <Circle className="size-5" />}
      </span>
      <div className="min-w-0 flex-1">
        <p className={`text-sm font-medium ${done ? "line-through text-sage-600" : ""}`}>{title}</p>
        <div className="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-sage-100">
          <div className="h-full rounded-full bg-sage-600" style={{ width: `${progress * 100}%` }} />
        </div>
      </div>
      <span className="text-xs font-medium tabular-nums text-sage-600">{Math.round(progress * 100)}%</span>
    </article>
  );
}

function Leaderboard() {
  const { t, lang } = useT();
  const [tab, setTab] = useState<LbTab>("Friends");
  const { location, loading } = useUserLocation();
  const { friends } = useFriends();

  const youSteps = useMemo(() => getTodaySteps(7240), []);

  const { rows, youRank, scopeLabel, scopeIcon } = useMemo(() => {
    if (tab === "Friends") {
      const all = [
        ...friends.map((f) => ({ n: f.name, s: f.steps })),
        { n: "__you__", s: youSteps },
      ].sort((a, b) => b.s - a.s);
      const idx = all.findIndex((x) => x.n === "__you__") + 1;
      return {
        rows: all,
        youRank: idx,
        scopeLabel: t("lb.friends_count", { n: friends.length }),
        scopeIcon: "friends" as const,
      };
    }
    if (tab === "Local") {
      const key = `local:${location.countryCode}:${location.region}`;
      const { rows: r, youRank: yr } = buildCohort(key, location.countryCode, 30, youSteps);
      return {
        rows: r.slice(0, 10),
        youRank: yr,
        scopeLabel: t("lb.region_label", { region: location.region }),
        scopeIcon: "local" as const,
      };
    }
    const key = `national:${location.countryCode}`;
    const { rows: r, youRank: yr } = buildCohort(key, location.countryCode, 60, youSteps);
    return {
      rows: r.slice(0, 10),
      youRank: yr,
      scopeLabel: t("lb.country_label", { country: location.country }),
      scopeIcon: "national" as const,
    };
  }, [tab, friends, youSteps, location, t]);

  useEffect(() => {
    if (tab === "Local") recordLeaderboardRank("local", youRank);
    else if (tab === "National") recordLeaderboardRank("national", youRank);
  }, [tab, youRank]);

  const dateLabel = useMemo(
    () =>
      new Date().toLocaleDateString(lang === "sv" ? "sv-SE" : undefined, {
        weekday: "short",
        month: "short",
        day: "numeric",
      }),
    [lang],
  );

  const Icon = scopeIcon === "friends" ? Users : scopeIcon === "local" ? MapPin : Globe2;
  const showYouFloating = tab !== "Friends" && youRank > 10;

  return (
    <div className="space-y-5">
      <div className="grid grid-cols-3 gap-1 rounded-2xl bg-card p-1 ring-1 ring-black/5">
        {LB_TABS.map((tk) => (
          <button
            key={tk}
            onClick={() => setTab(tk)}
            className={`rounded-xl py-2 text-xs font-semibold transition-colors ${
              tab === tk ? "bg-sage-600 text-primary-foreground" : "text-sage-700"
            }`}
          >
            {t(`lb.tab.${tk}`)}
          </button>
        ))}
      </div>

      <div className="flex items-center justify-between gap-2 px-1">
        <span className="inline-flex items-center gap-1.5 text-xs font-medium text-sage-700">
          <Icon className="size-3.5" />
          {loading && tab !== "Friends" ? t("lb.locating") : scopeLabel}
        </span>
        <span className="text-[10px] font-medium uppercase tracking-wider text-sage-600">
          {t("lb.today_label", { date: dateLabel })}
        </span>
      </div>

      {tab === "Friends" && friends.length === 0 ? (
        <p className="rounded-2xl bg-card p-6 text-center text-sm text-sage-600 ring-1 ring-black/5">
          {t("lb.no_friends")}
        </p>
      ) : (
        <ol className="space-y-2">
          {rows.map((row, i) => (
            <li
              key={row.n + i}
              className={`flex items-center gap-4 rounded-2xl p-4 ring-1 animate-rise ${
                row.n === "__you__" ? "bg-sage-600 text-primary-foreground ring-sage-700/40" : "bg-card ring-black/5"
              }`}
              style={{ animationDelay: `${i * 30}ms` }}
            >
              <span className={`grid size-8 place-items-center rounded-full text-xs font-semibold tabular-nums ${row.n === "__you__" ? "bg-white/15 text-white" : "bg-sage-100 text-sage-700"}`}>
                {i + 1}
              </span>
              <span className="flex-1 text-sm font-medium">{row.n === "__you__" ? t("lb.you") : row.n}</span>
              <span className="text-sm font-semibold tabular-nums">{row.s.toLocaleString()}</span>
            </li>
          ))}
        </ol>
      )}

      {showYouFloating && (
        <div className="flex items-center gap-4 rounded-2xl bg-sage-600 p-4 text-primary-foreground ring-1 ring-sage-700/40">
          <span className="grid size-8 place-items-center rounded-full bg-white/15 text-xs font-semibold tabular-nums">
            {youRank}
          </span>
          <span className="flex-1 text-sm font-medium">{t("lb.you")}</span>
          <span className="text-sm font-semibold tabular-nums">{youSteps.toLocaleString()}</span>
        </div>
      )}

      <p className="px-1 text-center text-xs text-sage-600">{t("lb.refresh")} · {t("lb.anon")}</p>
    </div>
  );
}

