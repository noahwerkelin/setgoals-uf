// Challenge catalog — trackable, deterministic daily/weekly selection.
import { earnedMinFromSteps, type SettingsState } from "./settings";
import type { DayTotals } from "./steps";

export type Metric = "steps" | "distance" | "exercise" | "calories" | "earned" | "streak" | "goal";

export type Challenge = {
  id: string;
  metric: Metric;
  target: number; // target value in metric units (steps, km, minutes, calories, days)
  scope: "daily" | "weekly";
  title: { en: string; sv: string };
  desc: { en: string; sv: string };
  rewardMin: number; // bonus screen-time minutes on completion (informational)
};

// -------- Daily pool (trackable metrics only) --------
export const DAILY_POOL: Challenge[] = [
  {
    id: "d_steps_5k", metric: "steps", target: 5000, scope: "daily", rewardMin: 15,
    title: { en: "Walk 5,000 steps", sv: "Gå 5 000 steg" },
    desc: {
      en: "Log at least 5,000 steps today. Progress updates automatically from your activity data.",
      sv: "Logga minst 5 000 steg idag. Framstegen uppdateras automatiskt från din aktivitet.",
    },
  },
  {
    id: "d_steps_8k", metric: "steps", target: 8000, scope: "daily", rewardMin: 30,
    title: { en: "Walk 8,000 steps", sv: "Gå 8 000 steg" },
    desc: {
      en: "Hit 8,000 steps by end of day. Every step counts — automatically tracked.",
      sv: "Nå 8 000 steg innan dagen är slut. Varje steg räknas — spåras automatiskt.",
    },
  },
  {
    id: "d_steps_goal", metric: "goal", target: 1, scope: "daily", rewardMin: 20,
    title: { en: "Reach your daily step goal", sv: "Nå ditt dagliga stegmål" },
    desc: {
      en: "Complete your personal daily step goal set in Settings.",
      sv: "Nå ditt personliga dagliga stegmål som du satt i Inställningar.",
    },
  },
  {
    id: "d_dist_3k", metric: "distance", target: 3, scope: "daily", rewardMin: 15,
    title: { en: "Cover 3 km today", sv: "Tillryggalägg 3 km idag" },
    desc: {
      en: "Cover 3 kilometers on foot. Distance is measured from your logged activity.",
      sv: "Tillryggalägg 3 kilometer till fots. Sträckan mäts från din loggade aktivitet.",
    },
  },
  {
    id: "d_dist_5k", metric: "distance", target: 5, scope: "daily", rewardMin: 25,
    title: { en: "Cover 5 km today", sv: "Tillryggalägg 5 km idag" },
    desc: {
      en: "Cover 5 kilometers today. A great mid-length walk or run.",
      sv: "Tillryggalägg 5 kilometer idag. En bra medellång promenad eller löprunda.",
    },
  },
  {
    id: "d_exercise_30", metric: "exercise", target: 30, scope: "daily", rewardMin: 20,
    title: { en: "30 active minutes", sv: "30 aktiva minuter" },
    desc: {
      en: "Log 30 minutes of activity today.",
      sv: "Logga 30 minuters aktivitet idag.",
    },
  },
  {
    id: "d_exercise_60", metric: "exercise", target: 60, scope: "daily", rewardMin: 35,
    title: { en: "60 active minutes", sv: "60 aktiva minuter" },
    desc: {
      en: "Reach a full hour of activity today.",
      sv: "Nå en hel timmes aktivitet idag.",
    },
  },
  {
    id: "d_earn_60", metric: "earned", target: 60, scope: "daily", rewardMin: 10,
    title: { en: "Earn 1 hour of screen time", sv: "Tjäna 1 timmes skärmtid" },
    desc: {
      en: "Earn 60 minutes of screen time by walking, using your current earning rules.",
      sv: "Tjäna 60 minuters skärmtid genom att gå, enligt dina intjäningsregler.",
    },
  },
  {
    id: "d_earn_90", metric: "earned", target: 90, scope: "daily", rewardMin: 15,
    title: { en: "Earn 90 minutes of screen time", sv: "Tjäna 90 minuters skärmtid" },
    desc: {
      en: "Earn 90 minutes of screen time today.",
      sv: "Tjäna 90 minuters skärmtid idag.",
    },
  },
  {
    id: "d_calories_300", metric: "calories", target: 300, scope: "daily", rewardMin: 15,
    title: { en: "Burn 300 calories", sv: "Bränn 300 kalorier" },
    desc: {
      en: "Burn 300 active calories today.",
      sv: "Bränn 300 aktiva kalorier idag.",
    },
  },
];

