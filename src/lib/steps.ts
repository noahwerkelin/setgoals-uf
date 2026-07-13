import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "./auth";

function todayISO() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function daysAgoISO(n: number) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export type DayTotals = {
  day: string;
  steps: number;
  distance_km: number;
  calories: number;
  exercise_minutes: number;
};

export function useTodaySteps() {
  const { user } = useAuth();
  const qc = useQueryClient();

  // realtime subscribe
  useEffect(() => {
    if (!user) return;
    const ch = supabase
      .channel("activity-today-" + user.id)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "activity_steps", filter: `user_id=eq.${user.id}` },
        () => {
          qc.invalidateQueries({ queryKey: ["today-steps", user.id] });
          qc.invalidateQueries({ queryKey: ["week-steps", user.id] });
        },
      )
      .subscribe();
    return () => {
      supabase.removeChannel(ch);
    };
  }, [user, qc]);

  return useQuery({
    queryKey: ["today-steps", user?.id],
    enabled: !!user,
    queryFn: async (): Promise<DayTotals> => {
      const { data } = await supabase
        .from("activity_steps")
        .select("day, steps, distance_km, calories, exercise_minutes")
        .eq("user_id", user!.id)
        .eq("day", todayISO());
      const totals = (data ?? []).reduce<DayTotals>(
        (acc, r) => ({
          day: todayISO(),
          steps: acc.steps + r.steps,
          distance_km: acc.distance_km + Number(r.distance_km),
          calories: acc.calories + r.calories,
          exercise_minutes: acc.exercise_minutes + r.exercise_minutes,
        }),
        { day: todayISO(), steps: 0, distance_km: 0, calories: 0, exercise_minutes: 0 },
      );
      return totals;
    },
  });
}

export function useWeekSteps() {
  const { user } = useAuth();
  return useQuery({
    queryKey: ["week-steps", user?.id],
    enabled: !!user,
    queryFn: async (): Promise<DayTotals[]> => {
      const since = daysAgoISO(6);
      const { data } = await supabase
        .from("activity_steps")
        .select("day, steps, distance_km, calories, exercise_minutes")
        .eq("user_id", user!.id)
        .gte("day", since);
      // aggregate by day
      const map = new Map<string, DayTotals>();
      for (let i = 6; i >= 0; i--) {
        const d = daysAgoISO(i);
        map.set(d, { day: d, steps: 0, distance_km: 0, calories: 0, exercise_minutes: 0 });
      }
      for (const r of data ?? []) {
        const cur = map.get(r.day);
        if (!cur) continue;
        cur.steps += r.steps;
        cur.distance_km += Number(r.distance_km);
        cur.calories += r.calories;
        cur.exercise_minutes += r.exercise_minutes;
      }
      return [...map.values()];
    },
  });
}

export function useHistorySteps(days: number) {
  const { user } = useAuth();
  return useQuery({
    queryKey: ["history-steps", user?.id, days],
    enabled: !!user,
    queryFn: async (): Promise<DayTotals[]> => {
      const since = daysAgoISO(days - 1);
      const { data } = await supabase
        .from("activity_steps")
        .select("day, steps, distance_km, calories, exercise_minutes")
        .eq("user_id", user!.id)
        .gte("day", since);
      const map = new Map<string, DayTotals>();
      for (let i = days - 1; i >= 0; i--) {
        const d = daysAgoISO(i);
        map.set(d, { day: d, steps: 0, distance_km: 0, calories: 0, exercise_minutes: 0 });
      }
      for (const r of data ?? []) {
        const cur = map.get(r.day);
        if (!cur) continue;
        cur.steps += r.steps;
        cur.distance_km += Number(r.distance_km);
        cur.calories += r.calories;
        cur.exercise_minutes += r.exercise_minutes;
      }
      return [...map.values()];
    },
  });
}

export async function logManualSteps(input: {
  steps: number;
  distance_km?: number;
  calories?: number;
  exercise_minutes?: number;
}) {
  const { data: u } = await supabase.auth.getUser();
  if (!u.user) throw new Error("Not signed in");
  const { error } = await supabase.from("activity_steps").upsert(
    {
      user_id: u.user.id,
      day: todayISO(),
      source: "manual",
      steps: input.steps,
      distance_km: input.distance_km ?? 0,
      calories: input.calories ?? 0,
      exercise_minutes: input.exercise_minutes ?? 0,
    },
    { onConflict: "user_id,day,source" },
  );
  if (error) throw error;
}
