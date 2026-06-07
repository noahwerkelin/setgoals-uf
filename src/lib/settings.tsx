import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

export type Units = "metric" | "imperial";
export type Role = "individual" | "parent" | "child";

export type ChildProfile = {
  id: string;
  name: string;
  birthday: string; // YYYY-MM-DD
  avatar: string; // emoji or initials
  dailyGoal: number; // steps
  code: string; // 6-char login code
  stepsPer30: number; // earning ratio
  dailyCapHours: number; // screen-time cap
};

export type StreakState = {
  count: number;
  lastGoalMetDate: string | null; // YYYY-MM-DD in local tz
  best: number;
};

export type SubPlan = "monthly" | "yearly";
export type ThemeColor = "sage" | "rose" | "blue" | "pink" | "lavender" | "amber" | "slate";
export const THEME_COLORS: { id: ThemeColor; swatch: string }[] = [
  { id: "sage", swatch: "oklch(0.58 0.038 142)" },
  { id: "rose", swatch: "oklch(0.58 0.07 24)" },
  { id: "blue", swatch: "oklch(0.58 0.07 248)" },
  { id: "pink", swatch: "oklch(0.58 0.07 350)" },
  { id: "lavender", swatch: "oklch(0.58 0.068 295)" },
  { id: "amber", swatch: "oklch(0.58 0.078 72)" },
  { id: "slate", swatch: "oklch(0.58 0.025 250)" },
];

export type SettingsState = {
  stepsPer30: number;
  dailyCapHours: number;
  healthkitConnected: boolean;
  googlefitConnected: boolean;
  pushOn: boolean;
  anonymousLeaderboard: boolean;
  shareLocation: "off" | "while_using" | "always";
  units: Units;
  isPro: boolean;
  proSince: string | null; // ISO date subscription started / last renewed
  proPlan: SubPlan;
  proAutoRenew: boolean;
  proPaymentMethod: string; // e.g. "Visa •• 4242"
  themeColor: ThemeColor;
  bonusMinFromYesterday: number;
  role: Role;
  displayName: string;
  username: string;
  email: string;
  password: string;
  avatar: string | null;
  children: ChildProfile[];
  streak: StreakState;
};

const DEFAULTS: SettingsState = {
  stepsPer30: 1000,
  dailyCapHours: 3,
  healthkitConnected: false,
  googlefitConnected: false,
  pushOn: true,
  anonymousLeaderboard: false,
  shareLocation: "while_using",
  units: "metric",
  isPro: false,
  proSince: null,
  proPlan: "monthly",
  proAutoRenew: true,
  proPaymentMethod: "Visa •• 4242",
  themeColor: "sage",
  bonusMinFromYesterday: 45,
  role: "individual",
  displayName: "Lukas",
  username: "lukas",
  email: "lukas@example.com",
  password: "password123",
  avatar: null,
  children: [],
  streak: { count: 0, lastGoalMetDate: null, best: 0 },
};

type Ctx = {
  settings: SettingsState;
  update: <K extends keyof SettingsState>(key: K, value: SettingsState[K]) => void;
  recordSteps: (steps: number, goal: number) => void;
};
const SettingsCtx = createContext<Ctx | null>(null);

const KEY = "sg.settings";

function todayISO(): string {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

function daysBetween(a: string, b: string): number {
  const da = new Date(a + "T00:00:00");
  const db = new Date(b + "T00:00:00");
  return Math.round((db.getTime() - da.getTime()) / 86400000);
}

export function currentStreak(s: StreakState): number {
  if (!s.lastGoalMetDate) return 0;
  const diff = daysBetween(s.lastGoalMetDate, todayISO());
  if (diff <= 1) return s.count; // today or yesterday — still alive
  return 0; // missed a day — reset
}

export function SettingsProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState<SettingsState>(DEFAULTS);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        setSettings({
          ...DEFAULTS,
          ...parsed,
          streak: { ...DEFAULTS.streak, ...(parsed.streak ?? {}) },
        });
      }
    } catch {}
  }, []);

  // Apply PRO color theme to <html data-theme="…"> — non-PRO always uses sage.
  useEffect(() => {
    if (typeof document === "undefined") return;
    const active = settings.isPro ? settings.themeColor : "sage";
    if (active === "sage") document.documentElement.removeAttribute("data-theme");
    else document.documentElement.setAttribute("data-theme", active);
  }, [settings.themeColor, settings.isPro]);

  const update = useCallback<Ctx["update"]>((key, value) => {
    setSettings((prev) => {
      const next = { ...prev, [key]: value };
      try { localStorage.setItem(KEY, JSON.stringify(next)); } catch {}
      return next;
    });
  }, []);

  const recordSteps = useCallback((steps: number, goal: number) => {
    setSettings((prev) => {
      const today = todayISO();
      const s = prev.streak;
      let next = s;
      if (steps >= goal) {
        if (s.lastGoalMetDate === today) {
          next = s; // already counted today
        } else if (s.lastGoalMetDate && daysBetween(s.lastGoalMetDate, today) === 1) {
          const count = s.count + 1;
          next = { count, lastGoalMetDate: today, best: Math.max(s.best, count) };
        } else {
          next = { count: 1, lastGoalMetDate: today, best: Math.max(s.best, 1) };
        }
      } else if (s.lastGoalMetDate && daysBetween(s.lastGoalMetDate, today) >= 2) {
        // missed at least a full day -> reset count
        next = { ...s, count: 0 };
      }
      if (next === s) return prev;
      const out = { ...prev, streak: next };
      try { localStorage.setItem(KEY, JSON.stringify(out)); } catch {}
      return out;
    });
  }, []);

  const value = useMemo(() => ({ settings, update, recordSteps }), [settings, update, recordSteps]);
  return <SettingsCtx.Provider value={value}>{children}</SettingsCtx.Provider>;
}

export function useSettings() {
  const ctx = useContext(SettingsCtx);
  if (!ctx) throw new Error("useSettings must be used inside SettingsProvider");
  return ctx;
}

export function useIsChild() {
  return useSettings().settings.role === "child";
}

// Unit helpers
export function kmToDisplay(km: number, units: Units): { value: number; unit: "km" | "mi" } {
  if (units === "imperial") return { value: km * 0.621371, unit: "mi" };
  return { value: km, unit: "km" };
}

export function formatDistance(km: number, units: Units, digits = 1): string {
  const { value, unit } = kmToDisplay(km, units);
  return `${value.toFixed(digits)} ${unit}`;
}

export function genChildCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = "";
  for (let i = 0; i < 6; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}