// -------- Weekly pool --------
export const WEEKLY_POOL: Challenge[] = [
  {
    id: "w_steps_40k", metric: "steps", target: 40000, scope: "weekly", rewardMin: 60,
    title: { en: "40,000 steps this week", sv: "40 000 steg denna vecka" },
    desc: {
      en: "Accumulate 40,000 steps across the week. Averages about 5,700 steps a day.",
      sv: "Samla 40 000 steg under veckan. Motsvarar cirka 5 700 steg per dag.",
    },
  },
  {
    id: "w_steps_60k", metric: "steps", target: 60000, scope: "weekly", rewardMin: 90,
    title: { en: "60,000 steps this week", sv: "60 000 steg denna vecka" },
    desc: {
      en: "Reach 60,000 steps this week — around 8,600 a day.",
      sv: "Nå 60 000 steg denna vecka — cirka 8 600 per dag.",
    },
  },
  {
    id: "w_dist_25", metric: "distance", target: 25, scope: "weekly", rewardMin: 60,
    title: { en: "25 km this week", sv: "25 km denna vecka" },
    desc: {
      en: "Cover 25 kilometers across the week.",
      sv: "Tillryggalägg 25 kilometer under veckan.",
    },
  },
  {
    id: "w_dist_40", metric: "distance", target: 40, scope: "weekly", rewardMin: 90,
    title: { en: "40 km this week", sv: "40 km denna vecka" },
    desc: {
      en: "Cover 40 kilometers across the week.",
      sv: "Tillryggalägg 40 kilometer under veckan.",
    },
  },
  {
    id: "w_exercise_150", metric: "exercise", target: 150, scope: "weekly", rewardMin: 75,
    title: { en: "150 active minutes", sv: "150 aktiva minuter" },
    desc: {
      en: "Log 150 minutes of activity this week — the WHO baseline.",
      sv: "Logga 150 aktiva minuter i veckan — WHO:s rekommendation.",
    },
  },
  {
    id: "w_streak_5", metric: "streak", target: 5, scope: "weekly", rewardMin: 60,
    title: { en: "Keep a 5-day streak", sv: "Håll en 5-dagars svit" },
    desc: {
      en: "Reach your daily goal on 5 different days to keep a streak of 5.",
      sv: "Nå ditt dagsmål 5 olika dagar för att hålla en 5-dagars svit.",
    },
  },
  {
    id: "w_earn_10h", metric: "earned", target: 600, scope: "weekly", rewardMin: 60,
    title: { en: "Earn 10h screen time", sv: "Tjäna 10h skärmtid" },
    desc: {
      en: "Earn 10 hours of screen time across the week from your activity.",
      sv: "Tjäna 10 timmars skärmtid under veckan från din aktivitet.",
    },
  },
];

// -------- Deterministic selection by date --------
function hash(str: string): number {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function dayKey(d: Date): string {
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
}

function isoWeekKey(d: Date): string {
  const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  const day = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((+t - +yearStart) / 86400000 + 1) / 7);
  return `${t.getUTCFullYear()}-W${week}`;
}

function pickN<T extends { id: string }>(pool: T[], seed: string, n: number): T[] {
  const scored = pool.map((c) => ({ c, s: hash(seed + ":" + c.id) }));
  scored.sort((a, b) => a.s - b.s);
  return scored.slice(0, n).map((x) => x.c);
}

export function todaysDailyChallenges(now = new Date()): Challenge[] {
  return pickN(DAILY_POOL, "daily:" + dayKey(now), 3);
}

export function thisWeeksWeeklyChallenges(now = new Date()): Challenge[] {
  return pickN(WEEKLY_POOL, "weekly:" + isoWeekKey(now), 2);
}

// -------- Progress calculation --------
export type ProgressCtx = {
  today: DayTotals | null;
  week: DayTotals[]; // last 7 days
  settings: SettingsState;
};

export function challengeProgress(c: Challenge, ctx: ProgressCtx): { current: number; target: number; done: boolean } {
  const { today, week, settings } = ctx;
  let current = 0;
  const target = c.target;
  if (c.scope === "daily") {
    const t = today ?? { steps: 0, distance_km: 0, calories: 0, exercise_minutes: 0 };
    switch (c.metric) {
      case "steps": current = t.steps; break;
      case "distance": current = t.distance_km; break;
      case "exercise": current = t.exercise_minutes; break;
      case "calories": current = t.calories; break;
      case "earned":
        current = earnedMinFromSteps(t.steps, settings.stepsPer30, settings.dailyCapHours);
        break;
      case "goal":
        current = t.steps >= settings.dailyGoal ? 1 : t.steps / Math.max(1, settings.dailyGoal);
        break;
      case "streak": current = settings.streak.count; break;
    }
  } else {
    const sum = week.reduce(
      (a, d) => ({
        steps: a.steps + d.steps,
        distance_km: a.distance_km + d.distance_km,
        exercise_minutes: a.exercise_minutes + d.exercise_minutes,
        calories: a.calories + d.calories,
        earned: a.earned + earnedMinFromSteps(d.steps, settings.stepsPer30, settings.dailyCapHours),
      }),
      { steps: 0, distance_km: 0, exercise_minutes: 0, calories: 0, earned: 0 },
    );
    switch (c.metric) {
      case "steps": current = sum.steps; break;
      case "distance": current = sum.distance_km; break;
      case "exercise": current = sum.exercise_minutes; break;
      case "calories": current = sum.calories; break;
      case "earned": current = sum.earned; break;
      case "streak": current = settings.streak.count; break;
      case "goal": current = 0; break;
    }
  }
  const done = current >= target;
  return { current, target, done };
}

export function formatMetric(metric: Metric, value: number): string {
  switch (metric) {
    case "steps": return `${Math.floor(value).toLocaleString()} steps`;
    case "distance": return `${value.toFixed(1)} km`;
    case "exercise": return `${Math.floor(value)} min`;
    case "calories": return `${Math.floor(value)} kcal`;
    case "earned": {
      const m = Math.floor(value);
      const h = Math.floor(m / 60);
      const r = m % 60;
      return h ? `${h}h ${r}m` : `${r}m`;
    }
    case "streak": return `${Math.floor(value)} days`;
    case "goal": return value >= 1 ? "Complete" : `${Math.round(value * 100)}%`;
  }
}
