import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { CheckCircle2, Circle, Flame, Lock } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Badges, recordLeaderboardRank } from "@/components/Badges";
import { useT } from "@/lib/i18n";
import { useSettings } from "@/lib/settings";
import { ProUpgradeDialog } from "@/components/Pro";
import { toast } from "sonner";

type LbTab = "Friends" | "Local" | "National";
const LB_TABS: LbTab[] = ["Friends", "Local", "National"];
const LB_RANGES = ["Daily", "Weekly", "Monthly"] as const;

const FRIEND_NAMES = ["Maja", "Erik", "Sofia", "Anton", "Olivia", "Noah", "Linnea"];
const LOCAL_NAMES = ["runner_42", "hiker.se", "morning.walk", "trailblazer", "fjord.go", "sunrise.run"];
const NATIONAL_NAMES = ["stepking", "wanderlust", "trailmix", "northern.steps", "pace.master", "ultra.lina"];

function lbRng(seed: number) {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let t = seed;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function dayOfYear(d = new Date()) {
  const start = Date.UTC(d.getUTCFullYear(), 0, 0);
  return Math.floor((d.getTime() - start) / 86400000);
}

function buildLbRows(tab: LbTab, range: (typeof LB_RANGES)[number]) {
  const names =
    tab === "Friends" ? FRIEND_NAMES : tab === "Local" ? LOCAL_NAMES : NATIONAL_NAMES;
  const base = tab === "Friends" ? 6000 : tab === "Local" ? 9000 : 15000;
  const spread = tab === "Friends" ? 8000 : tab === "Local" ? 14000 : 22000;
  const multiplier = range === "Daily" ? 1 : range === "Weekly" ? 6.4 : 27;
  const day = dayOfYear();
  const seed = day * 1000 + (tab === "Friends" ? 1 : tab === "Local" ? 2 : 3) + (range === "Daily" ? 10 : range === "Weekly" ? 20 : 30);
  const r = lbRng(seed);
  const youSteps = Math.round((4500 + r() * 7000) * multiplier);
  const rows = names.map((n) => ({
    n,
    s: Math.round((base + r() * spread) * multiplier),
  }));
  rows.push({ n: "__you__", s: youSteps });
  rows.sort((a, b) => b.s - a.s);
  return rows.slice(0, 6);
}

export const Route = createFileRoute("/challenges")({
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
  return (
    <AppShell>
      <PageHeader eyebrow={t("challenges.eyebrow")} title={t("challenges.title")} />
      <div className="px-6 space-y-6">
        <Tabs defaultValue="goals" className="w-full">
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
  const [range, setRange] = useState<(typeof LB_RANGES)[number]>("Daily");

  const rows = useMemo(() => buildLbRows(tab, range), [tab, range]);

  const dateLabel = useMemo(
    () =>
      new Date().toLocaleDateString(lang === "sv" ? "sv-SE" : undefined, {
        weekday: "short",
        month: "short",
        day: "numeric",
      }),
    [lang],
  );

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

      <div className="flex items-center justify-between gap-2">
        <div className="flex gap-2">
          {LB_RANGES.map((r) => (
            <button
              key={r}
              onClick={() => setRange(r)}
              className={`rounded-full px-3 py-1.5 text-xs font-medium ring-1 ring-black/5 ${
                range === r ? "bg-sage-600 text-primary-foreground" : "bg-card text-sage-700"
              }`}
            >
              {t(`lb.range.${r}`)}
            </button>
          ))}
        </div>
        {range === "Daily" && (
          <span className="text-[10px] font-medium uppercase tracking-wider text-sage-600">
            {t("lb.today_label", { date: dateLabel })}
          </span>
        )}
      </div>

      <ol className="space-y-2">
        {rows.map((row, i) => (
          <li
            key={row.n + i}
            className={`flex items-center gap-4 rounded-2xl p-4 ring-1 animate-rise ${
              row.n === "__you__" ? "bg-sage-600 text-primary-foreground ring-sage-700/40" : "bg-card ring-black/5"
            }`}
            style={{ animationDelay: `${i * 40}ms` }}
          >
            <span className={`grid size-8 place-items-center rounded-full text-xs font-semibold tabular-nums ${row.n === "__you__" ? "bg-white/15 text-white" : "bg-sage-100 text-sage-700"}`}>
              {i + 1}
            </span>
            <span className="flex-1 text-sm font-medium">{row.n === "__you__" ? t("lb.you") : row.n}</span>
            <span className="text-sm font-semibold tabular-nums">{row.s.toLocaleString()}</span>
          </li>
        ))}
      </ol>

      <p className="px-1 text-center text-xs text-sage-600">{t("lb.refresh")} · {t("lb.anon")}</p>
    </div>
  );
}
