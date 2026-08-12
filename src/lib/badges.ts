import { useCallback, useEffect, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { getUserBadges, awardBadge as awardBadgeFn } from "@/lib/badges.functions";
import { useSettings, currentStreak } from "@/lib/settings";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/auth";
import { useTodaySteps } from "@/lib/steps";


export type EarnedMap = Record<string, string>;

const BADGE_QUERY_KEY = ["user-badges"];
const TOTALS_KEY = "sg.totals";
const HOURLY_KEY = "sg.hourly";

export const EARLY_BIRD_THRESHOLD = 2000;
export const NIGHT_OWL_THRESHOLD = 2000;

type Totals = { lastDate: string | null; totalSteps: number; totalKm: number };
type HourlyState = {
  date: string | null;
  lastSteps: number;
  earlyBirdSteps: number;
  nightOwlSteps: number;
};

function loadTotals(): Totals {
  try {
    const raw = localStorage.getItem(TOTALS_KEY);
    return raw ? JSON.parse(raw) : { lastDate: null, totalSteps: 0, totalKm: 0 };
  } catch {
    return { lastDate: null, totalSteps: 0, totalKm: 0 };
  }
}
function saveTotals(t: Totals) {
  try {
    localStorage.setItem(TOTALS_KEY, JSON.stringify(t));
  } catch {}
}

function loadHourly(): HourlyState {
  try {
    const raw = localStorage.getItem(HOURLY_KEY);
    if (raw) return JSON.parse(raw);
  } catch {}
  return { date: null, lastSteps: 0, earlyBirdSteps: 0, nightOwlSteps: 0 };
}
function saveHourly(h: HourlyState) {
  try {
    localStorage.setItem(HOURLY_KEY, JSON.stringify(h));
  } catch {}
}

function updateHourlyBuckets(steps: number, hour: number): HourlyState {
  const today = new Date();
  const iso = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;
  let h = loadHourly();
  if (h.date !== iso) {
    h = { date: iso, lastSteps: 0, earlyBirdSteps: 0, nightOwlSteps: 0 };
  }
  if (steps < h.lastSteps) {
    h.lastSteps = steps;
    saveHourly(h);
    return h;
  }
  const delta = steps - h.lastSteps;
  if (delta > 0) {
    if (hour >= 0 && hour < 8) h.earlyBirdSteps += delta;
    else if (hour >= 21 && hour <= 23) h.nightOwlSteps += delta;
    h.lastSteps = steps;
    saveHourly(h);
  }
  return h;
}

export function useEarnedBadges() {
  const getBadges = useServerFn(getUserBadges);
  return useQuery({
    queryKey: BADGE_QUERY_KEY,
    queryFn: () => getBadges({ data: undefined }),
  });
}

export function useAwardBadge() {
  const award = useServerFn(awardBadgeFn);
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => award({ data: id }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: BADGE_QUERY_KEY });
    },
  });
}

export function useAwardBadges() {
  const award = useAwardBadge();
  return useCallback(
    async (ids: string[]) => {
      const newly: string[] = [];
      for (const id of ids) {
        const res = await award.mutateAsync(id);
        if (res.newlyAwarded) newly.push(id);
      }
      return newly;
    },
    [award],
  );
}

/**
 * Every day of logged activity the account has, summed. This is the real
 * movement data behind the distance badges — no local guesses.
 */
export function useLifetimeTotals() {
  const { user } = useAuth();
  return useQuery({
    queryKey: ["lifetime-totals", user?.id],
    enabled: !!user,
    staleTime: 60_000,
    queryFn: async (): Promise<{ steps: number; km: number }> => {
      const { data } = await supabase
        .from("activity_steps")
        .select("steps, distance_km")
        .eq("user_id", user!.id);
      return (data ?? []).reduce(
        (acc, r) => ({ steps: acc.steps + (r.steps ?? 0), km: acc.km + Number(r.distance_km ?? 0) }),
        { steps: 0, km: 0 },
      );
    },
  });
}

/**
 * Awards the activity badges from the user's real recorded movement:
 * today's totals from `activity_steps` and the all-time distance sum.
 * Early Bird / Night Owl still come from the device's hourly buckets,
 * which is the only place the time-of-day split is known.
 */
