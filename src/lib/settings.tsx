import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "./auth";

export type Units = "metric" | "imperial";
export type Role = "individual" | "parent" | "child";

export type ChildProfile = {
  id: string;
  name: string;
  birthday: string;
  avatar: string;
  dailyGoal: number;
  code: string;
  stepsPer30: number;
  dailyCapHours: number;
};

export type StreakState = {
  count: number;
  lastGoalMetDate: string | null;
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
  dailyGoal: number;
  healthkitConnected: boolean;
  googlefitConnected: boolean;
  pushOn: boolean;
  anonymousLeaderboard: boolean;
  shareLocation: "off" | "while_using" | "always";
  units: Units;
  isPro: boolean;
  proSince: string | null;
  proPlan: SubPlan;
  proAutoRenew: boolean;
  proPaymentMethod: string;
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
  proPaymentMethod: "",
  themeColor: "sage",
  bonusMinFromYesterday: 0,
  role: "individual",
  displayName: "",
  username: "",
  email: "",
  password: "",
  avatar: null,
  children: [],
  streak: { count: 0, lastGoalMetDate: null, best: 0 },
};

type Ctx = {
  settings: SettingsState;
  update: <K extends keyof SettingsState>(key: K, value: SettingsState[K]) => Promise<void> | void;
  recordSteps: (steps: number, goal: number) => Promise<void> | void;
  refresh: () => Promise<void>;
};
const SettingsCtx = createContext<Ctx | null>(null);

