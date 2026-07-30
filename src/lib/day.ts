import { useEffect, useState } from "react";

/** Local calendar day key (YYYY-MM-DD). All daily resets use the user's local midnight. */
export function localDayKey(d = new Date()) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function msUntilMidnight() {
  const now = new Date();
  const next = new Date(now);
  next.setHours(24, 0, 0, 0);
  return Math.max(1000, next.getTime() - now.getTime());
}

/**
 * Returns the current local day key and re-renders right after local midnight,
 * so every daily surface (leaderboards, streaks, gifted screen time) resets.
 */
export function useDayKey(): string {
  const [day, setDay] = useState(() => localDayKey());

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout>;
    const schedule = () => {
      timer = setTimeout(() => {
        setDay(localDayKey());
        schedule();
      }, msUntilMidnight());
    };
    schedule();
    const onFocus = () => setDay(localDayKey());
    window.addEventListener("focus", onFocus);
    document.addEventListener("visibilitychange", onFocus);
    return () => {
      clearTimeout(timer);
      window.removeEventListener("focus", onFocus);
      document.removeEventListener("visibilitychange", onFocus);
    };
  }, []);

  return day;
}