export function useActivityBadgeSync() {
  const { data: today } = useTodaySteps();
  const { data: totals } = useLifetimeTotals();
  const { awardIds } = useAutoBadgeAwards();

  const steps = today?.steps ?? 0;
  const km = Number(today?.distance_km ?? 0);
  const totalKm = totals?.km ?? 0;

  useEffect(() => {
    const ids: string[] = [];
    if (steps > 0) {
      const h = updateHourlyBuckets(steps, new Date().getHours());
      if (steps >= 1000) ids.push("first_steps");
      if (steps >= 5000) ids.push("daily_walker");
      if (km >= 10) ids.push("ten_k_club");
      if (h.earlyBirdSteps >= EARLY_BIRD_THRESHOLD) ids.push("early_bird");
      if (h.nightOwlSteps >= NIGHT_OWL_THRESHOLD) ids.push("night_owl");
    }
    if (totalKm >= 10) ids.push("explorer");
    if (totalKm >= 100) ids.push("adventurer");
    if (totalKm >= 500) ids.push("pathfinder");
    if (ids.length) awardIds(ids);
  }, [steps, km, totalKm, awardIds]);
}


export function recordLeaderboardBadges(
  scope: "local" | "national",
  rank: number,
  opts: { steps: number; participants: number },
): string[] {
  const { steps, participants } = opts;
  if (!Number.isFinite(rank) || rank < 1) return [];
  if (steps <= 0) return [];
  const ids: string[] = [];
  if (scope === "local") {
    if (rank <= 10 && participants >= 10) ids.push("local_elite");
    if (rank === 1 && participants >= 10) ids.push("local_legend");
  } else {
    if (rank <= 100 && participants >= 100) ids.push("national_contender");
    if (rank <= 10 && participants >= 100) ids.push("national_elite");
    if (rank === 1 && participants >= 100) ids.push("national_champion");
  }
  return ids;
}

/**
 * Hook that auto-awards daily, streak, pro, and unlocker badges by combining
 * local state with the server-side badge store.
 */
export function useAutoBadgeAwards() {
  const { settings } = useSettings();
  const { data: earned } = useEarnedBadges();
  const award = useAwardBadge();

  const earnedSet = useMemo(() => {
    const s = new Set<string>();
    if (earned) {
      for (const b of earned) s.add(b.badge_id);
    }
    return s;
  }, [earned]);

  const awardIds = useCallback(
    async (ids: string[]) => {
      for (const id of ids) {
        if (!earnedSet.has(id)) await award.mutateAsync(id);
      }
    },
    [earnedSet, award],
  );

  return { earnedSet, awardIds };
}

export function useStreakBadges() {
  const { settings } = useSettings();
  const { awardIds } = useAutoBadgeAwards();
  useEffect(() => {
    const best = Math.max(settings.streak.best, currentStreak(settings.streak));
    const ids: string[] = [];
    if (best >= 7) ids.push("consistency_king");
    if (best >= 30) ids.push("impressive");
    if (best >= 100) ids.push("unstoppable");
    if (ids.length) awardIds(ids);
  }, [settings.streak, awardIds]);
}

export function useProBadge() {
  const { settings } = useSettings();
  const { awardIds } = useAutoBadgeAwards();
  useEffect(() => {
    if (settings.isPro) awardIds(["earned_elite"]);
  }, [settings.isPro, awardIds]);
}

export function useUnlockerBadge() {
  const { data: earned } = useEarnedBadges();
  const { awardIds } = useAutoBadgeAwards();
  useEffect(() => {
    if (!earned) return;
    const allOthers = [
      "first_steps", "daily_walker", "early_bird", "night_owl",
      "ten_k_club", "explorer", "adventurer", "pathfinder",
      "consistency_king", "impressive", "unstoppable",
      "first_adventure", "first_friend", "challenge_accepted",
      "local_elite", "local_legend", "national_contender", "national_elite", "national_champion",
      "problem_solver", "earned_elite",
    ];
    const allEarned = allOthers.every((id) => earned.some((b) => b.badge_id === id));
    if (allEarned && !earned.some((b) => b.badge_id === "unlocker")) awardIds(["unlocker"]);
  }, [earned, awardIds]);
}

export function useLeaderboardBadgeCheck(
  scope: "local" | "national",
  rank: number,
  opts: { steps: number; participants: number },
) {
  const { awardIds } = useAutoBadgeAwards();
  useEffect(() => {
    const ids = recordLeaderboardBadges(scope, rank, opts);
    if (ids.length) awardIds(ids);
  }, [scope, rank, opts.steps, opts.participants, awardIds]);
}

/** Kept for callers that pass today's numbers — the sync hook owns the rules. */
export function useDailyBadgeCheck() {
  useActivityBadgeSync();
}


