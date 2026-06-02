import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

export type Units = "metric" | "imperial";

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
  // Pro: minutes saved from yesterday usable today (cap at 60)
  bonusMinFromYesterday: number;
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
  bonusMinFromYesterday: 45,
};

type Ctx = {
  settings: SettingsState;
  update: <K extends keyof SettingsState>(key: K, value: SettingsState[K]) => void;
};
const SettingsCtx = createContext<Ctx | null>(null);

const KEY = "sg.settings";

export function SettingsProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState<SettingsState>(DEFAULTS);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(KEY);
      if (raw) setSettings({ ...DEFAULTS, ...JSON.parse(raw) });
    } catch {}
  }, []);

  const update = useCallback<Ctx["update"]>((key, value) => {
    setSettings((prev) => {
      const next = { ...prev, [key]: value };
      try { localStorage.setItem(KEY, JSON.stringify(next)); } catch {}
      return next;
    });
  }, []);

  const value = useMemo(() => ({ settings, update }), [settings, update]);
  return <SettingsCtx.Provider value={value}>{children}</SettingsCtx.Provider>;
}

export function useSettings() {
  const ctx = useContext(SettingsCtx);
  if (!ctx) throw new Error("useSettings must be used inside SettingsProvider");
  return ctx;
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
