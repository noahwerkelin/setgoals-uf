import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { CheckCircle2, Circle, Flame, Sparkles } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Badges, recordLeaderboardRank } from "@/components/Badges";
import { useT, type Lang } from "@/lib/i18n";
import { useSettings } from "@/lib/settings";
import { useAuth } from "@/lib/auth";
import { supabase } from "@/integrations/supabase/client";
import { useServerFn } from "@tanstack/react-start";
import { getLeaderboard, type LeaderboardRow as LbRow } from "@/lib/leaderboard.functions";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useTodaySteps, useWeekSteps } from "@/lib/steps";
import {
  todaysDailyChallenges,
  thisWeeksWeeklyChallenges,
  challengeProgress,
  formatMetric,
  type Challenge,
} from "@/lib/challenges-catalog";

type LbPeriod = "daily" | "weekly" | "monthly" | "alltime";
const LB_PERIODS: LbPeriod[] = ["daily", "weekly", "monthly", "alltime"];

type LeaderboardRow = {
  user_id: string;
  display_name: string;
  username: string;
  avatar_url: string | null;
  total_steps: number;
  rank: number;
};


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


function Page() {
  const { t, lang } = useT();
  const { settings } = useSettings();
  const [detail, setDetail] = useState<Challenge | null>(null);
  const search = Route.useSearch();
  const navigate = useNavigate({ from: Route.fullPath });
  const tab: ChallengesTab = search.tab ?? "goals";

  const { data: today } = useTodaySteps();
  const { data: week } = useWeekSteps();

  const dailyList = todaysDailyChallenges();
  const weeklyList = thisWeeksWeeklyChallenges();
  const ctx = { today: today ?? null, week: week ?? [], settings };

  const streakCount = settings.streak.count;

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
              <p className="mt-1 text-3xl font-semibold tabular-nums">{t("challenges.streak_days", { n: streakCount })}</p>
              <p className="text-sm text-sage-100/80">{t("challenges.streak_sub")}</p>
            </section>

            <section className="space-y-3">
              <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{t("challenges.today")}</h2>
              {dailyList.map((c, i) => {
                const p = challengeProgress(c, ctx);
                const pct = Math.min(1, p.target === 0 ? 0 : p.current / p.target);
                return (
                  <ChallengeRow
                    key={c.id}
                    title={c.title[lang]}
                    progress={pct}
                    done={p.done}
                    delay={i * 50}
                    onClick={() => setDetail(c)}
                  />
                );
              })}
            </section>

            <section className="space-y-3">
              <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{t("challenges.week")}</h2>
              {weeklyList.map((c, i) => {
                const p = challengeProgress(c, ctx);
                const pct = Math.min(1, p.target === 0 ? 0 : p.current / p.target);
                return (
                  <ChallengeRow
                    key={c.id}
                    title={c.title[lang]}
                    progress={pct}
                    done={p.done}
                    delay={150 + i * 50}
                    onClick={() => setDetail(c)}
                  />
                );
              })}
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
      <ChallengeDetailDialog challenge={detail} onOpenChange={(o) => !o && setDetail(null)} ctx={ctx} lang={lang} />
    </AppShell>
  );
}

function ChallengeRow({
  title, progress, done, delay = 0, onClick,
}: { title: string; progress: number; done?: boolean; delay?: number; onClick?: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full items-center gap-4 rounded-3xl bg-card p-4 text-left ring-1 ring-black/5 animate-rise transition hover:ring-sage-300"
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
    </button>
  );
}