function todayISO(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
function daysBetween(a: string, b: string): number {
  return Math.round((new Date(b + "T00:00:00").getTime() - new Date(a + "T00:00:00").getTime()) / 86400000);
}
export function currentStreak(s: StreakState): number {
  if (!s.lastGoalMetDate) return 0;
  const diff = daysBetween(s.lastGoalMetDate, todayISO());
  return diff <= 1 ? s.count : 0;
}

type ChildRow = {
  id: string;
  name: string;
  birthday: string | null;
  avatar: string | null;
  daily_goal: number;
  code: string;
  steps_per_30: number;
  daily_cap_hours: number;
};

function mapChild(c: ChildRow): ChildProfile {
  return {
    id: c.id,
    name: c.name,
    birthday: c.birthday ?? "",
    avatar: c.avatar ?? "🌱",
    dailyGoal: c.daily_goal,
    code: c.code,
    stepsPer30: c.steps_per_30,
    dailyCapHours: c.daily_cap_hours,
  };
}

export function SettingsProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const [settings, setSettings] = useState<SettingsState>(DEFAULTS);

  const load = useCallback(async () => {
    if (!user) {
      setSettings(DEFAULTS);
      return;
    }
    const [profileRes, settingsRes, streakRes, childrenRes] = await Promise.all([
      supabase.from("profiles").select("*").eq("id", user.id).maybeSingle(),
      supabase.from("user_settings").select("*").eq("user_id", user.id).maybeSingle(),
      supabase.from("streaks").select("*").eq("user_id", user.id).maybeSingle(),
      supabase.from("children").select("*").eq("parent_id", user.id),
    ]);
    const p = profileRes.data;
    const s = settingsRes.data;
    const st = streakRes.data;
    const kids = (childrenRes.data ?? []) as ChildRow[];

    setSettings({
      stepsPer30: s?.steps_per_30 ?? DEFAULTS.stepsPer30,
      dailyCapHours: s?.daily_cap_hours ?? DEFAULTS.dailyCapHours,
      healthkitConnected: s?.healthkit_connected ?? false,
      googlefitConnected: s?.googlefit_connected ?? false,
      pushOn: s?.push_on ?? true,
      anonymousLeaderboard: s?.anonymous_leaderboard ?? false,
      shareLocation: (s?.share_location ?? "while_using") as SettingsState["shareLocation"],
      units: (s?.units ?? "metric") as Units,
      isPro: s?.is_pro ?? false,
      proSince: s?.pro_since ?? null,
      proPlan: (s?.pro_plan ?? "monthly") as SubPlan,
      proAutoRenew: s?.pro_auto_renew ?? true,
      proPaymentMethod: s?.pro_payment_method ?? "",
      themeColor: (s?.theme_color ?? "sage") as ThemeColor,
      bonusMinFromYesterday: 0,
      role: (p?.role ?? "individual") as Role,
      displayName: p?.display_name ?? "",
      username: p?.username ?? "",
      email: p?.email ?? user.email ?? "",
      password: "",
      avatar: p?.avatar_url ?? null,
      children: kids.map(mapChild),
      streak: {
        count: st?.count ?? 0,
        best: st?.best ?? 0,
        lastGoalMetDate: st?.last_goal_met_date ?? null,
      },
    });
  }, [user]);

  useEffect(() => {
    load();
  }, [load]);

  // Apply theme
  useEffect(() => {
    if (typeof document === "undefined") return;
    const active = settings.isPro ? settings.themeColor : "sage";
    if (active === "sage") document.documentElement.removeAttribute("data-theme");
    else document.documentElement.setAttribute("data-theme", active);
  }, [settings.themeColor, settings.isPro]);

  const update = useCallback<Ctx["update"]>(
    async (key, value) => {
      setSettings((prev) => ({ ...prev, [key]: value }));
      if (!user) return;

      const profileKeys: Partial<Record<keyof SettingsState, string>> = {
        displayName: "display_name",
        username: "username",
        avatar: "avatar_url",
        role: "role",
        email: "email",
      };
      const settingsKeys: Partial<Record<keyof SettingsState, string>> = {
        stepsPer30: "steps_per_30",
        dailyCapHours: "daily_cap_hours",
        healthkitConnected: "healthkit_connected",
        googlefitConnected: "googlefit_connected",
        pushOn: "push_on",
        anonymousLeaderboard: "anonymous_leaderboard",
        shareLocation: "share_location",
        units: "units",
        isPro: "is_pro",
        proPlan: "pro_plan",
        proAutoRenew: "pro_auto_renew",
        proSince: "pro_since",
        proPaymentMethod: "pro_payment_method",
        themeColor: "theme_color",
      };

      if (key === "children") {
        // Full sync: replace children list (delete missing, upsert provided)
        const list = value as ChildProfile[];
        const { data: existing } = await supabase.from("children").select("id").eq("parent_id", user.id);
        const existingIds = new Set((existing ?? []).map((r) => r.id));
        const newIds = new Set(list.map((c) => c.id));
        const toDelete = [...existingIds].filter((id) => !newIds.has(id));
        if (toDelete.length) await supabase.from("children").delete().in("id", toDelete);
        if (list.length) {
          await supabase.from("children").upsert(
            list.map((c) => ({
              id: c.id,
              parent_id: user.id,
              name: c.name,
              birthday: c.birthday || null,
              avatar: c.avatar,
              daily_goal: c.dailyGoal,
              code: c.code,
              steps_per_30: c.stepsPer30,
              daily_cap_hours: c.dailyCapHours,
            })),
          );
        }
        return;
      }

      if (key === "streak") {
        const s = value as StreakState;
        await supabase.from("streaks").upsert({
          user_id: user.id,
          count: s.count,
          best: s.best,
          last_goal_met_date: s.lastGoalMetDate,
        });
        return;
      }

      if (profileKeys[key]) {
        await supabase
          .from("profiles")
          .update({ [profileKeys[key]!]: value } as never)
          .eq("id", user.id);
        return;
      }
      if (settingsKeys[key]) {
        await supabase
          .from("user_settings")
          .update({ [settingsKeys[key]!]: value } as never)
          .eq("user_id", user.id);
        return;
      }
    },
    [user],
  );

  const recordSteps = useCallback(
    async (steps: number, goal: number) => {
      if (!user) return;
      const today = todayISO();
      const { data: cur } = await supabase
        .from("streaks")
        .select("*")
        .eq("user_id", user.id)
        .maybeSingle();
      const s: StreakState = {
        count: cur?.count ?? 0,
        best: cur?.best ?? 0,
        lastGoalMetDate: cur?.last_goal_met_date ?? null,
      };
      let next = s;
      if (steps >= goal) {
        if (s.lastGoalMetDate === today) next = s;
        else if (s.lastGoalMetDate && daysBetween(s.lastGoalMetDate, today) === 1) {
          const count = s.count + 1;
          next = { count, lastGoalMetDate: today, best: Math.max(s.best, count) };
        } else next = { count: 1, lastGoalMetDate: today, best: Math.max(s.best, 1) };
      } else if (s.lastGoalMetDate && daysBetween(s.lastGoalMetDate, today) >= 2) {
        next = { ...s, count: 0 };
      }
      if (next !== s) {
        await supabase.from("streaks").upsert({
          user_id: user.id,
          count: next.count,
          best: next.best,
          last_goal_met_date: next.lastGoalMetDate,
        });
        setSettings((prev) => ({ ...prev, streak: next }));
      }
    },
    [user],
  );

  const value = useMemo<Ctx>(
    () => ({ settings, update, recordSteps, refresh: load }),
    [settings, update, recordSteps, load],
  );
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

export function earnedMinFromSteps(steps: number, stepsPer30: number, dailyCapHours: number): number {
  const cap = dailyCapHours * 60;
  const earned = Math.floor(steps / Math.max(1, stepsPer30)) * 30;
  return Math.min(cap, earned);
}

export function formatScreenMin(min: number): string {
  const h = Math.floor(min / 60);
  const m = min % 60;
  return h ? `${h}h ${m}m` : `${m}m`;
}
