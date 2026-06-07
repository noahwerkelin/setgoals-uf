import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Lock, Sparkles } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { useT } from "@/lib/i18n";
import { useSettings, earnedMinFromSteps, formatScreenMin } from "@/lib/settings";
import { useWeekSteps } from "@/lib/steps";
import { ProUpgradeDialog } from "@/components/Pro";

export const Route = createFileRoute("/stats")({
  head: () => ({
    meta: [
      { title: "Statistics — SetGoals" },
      { name: "description", content: "Daily, weekly, and monthly trends for steps and screen time." },
    ],
  }),
  component: Page,
});

const DAY_KEYS = ["M", "T", "W", "T", "F", "S", "S"] as const;

function Page() {
  const { t } = useT();
  const { settings } = useSettings();
  const { data: week = [] } = useWeekSteps();
  const WEEK = week.map((d) => d.steps);
  const MAX = Math.max(1, ...WEEK);
  const [proOpen, setProOpen] = useState(false);
  const avg = WEEK.length ? Math.round(WEEK.reduce((a, b) => a + b, 0) / WEEK.length) : 0;
  const weeklyEarnedMin = WEEK.reduce((a, s) => a + earnedMinFromSteps(s, settings.stepsPer30, settings.dailyCapHours), 0);
  return (
    <AppShell>
      <PageHeader eyebrow={t("stats.eyebrow")} title={t("stats.title")} />
      <div className="px-6 space-y-5">
        <section className="rounded-3xl bg-card p-6 ring-1 ring-black/5 animate-rise">
          <div className="flex items-baseline justify-between">
            <div>
              <p className="text-[10px] font-medium uppercase tracking-widest text-sage-600">{t("stats.avg")}</p>
              <p className="text-3xl font-semibold tabular-nums">{avg.toLocaleString()}</p>
            </div>
            <span className="rounded-full bg-sage-100 px-3 py-1 text-xs font-medium text-sage-700">{t("stats.vs_last")}</span>
          </div>
          <div className="mt-6 grid grid-cols-7 items-end gap-2 h-40">
            {WEEK.map((v, i) => (
              <div key={i} className="flex h-full flex-col items-center gap-2">
                <div className="flex h-full w-full items-end">
                  <div
                    className="w-full rounded-t-lg bg-sage-600"
                    style={{ height: `${(v / MAX) * 100}%`, opacity: i === 4 ? 1 : 0.55 }}
                  />
                </div>
                <span className="text-[10px] font-medium text-sage-600">{t(`stats.day.${DAY_KEYS[i]}`)}</span>
              </div>
            ))}
          </div>
        </section>

        <section className="grid grid-cols-2 gap-4">
          <Card label={t("stats.screen")} value={formatScreenMin(weeklyEarnedMin)} sub={t("stats.screen_sub")} />
          <Card label={t("stats.goal")} value="86%" sub={t("stats.goal_sub")} />
          <Card label={t("stats.active")} value="6 / 7" sub={t("stats.active_sub")} />
          <Card label={t("stats.best")} value="11,200" sub={t("stats.best_sub")} />
        </section>

        <section className="rounded-3xl bg-card p-5 ring-1 ring-black/5">
          <h3 className="text-sm font-semibold">{t("stats.trend")}</h3>
          <svg viewBox="0 0 300 100" className="mt-3 w-full">
            <path
              d="M0,80 C40,60 70,70 100,55 S180,30 220,40 S290,20 300,25"
              fill="none"
              stroke="oklch(0.58 0.038 142)"
              strokeWidth="2.5"
              strokeLinecap="round"
            />
            <path
              d="M0,80 C40,60 70,70 100,55 S180,30 220,40 S290,20 300,25 L300,100 L0,100 Z"
              fill="oklch(0.58 0.038 142 / 0.12)"
            />
          </svg>
          <p className="mt-2 text-xs text-sage-600">{t("stats.trend_sub")}</p>
        </section>

        <section className={`rounded-3xl p-5 ring-1 ${settings.isPro ? "bg-card ring-black/5" : "bg-sage-50 ring-sage-200"}`}>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="grid size-8 place-items-center rounded-xl bg-sage-600 text-primary-foreground">
                <Sparkles className="size-4" />
              </span>
              <h3 className="text-sm font-semibold">{t("stats.pro_title")}</h3>
            </div>
            {!settings.isPro && (
              <button
                onClick={() => setProOpen(true)}
                className="rounded-xl bg-sage-600 px-3 py-2 text-xs font-semibold text-primary-foreground"
              >
                {t("pro.upgrade")}
              </button>
            )}
          </div>
          <p className="mt-2 text-xs text-sage-600">{t("stats.pro_sub")}</p>
          <div className="mt-3 grid grid-cols-3 gap-3">
            {["stats.pro1", "stats.pro2", "stats.pro3"].map((k) => (
              <div key={k} className="relative rounded-2xl bg-sage-50 p-3 ring-1 ring-black/5">
                <p className="text-[10px] font-semibold uppercase tracking-wider text-sage-600">{t(k)}</p>
                <p className={`mt-1 text-base font-semibold tabular-nums ${settings.isPro ? "" : "blur-sm select-none"}`}>
                  {k === "stats.pro1" ? "42m" : k === "stats.pro2" ? "78" : "+18%"}
                </p>
                {!settings.isPro && (
                  <Lock className="absolute right-2 top-2 size-3.5 text-sage-600" />
                )}
              </div>
            ))}
          </div>
        </section>
      </div>
      <ProUpgradeDialog open={proOpen} onOpenChange={setProOpen} />
    </AppShell>
  );
}

function Card({ label, value, sub }: { label: string; value: string; sub: string }) {
  return (
    <div className="rounded-2xl bg-card p-4 ring-1 ring-black/5">
      <p className="text-[10px] font-medium uppercase tracking-wider text-sage-600">{label}</p>
      <p className="mt-1 text-xl font-semibold tabular-nums">{value}</p>
      <p className="text-xs text-sage-600">{sub}</p>
    </div>
  );
}
