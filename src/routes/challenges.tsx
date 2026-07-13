import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { CheckCircle2, Circle, Flame, Lock, Sparkles } from "lucide-react";
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
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { ProUpgradeDialog } from "@/components/Pro";
import { toast } from "sonner";
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
  const { t } = useT();
  const { user } = useAuth();
  const qc = useQueryClient();
  const [period, setPeriod] = useState<LbPeriod>("daily");

  const { data: rows = [], isLoading } = useQuery({
    queryKey: ["leaderboard", period],
    enabled: !!user,
    queryFn: async (): Promise<LeaderboardRow[]> => {
      const { data, error } = await supabase.rpc("leaderboard", { _period: period });
      if (error) throw error;
      return (data ?? []) as LeaderboardRow[];
    },
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


