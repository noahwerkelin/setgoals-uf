import type { DayTotals } from "./steps";
import { earnedMinFromSteps } from "./settings";

export type Insights = {
  activityScore: number;
  trend7: number;
  trend30: number;
  trend90: number;
  forecastSteps: number;
  bestWeekday: string;
  worstWeekday: string;
  weekendScreenBias: number; // % more screen earned on weekends vs weekdays
  activeDays: number;
  stepsToday: number;
  goalLeftToday: number;
  avgSteps30: number;
  personalBestSteps: number;
  personalBestDay: string;
  goalStreak: number;
};

const WEEKDAYS_EN = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const WEEKDAYS_SV = ["söndagar", "måndagar", "tisdagar", "onsdagar", "torsdagar", "fredagar", "lördagar"];

export function weekdayLabel(name: string, lang: "en" | "sv"): string {
  const i = WEEKDAYS_EN.indexOf(name);
  if (i < 0) return name;
  return lang === "sv" ? WEEKDAYS_SV[i] : name;
}

function avg(xs: number[]): number {
  return xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0;
}

function pctChange(a: number, b: number): number {
  if (b === 0) return a === 0 ? 0 : 100;
  return ((a - b) / b) * 100;
}

// simple linear regression slope + intercept
function linreg(ys: number[]): { slope: number; intercept: number } {
  const n = ys.length;
  if (!n) return { slope: 0, intercept: 0 };
  const xs = ys.map((_, i) => i);
  const mx = avg(xs);
  const my = avg(ys);
  let num = 0;
  let den = 0;
  for (let i = 0; i < n; i++) {
    num += (xs[i] - mx) * (ys[i] - my);
    den += (xs[i] - mx) ** 2;
  }
  const slope = den === 0 ? 0 : num / den;
  return { slope, intercept: my - slope * mx };
}

export function computeInsights(
  history: DayTotals[],
  dailyGoal: number,
  stepsPer30: number,
  dailyCapHours: number,
): Insights {
  const steps = history.map((d) => d.steps);
  const n = steps.length;

  const last7 = steps.slice(-7);
  const prev7 = steps.slice(-14, -7);
  const last30 = steps.slice(-30);
  const prev30 = steps.slice(-60, -30);
  const last90 = steps.slice(-90);
  const prev90 = steps.slice(-180, -90);

  const trend7 = pctChange(avg(last7), avg(prev7));
  const trend30 = pctChange(avg(last30), avg(prev30));
  const trend90 = pctChange(avg(last90), avg(prev90));

  // Forecast next-day steps from last 30d linear trend
  const window = last30.length ? last30 : last7;
  const { slope, intercept } = linreg(window);
  const forecastSteps = Math.max(0, Math.round(slope * window.length + intercept));

  // Weekday averages (based on last 30 days)
  const buckets: number[][] = Array.from({ length: 7 }, () => []);
  const src = history.slice(-30);
  for (const d of src) {
    const dow = new Date(d.day + "T00:00:00").getDay();
    buckets[dow].push(d.steps);
  }
  const dayAvgs = buckets.map((b) => avg(b));
  const maxIdx = dayAvgs.indexOf(Math.max(...dayAvgs));
  const nonZero = dayAvgs.map((v) => (v === 0 ? Infinity : v));
  const minIdx = nonZero.indexOf(Math.min(...nonZero));

  // Weekend vs weekday screen time bias
  let weekendMin = 0;
  let weekendCount = 0;
  let weekdayMin = 0;
  let weekdayCount = 0;
  for (const d of src) {
    const dow = new Date(d.day + "T00:00:00").getDay();
    const min = earnedMinFromSteps(d.steps, stepsPer30, dailyCapHours);
    if (dow === 0 || dow === 6) {
      weekendMin += min;
      weekendCount++;
    } else {
      weekdayMin += min;
      weekdayCount++;
    }
  }
  const weAvg = weekendCount ? weekendMin / weekendCount : 0;
  const wdAvg = weekdayCount ? weekdayMin / weekdayCount : 0;
  const weekendScreenBias = pctChange(weAvg, wdAvg);

  // Activity score
  const goalHitRatio = last30.length
    ? last30.filter((s) => s >= dailyGoal).length / last30.length
    : 0;
  const avgRatio = Math.min(1, avg(last30) / Math.max(1, dailyGoal));
  const consistency = last30.length
    ? 1 - Math.min(1, stdev(last30) / Math.max(1, avg(last30) || 1))
    : 0;
  const trendComponent = Math.max(0, Math.min(1, 0.5 + trend30 / 200));
  const activityScore = Math.round(
    (goalHitRatio * 40 + avgRatio * 30 + consistency * 15 + trendComponent * 15),
  );

  const activeDays = last30.filter((s) => s >= dailyGoal).length;

  // Today, personal best and current goal streak.
  const now = new Date();
  const todayKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
  const todayRow = history[history.length - 1];
  const stepsToday = todayRow && todayRow.day === todayKey ? todayRow.steps : 0;
  const goalLeftToday = Math.max(0, dailyGoal - stepsToday);
  const avgSteps30 = Math.round(avg(last30));
  let personalBestSteps = 0;
  let personalBestDay = "";
  for (const d of history.slice(-30)) {
    if (d.steps > personalBestSteps) {
      personalBestSteps = d.steps;
      personalBestDay = d.day;
    }
  }
  let goalStreak = 0;
  for (let i = history.length - 1; i >= 0; i--) {
    const d = history[i];
    if (d.steps >= dailyGoal) goalStreak++;
    else if (d.day === todayKey) continue; // today may still be in progress
    else break;
  }

  return {
    activityScore: Math.max(0, Math.min(100, activityScore)),
    trend7,
    trend30,
    trend90,
    forecastSteps,
    bestWeekday: WEEKDAYS_EN[maxIdx] ?? "—",
    worstWeekday: WEEKDAYS_EN[minIdx] ?? "—",
    weekendScreenBias,
    activeDays,
    stepsToday,
    goalLeftToday,
    avgSteps30,
    personalBestSteps,
    personalBestDay,
    goalStreak,
  };
  function stdev(xs: number[]): number {
    const m = avg(xs);
    return Math.sqrt(avg(xs.map((x) => (x - m) ** 2)));
  }
}