function ChallengeDetailDialog({
  challenge, onOpenChange, ctx, lang,
}: {
  challenge: Challenge | null;
  onOpenChange: (o: boolean) => void;
  ctx: { today: import("@/lib/steps").DayTotals | null; week: import("@/lib/steps").DayTotals[]; settings: ReturnType<typeof useSettings>["settings"] };
  lang: Lang;
}) {
  const { t } = useT();
  if (!challenge) {
    return (
      <Dialog open={false} onOpenChange={onOpenChange}>
        <DialogContent />
      </Dialog>
    );
  }
  const p = challengeProgress(challenge, ctx);
  const pct = Math.min(1, p.target === 0 ? 0 : p.current / p.target);
  const resetLabel = challenge.scope === "daily" ? t("challenges.detail.resets_daily") : t("challenges.detail.resets_weekly");
  return (
    <Dialog open onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{challenge.title[lang]}</DialogTitle>
          <DialogDescription>{challenge.desc[lang]}</DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          <div className="rounded-2xl bg-sage-50 p-4">
            <div className="flex items-center justify-between text-xs text-sage-600">
              <span>{t("challenges.detail.progress")}</span>
              <span className="font-semibold tabular-nums">
                {formatMetric(challenge.metric, p.current)} / {formatMetric(challenge.metric, p.target)}
              </span>
            </div>
            <div className="mt-3 h-2 w-full overflow-hidden rounded-full bg-sage-100">
              <div className="h-full rounded-full bg-sage-600" style={{ width: `${pct * 100}%` }} />
            </div>
            <p className="mt-2 text-right text-[11px] font-medium tabular-nums text-sage-600">
              {Math.round(pct * 100)}%
            </p>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="rounded-2xl bg-card p-3 ring-1 ring-black/5">
              <p className="text-[10px] font-medium uppercase tracking-wider text-sage-600">{t("challenges.detail.reward")}</p>
              <p className="mt-1 flex items-center gap-1 text-sm font-semibold">
                <Sparkles className="size-3.5 text-sage-700" /> +{challenge.rewardMin}m
              </p>
            </div>
            <div className="rounded-2xl bg-card p-3 ring-1 ring-black/5">
              <p className="text-[10px] font-medium uppercase tracking-wider text-sage-600">{t("challenges.detail.resets")}</p>
              <p className="mt-1 text-sm font-semibold">{resetLabel}</p>
            </div>
          </div>
          {p.done && (
            <p className="rounded-xl bg-sage-100 px-3 py-2 text-center text-xs font-semibold text-sage-700">
              {t("challenges.detail.done")}
            </p>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}


function Leaderboard() {
  const { t } = useT();
  const { user } = useAuth();
  const qc = useQueryClient();
  const [period, setPeriod] = useState<LbPeriod>("daily");

  const fetchLb = useServerFn(getLeaderboard);
  const { data: rows = [], isLoading } = useQuery({
    queryKey: ["leaderboard", period],
    enabled: !!user,
    queryFn: async (): Promise<LbRow[]> =>
      fetchLb({ data: { period } }) as Promise<LbRow[]>,
  });

  // realtime — refresh leaderboard when any activity_steps changes
  useEffect(() => {
    if (!user) return;
    const ch = supabase
      .channel("lb-activity")
      .on("postgres_changes", { event: "*", schema: "public", table: "activity_steps" }, () => {
        qc.invalidateQueries({ queryKey: ["leaderboard"] });
      })
      .subscribe();
    return () => {
      supabase.removeChannel(ch);
    };
  }, [user, qc]);

  const youRow = rows.find((r) => r.user_id === user?.id);
  const youRank = youRow?.rank ?? 0;
  const top = rows.slice(0, 50);

  useEffect(() => {
    if (period === "daily" && youRank > 0) recordLeaderboardRank("national", youRank);
  }, [period, youRank]);

  return (
    <div className="space-y-5">
      <div className="grid grid-cols-4 gap-1 rounded-2xl bg-card p-1 ring-1 ring-black/5">
        {LB_PERIODS.map((p) => (
          <button
            key={p}
            onClick={() => setPeriod(p)}
            className={`rounded-xl py-2 text-[11px] font-semibold capitalize transition-colors ${
              period === p ? "bg-sage-600 text-primary-foreground" : "text-sage-700"
            }`}
          >
            {p === "alltime" ? "All-time" : p}
          </button>
        ))}
      </div>

      {isLoading ? (
        <p className="rounded-2xl bg-card p-6 text-center text-sm text-sage-600 ring-1 ring-black/5">
          Loading leaderboard…
        </p>
      ) : top.length === 0 ? (
        <p className="rounded-2xl bg-card p-6 text-center text-sm text-sage-600 ring-1 ring-black/5">
          No verified activity yet. Be the first!
        </p>
      ) : (
        <ol className="space-y-2">
          {top.map((row, i) => {
            const isYou = row.user_id === user?.id;
            return (
              <li
                key={row.user_id}
                className={`flex items-center gap-4 rounded-2xl p-4 ring-1 animate-rise ${
                  isYou ? "bg-sage-600 text-primary-foreground ring-sage-700/40" : "bg-card ring-black/5"
                }`}
                style={{ animationDelay: `${i * 20}ms` }}
              >
                <span className={`grid size-8 place-items-center rounded-full text-xs font-semibold tabular-nums ${isYou ? "bg-white/15 text-white" : "bg-sage-100 text-sage-700"}`}>
                  {row.rank}
                </span>
                <span className="flex-1 text-sm font-medium truncate">
                  {isYou ? t("lb.you") : row.display_name}
                </span>
                <span className="text-sm font-semibold tabular-nums">{row.total_steps.toLocaleString()}</span>
              </li>
            );
          })}
        </ol>
      )}

      {youRank > 50 && youRow && (
        <div className="flex items-center gap-4 rounded-2xl bg-sage-600 p-4 text-primary-foreground ring-1 ring-sage-700/40">
          <span className="grid size-8 place-items-center rounded-full bg-white/15 text-xs font-semibold tabular-nums">
            {youRow.rank}
          </span>
          <span className="flex-1 text-sm font-medium">{t("lb.you")}</span>
          <span className="text-sm font-semibold tabular-nums">{youRow.total_steps.toLocaleString()}</span>
        </div>
      )}

      <p className="px-1 text-center text-xs text-sage-600">
        Live updates · Verified step data only
      </p>
    </div>
  );
}


