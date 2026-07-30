import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Lock, Sparkles, TrendingUp, TrendingDown, Minus } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { useT } from "@/lib/i18n";
import { useSettings, earnedMinFromSteps, formatScreenMin } from "@/lib/settings";
import { useWeekSteps, useHistorySteps } from "@/lib/steps";
import { ProUpgradeDialog } from "@/components/Pro";
import { computeInsights, buildMessages } from "@/lib/insights";

export const Route = createFileRoute("/stats")({
  head: () => ({
    meta: [
      { title: "Statistics — SetGoals" },
      { name: "description", content: "Daily, weekly, and monthly trends for steps and screen time." },
    ],
  }),
  component: Page,
});

function Page() {
  const { t, lang } = useT();
  const { settings } = useSettings();
  const { data: week = [] } = useWeekSteps();
  const { data: history = [] } = useHistorySteps(180);
  const insights = computeInsights(history, settings.dailyGoal, settings.stepsPer30, settings.dailyCapHours);
  const messages = buildMessages(insights, lang);
  const locale = lang === "sv" ? "sv-SE" : "en-US";
  const WEEK = week.map((d) => d.steps);
  const MAX = Math.max(1, ...WEEK);
  const [proOpen, setProOpen] = useState(false);
  const avg = WEEK.length ? Math.round(WEEK.reduce((a, b) => a + b, 0) / WEEK.length) : 0;
  const weeklyEarnedMin = WEEK.reduce((a, s) => a + earnedMinFromSteps(s, settings.stepsPer30, settings.dailyCapHours), 0);

  const dayLabel = (iso: string, opts: Intl.DateTimeFormatOptions) => {
    const [y, m, d] = iso.split("-").map(Number);
    return new Date(y, (m || 1) - 1, d || 1).toLocaleDateString(locale, opts);
  };

  // Last 7 days vs the 7 days before that — from real logged activity.
  const last7 = history.slice(-7).reduce((a, d) => a + d.steps, 0);
  const prev7 = history.slice(-14, -7).reduce((a, d) => a + d.steps, 0);
  const vsLastPct = prev7 > 0 ? Math.round(((last7 - prev7) / prev7) * 100) : null;

  // Goal completion over the last 30 days (days with any data count toward it).
  const goal = Math.max(1, settings.dailyGoal || 1);
  const last30 = history.slice(-30);
  const goalPct = last30.length
    ? Math.round((last30.filter((d) => d.steps >= goal).length / last30.length) * 100)
    : 0;

  // Active days this week = days that hit the goal.
  const activeDays = week.filter((d) => d.steps >= goal).length;

  // Best day in the last 30 days.
  const best = last30.reduce<{ day: string; steps: number } | null>(
    (acc, d) => (!acc || d.steps > acc.steps ? { day: d.day, steps: d.steps } : acc),
    null,
  );

  // Weekly averages for the trend line (last 8 weeks).
  const weeks: number[] = [];
  for (let i = 8; i >= 1; i--) {
    const slice = history.slice(-7 * i, history.length - 7 * (i - 1));
    weeks.push(slice.length ? slice.reduce((a, d) => a + d.steps, 0) / slice.length : 0);
  }
  const trendMax = Math.max(1, ...weeks);
  const points = weeks.map((v, i) => {
    const x = (i / Math.max(1, weeks.length - 1)) * 300;
    const y = 95 - (v / trendMax) * 85;
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  });
  const linePath = `M${points.join(" L")}`;
  const areaPath = `${linePath} L300,100 L0,100 Z`;
  const recent4 = weeks.slice(-4).reduce((a, b) => a + b, 0);
  const prior4 = weeks.slice(0, 4).reduce((a, b) => a + b, 0);
  const trendPct = prior4 > 0 ? Math.round(((recent4 - prior4) / prior4) * 100) : null;
  const hasTrendData = weeks.some((v) => v > 0);

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
            <span className="rounded-full bg-sage-100 px-3 py-1 text-xs font-medium text-sage-700">
              {vsLastPct === null
                ? t("stats.no_data")
                : t("stats.vs_last", { pct: `${vsLastPct > 0 ? "+" : ""}${vsLastPct}` })}
            </span>
          </div>
          <div className="mt-6 grid grid-cols-7 items-end gap-2 h-40">
            {week.map((d, i) => (
              <div key={d.day} className="flex h-full flex-col items-center gap-2">
                <div className="flex h-full w-full items-end">
                  <div
                    className="w-full rounded-t-lg bg-sage-600"
                    style={{ height: `${(d.steps / MAX) * 100}%`, opacity: i === week.length - 1 ? 1 : 0.55 }}
                  />
                </div>
                <span className="text-[10px] font-medium text-sage-600">
                  {dayLabel(d.day, { weekday: "narrow" }).toUpperCase()}
                </span>
              </div>
            ))}
          </div>
        </section>

        <section className="grid grid-cols-2 gap-4">
          <Card label={t("stats.screen")} value={formatScreenMin(weeklyEarnedMin)} sub={t("stats.screen_sub")} />
          <Card label={t("stats.goal")} value={`${goalPct}%`} sub={t("stats.goal_sub")} />
          <Card label={t("stats.active")} value={`${activeDays} / ${Math.max(1, week.length)}`} sub={t("stats.active_sub")} />
          <Card
            label={t("stats.best")}
            value={best && best.steps > 0 ? best.steps.toLocaleString() : "—"}
            sub={best && best.steps > 0 ? dayLabel(best.day, { weekday: "long" }) : t("stats.no_data")}
          />
        </section>

        <section className="rounded-3xl bg-card p-5 ring-1 ring-black/5">
          <h3 className="text-sm font-semibold">{t("stats.trend")}</h3>
          {hasTrendData ? (
            <>
              <svg viewBox="0 0 300 100" className="mt-3 w-full">
                <path d={linePath} fill="none" stroke="oklch(0.58 0.038 142)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
                <path d={areaPath} fill="oklch(0.58 0.038 142 / 0.12)" />
              </svg>
              <p className="mt-2 text-xs text-sage-600">
                {trendPct === null
                  ? t("stats.no_data")
                  : t("stats.trend_sub", { pct: `${trendPct > 0 ? "+" : ""}${trendPct}` })}
              </p>
            </>
          ) : (
            <p className="mt-3 text-xs text-sage-600">{t("stats.no_data")}</p>
          )}
        </section>

        <section className={`relative overflow-hidden rounded-3xl p-5 ring-1 ${settings.isPro ? "bg-card ring-black/5" : "bg-sage-50 ring-sage-200"}`}>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="grid size-8 place-items-center rounded-xl bg-sage-600 text-primary-foreground">
                <Sparkles className="size-4" />
              </span>
              <h3 className="text-sm font-semibold">{t("stats.pro_title")}</h3>
            </div>
            {!settings.isPro && settings.role !== "child" && (
              <button
                onClick={() => setProOpen(true)}
                className="rounded-xl bg-sage-600 px-3 py-2 text-xs font-semibold text-primary-foreground"
              >
                {t("pro.upgrade")}
              </button>
            )}
          </div>
          <p className="mt-2 text-xs text-sage-600">
            {settings.isPro
              ? t("stats.pro_sub")
              : settings.role === "child"
                ? t("pro.child_desc")
                : t("stats.pro.locked")}
          </p>


          <div className={`mt-4 space-y-4 ${settings.isPro ? "" : "pointer-events-none select-none blur-sm"}`}>
            {/* Activity score */}
            <div className="flex items-center gap-4 rounded-2xl bg-sage-50 p-4 ring-1 ring-black/5">
              <ScoreRing score={insights.activityScore} />
              <div>
                <p className="text-[10px] font-semibold uppercase tracking-wider text-sage-600">
                  {t("stats.pro.score")}
                </p>
                <p className="text-2xl font-semibold tabular-nums">
                  {insights.activityScore}
                  <span className="ml-1 text-sm font-normal text-sage-600">/ 100</span>
                </p>
                <p className="text-xs text-sage-600">{t("stats.pro.score_sub")}</p>
              </div>
            </div>

            {/* Personal messages */}
            {messages.length > 0 && (
              <div className="rounded-2xl bg-sage-50 p-4 ring-1 ring-black/5">
                <p className="text-[10px] font-semibold uppercase tracking-wider text-sage-600">
                  {t("stats.pro.messages")}
                </p>
                <ul className="mt-2 space-y-2">
                  {messages.map((m, i) => (
                    <li key={i} className="flex gap-2 text-sm text-foreground">
                      <span className="mt-1.5 size-1.5 shrink-0 rounded-full bg-sage-600" />
                      <span>{m}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {/* Trends */}
            <div>
              <p className="mb-2 text-[10px] font-semibold uppercase tracking-wider text-sage-600">
                {t("stats.pro.trends")}
              </p>
              <div className="grid grid-cols-3 gap-3">
                <TrendCard label={t("stats.pro.trend7")} value={insights.trend7} />
                <TrendCard label={t("stats.pro.trend30")} value={insights.trend30} />
                <TrendCard label={t("stats.pro.trend90")} value={insights.trend90} />
              </div>
            </div>

            {/* Forecast */}
            <div className="rounded-2xl bg-sage-50 p-4 ring-1 ring-black/5">
              <p className="text-[10px] font-semibold uppercase tracking-wider text-sage-600">
                {t("stats.pro.forecast")}
              </p>
              <p className="mt-1 text-2xl font-semibold tabular-nums">
                {insights.forecastSteps.toLocaleString()}
              </p>
              <p className="text-xs text-sage-600">{t("stats.pro.forecast_sub")}</p>
            </div>
          </div>

          {!settings.isPro && (
            <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
              <Lock className="size-6 text-sage-700" />
            </div>
          )}
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

function ScoreRing({ score }: { score: number }) {
  const size = 72;
  const stroke = 8;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const offset = c * (1 - Math.max(0, Math.min(100, score)) / 100);
  return (
    <div className="relative shrink-0" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="-rotate-90">
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" strokeWidth={stroke} className="text-sage-100" stroke="currentColor" />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          strokeWidth={stroke}
          strokeLinecap="round"
          className="text-sage-600"
          stroke="currentColor"
          strokeDasharray={c}
          strokeDashoffset={offset}
        />
      </svg>
      <div className="absolute inset-0 grid place-items-center text-sm font-semibold tabular-nums">
        {score}
      </div>
    </div>
  );
}

function TrendCard({ label, value }: { label: string; value: number }) {
  const rounded = Math.round(value);
  const up = rounded > 1;
  const down = rounded < -1;
  const Icon = up ? TrendingUp : down ? TrendingDown : Minus;
  const color = up ? "text-emerald-600" : down ? "text-rose-600" : "text-sage-600";
  const sign = rounded > 0 ? "+" : "";
  return (
    <div className="rounded-2xl bg-sage-50 p-3 ring-1 ring-black/5">
      <p className="text-[10px] font-semibold uppercase tracking-wider text-sage-600">{label}</p>
      <div className={`mt-1 flex items-center gap-1 ${color}`}>
        <Icon className="size-4" />
        <p className="text-base font-semibold tabular-nums">{sign}{rounded}%</p>
      </div>
    </div>
  );
}
