import { earnedMinFromSteps } from "./settings";

export type ProST = {
  rollover: boolean;
  weekend2x: boolean;
  splitCaps: boolean;
  weekdayCap: number;
  weekendCap: number;
  catLimits: Record<string, number>;
};

export const PRO_ST_KEY = "sg.st.pro.v1";
export const DEFAULT_PRO_ST: ProST = {
  rollover: false,
  weekend2x: false,
  splitCaps: false,
  weekdayCap: 3,
  weekendCap: 5,
  catLimits: {},
};

export function loadProST(): ProST {
  if (typeof window === "undefined") return DEFAULT_PRO_ST;
  try {
    const raw = window.localStorage.getItem(PRO_ST_KEY);
    if (!raw) return DEFAULT_PRO_ST;
    return { ...DEFAULT_PRO_ST, ...JSON.parse(raw) };
  } catch {
    return DEFAULT_PRO_ST;
  }
}

export function saveProST(next: ProST) {
  try {
    window.localStorage.setItem(PRO_ST_KEY, JSON.stringify(next));
  } catch {}
}

/** Local-weekend check (Sat/Sun), matching the iOS `Calendar.current` rule. */
export function isWeekendDay(date: Date = new Date()): boolean {
  const day = date.getDay();
  return day === 0 || day === 6;
}

/**
 * The cap that actually applies on `date`. When split caps are on they
 * override the standard daily cap entirely; otherwise the standard cap rules.
 */
export function effectiveCapHours(
  dailyCapHours: number,
  pro: ProST,
  isPro: boolean,
  date: Date = new Date(),
): number {
  if (isPro && pro.splitCaps) {
    return isWeekendDay(date) ? pro.weekendCap : pro.weekdayCap;
  }
  return dailyCapHours;
}

/**
 * Steps needed per 30 earned minutes on `date`. The PRO weekend 2x
 * multiplier halves the steps required on Saturdays and Sundays.
 */
export function effectiveStepsPer30(
  stepsPer30: number,
  pro: ProST,
  isPro: boolean,
  date: Date = new Date(),
): number {
  if (isPro && pro.weekend2x && isWeekendDay(date)) {
    return Math.max(1, Math.round(stepsPer30 / 2));
  }
  return stepsPer30;
}

/** Earned minutes for a day, honoring the PRO weekend multiplier and split caps. */
export function earnedMinForDay(
  steps: number,
  stepsPer30: number,
  dailyCapHours: number,
  pro: ProST,
  isPro: boolean,
  date: Date = new Date(),
): number {
  return earnedMinFromSteps(
    steps,
    effectiveStepsPer30(stepsPer30, pro, isPro, date),
    effectiveCapHours(dailyCapHours, pro, isPro, date),
  );
}

/**
 * Rollover minutes from yesterday's unused earned screen time.
 * Since actual screen-time consumption isn't tracked, we treat
 * yesterday's *earned* minutes as the pool that can carry over,
 * capped by today's daily cap.
 */
export function computeRolloverMin(
  yesterdaySteps: number,
  stepsPer30: number,
  dailyCapHours: number,
  pro: ProST,
  isPro: boolean,
): number {
  if (!isPro || !pro.rollover) return 0;
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  const earnedYesterday = earnedMinForDay(yesterdaySteps, stepsPer30, dailyCapHours, pro, isPro, yesterday);
  return Math.min(earnedYesterday, effectiveCapHours(dailyCapHours, pro, isPro) * 60);
}
