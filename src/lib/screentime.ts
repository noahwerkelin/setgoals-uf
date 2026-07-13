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
  const earnedYesterday = earnedMinFromSteps(yesterdaySteps, stepsPer30, dailyCapHours);
  return Math.min(earnedYesterday, dailyCapHours * 60);
}