function capitalize(s: string): string {
  return s ? s[0].toUpperCase() + s.slice(1) : s;
}

/**
 * Personal, coach-style notes derived from the user's own history — no chat,
 * no AI: every number comes straight from logged activity.
 */
export function buildMessages(ins: Insights, lang: "en" | "sv", name?: string): string[] {
  const msgs: string[] = [];
  const best = weekdayLabel(ins.bestWeekday, lang);
  const worst = weekdayLabel(ins.worstWeekday, lang);
  const who = name?.trim() || (lang === "sv" ? "du" : "you");
  const walkMin = Math.max(5, Math.round(ins.goalLeftToday / 100));
  const locale = lang === "sv" ? "sv-SE" : "en-US";

  if (lang === "sv") {
    if (ins.goalLeftToday > 0) {
      msgs.push(`${who}, du är ${ins.goalLeftToday.toLocaleString(locale)} steg från dagens mål — ungefär ${walkMin} minuters promenad kvar.`);
    } else {
      msgs.push(`Dagens mål är klart, ${who} — snyggt jobbat.`);
    }
    if (ins.goalStreak >= 3) msgs.push(`${ins.goalStreak} dagar i rad med målet nått — håll serien vid liv.`);
    if (ins.trend30 > 5) msgs.push(`Trenden pekar uppåt — +${Math.round(ins.trend30)}% de senaste 30 dagarna. Fortsätt så.`);
    else if (ins.trend30 < -5) msgs.push(`Aktiviteten har minskat ${Math.round(Math.abs(ins.trend30))}% senaste månaden — en kort kvällspromenad om dagen vänder det.`);
    msgs.push(`${capitalize(best)} är dina starkaste dagar — lägg långpromenaderna där.`);
    if (worst !== best) msgs.push(`${capitalize(worst)} brukar vara lugna — en kort kvällsrunda kan ändra det.`);
    if (ins.personalBestSteps > 0) msgs.push(`Din bästa dag den här månaden: ${ins.personalBestSteps.toLocaleString(locale)} steg. Slå den i veckan.`);
    if (ins.activeDays >= 20) msgs.push(`Stark månad, ${who} — ${ins.activeDays} av 30 måldagar klarade.`);
    if (ins.weekendScreenBias > 10) msgs.push(`Du tjänar mer skärmtid på helgerna (+${Math.round(ins.weekendScreenBias)}%).`);
    else if (ins.weekendScreenBias < -10) msgs.push(`Du tjänar mindre skärmtid på helgerna (${Math.round(ins.weekendScreenBias)}%).`);
  } else {
    if (ins.goalLeftToday > 0) {
      msgs.push(`${who}, you're ${ins.goalLeftToday.toLocaleString(locale)} steps from today's goal — about a ${walkMin}-minute walk to go.`);
    } else {
      msgs.push(`Today's goal is done, ${who} — nice work.`);
    }
    if (ins.goalStreak >= 3) msgs.push(`${ins.goalStreak} days in a row hitting your goal — keep the streak alive.`);
    if (ins.trend30 > 5) msgs.push(`You're trending up — +${Math.round(ins.trend30)}% over the last 30 days. Keep it rolling.`);
    else if (ins.trend30 < -5) msgs.push(`Activity is down ${Math.round(Math.abs(ins.trend30))}% this month — a short evening walk each day turns it around.`);
    msgs.push(`${best}s are your strongest days — plan your longer walks there.`);
    if (worst !== best) msgs.push(`${worst}s tend to be quiet for you — a short evening walk could change that.`);
    if (ins.personalBestSteps > 0) msgs.push(`Your best day this month: ${ins.personalBestSteps.toLocaleString(locale)} steps. Beat it this week.`);
    if (ins.activeDays >= 20) msgs.push(`Strong month, ${who} — ${ins.activeDays} of 30 goal days hit.`);
    if (ins.weekendScreenBias > 10) msgs.push(`You tend to earn more screen time on weekends (+${Math.round(ins.weekendScreenBias)}%).`);
    else if (ins.weekendScreenBias < -10) msgs.push(`You earn less screen time on weekends (${Math.round(ins.weekendScreenBias)}%).`);
  }
  return msgs.slice(0, 4);
}
