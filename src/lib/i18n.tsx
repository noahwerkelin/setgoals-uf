import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

export type Lang = "en" | "sv";

type Dict = Record<string, string>;

const DICTS: Record<Lang, Dict> = {
  en: {
    "nav.home": "Home",
    "nav.map": "Map",
    "nav.goals": "Goals",
    "nav.coach": "Coach",
    "nav.profile": "Profile",

    "home.morning": "Morning",
    "home.steps_of": "of {goal} steps",
    "home.earned": "Earned",
    "home.remaining": "Remaining",
    "home.energy": "Energy",
    "home.distance": "Distance",
    "home.quote_eyebrow": "Quote of the day",
    "home.achievements": "Recent achievements",
    "home.family": "Family",
    "home.this_week": "This week",
    "home.leaderboards": "Leaderboards",
    "home.lb_sub": "You're #4 with friends today",

    "map.eyebrow": "Discover",
    "map.title": "Nearby activities",
    "map.start": "Start",
    "map.locating": "Locating you…",
    "map.use_location": "Use my location",
    "map.location_denied": "Location unavailable — showing Gothenburg",

    "settings.title": "Settings",
    "settings.earning": "Earning rules",
    "settings.steps_per_30": "Steps per 30 min",
    "settings.daily_cap": "Daily screen-time cap",
    "settings.integrations": "Integrations",
    "settings.healthkit": "Apple HealthKit",
    "settings.googlefit": "Google Fit / Health Connect",
    "settings.push": "Push notifications",
    "settings.privacy": "Privacy",
    "settings.anon_lb": "Anonymous on leaderboards",
    "settings.share_loc": "Share location for routes",
    "settings.account": "Account",
    "settings.language": "Language",
    "settings.email": "Email",
    "settings.signout": "Sign out",
    "settings.connected": "Connected",
    "settings.connect": "Connect",
    "settings.disconnect": "Disconnect",
    "settings.on": "On",
    "settings.off": "Off",
    "settings.while_using": "While using",
    "settings.save": "Save",
    "settings.cancel": "Cancel",
    "settings.hours": "h",
    "settings.minutes": "min",

    "hk.title": "Connect Apple HealthKit",
    "hk.desc": "We'll read your daily step count from HealthKit to credit screen time. You can disconnect any time.",
    "gf.title": "Connect Google Fit",
    "gf.desc": "We'll read your daily step count from Google Fit / Health Connect to credit screen time.",
    "hk.allow": "Allow access",

    "common.back": "Back",
  },
  sv: {
    "nav.home": "Hem",
    "nav.map": "Karta",
    "nav.goals": "Mål",
    "nav.coach": "Coach",
    "nav.profile": "Profil",

    "home.morning": "God morgon",
    "home.steps_of": "av {goal} steg",
    "home.earned": "Intjänat",
    "home.remaining": "Kvar",
    "home.energy": "Energi",
    "home.distance": "Distans",
    "home.quote_eyebrow": "Dagens citat",
    "home.achievements": "Senaste utmärkelser",
    "home.family": "Familj",
    "home.this_week": "Denna vecka",
    "home.leaderboards": "Topplistor",
    "home.lb_sub": "Du är #4 bland vänner idag",

    "map.eyebrow": "Upptäck",
    "map.title": "Aktiviteter nära dig",
    "map.start": "Starta",
    "map.locating": "Hittar din plats…",
    "map.use_location": "Använd min plats",
    "map.location_denied": "Plats ej tillgänglig — visar Göteborg",

    "settings.title": "Inställningar",
    "settings.earning": "Intjäningsregler",
    "settings.steps_per_30": "Steg per 30 min",
    "settings.daily_cap": "Daglig skärmtidsgräns",
    "settings.integrations": "Integrationer",
    "settings.healthkit": "Apple HealthKit",
    "settings.googlefit": "Google Fit / Health Connect",
    "settings.push": "Notiser",
    "settings.privacy": "Integritet",
    "settings.anon_lb": "Anonym på topplistor",
    "settings.share_loc": "Dela plats för rutter",
    "settings.account": "Konto",
    "settings.language": "Språk",
    "settings.email": "E-post",
    "settings.signout": "Logga ut",
    "settings.connected": "Ansluten",
    "settings.connect": "Anslut",
    "settings.disconnect": "Koppla från",
    "settings.on": "På",
    "settings.off": "Av",
    "settings.while_using": "När appen används",
    "settings.save": "Spara",
    "settings.cancel": "Avbryt",
    "settings.hours": "h",
    "settings.minutes": "min",

    "hk.title": "Anslut Apple HealthKit",
    "hk.desc": "Vi läser ditt dagliga stegantal från HealthKit för att tilldela skärmtid. Du kan koppla från när som helst.",
    "gf.title": "Anslut Google Fit",
    "gf.desc": "Vi läser ditt dagliga stegantal från Google Fit / Health Connect för att tilldela skärmtid.",
    "hk.allow": "Tillåt åtkomst",

    "common.back": "Tillbaka",
  },
};

type Ctx = { lang: Lang; setLang: (l: Lang) => void; t: (key: string, vars?: Record<string, string | number>) => string };
const I18nCtx = createContext<Ctx | null>(null);

export function I18nProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>("en");

  useEffect(() => {
    const stored = (typeof window !== "undefined" && (localStorage.getItem("sg.lang") as Lang)) || null;
    if (stored === "en" || stored === "sv") setLangState(stored);
  }, []);

  const setLang = useCallback((l: Lang) => {
    setLangState(l);
    try { localStorage.setItem("sg.lang", l); } catch {}
  }, []);

  const t = useCallback(
    (key: string, vars?: Record<string, string | number>) => {
      let s = DICTS[lang][key] ?? DICTS.en[key] ?? key;
      if (vars) for (const k in vars) s = s.replace(`{${k}}`, String(vars[k]));
      return s;
    },
    [lang],
  );

  const value = useMemo(() => ({ lang, setLang, t }), [lang, setLang, t]);
  return <I18nCtx.Provider value={value}>{children}</I18nCtx.Provider>;
}

export function useT() {
  const ctx = useContext(I18nCtx);
  if (!ctx) throw new Error("useT must be used inside I18nProvider");
  return ctx;
}
