import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { localDayKey, useDayKey } from "./day";

/** Daily key used for balances — local calendar day, so it resets at local midnight. */
export function todayKey(d = new Date()) {
  return localDayKey(d);
}

/**
 * Bonus screen-time minutes gifted by a parent for today.
 * Lives on the same daily balance row the Screen Time bridge reads.
 */
export function useBonusMin(): number {
  const [bonus, setBonus] = useState(0);
  const day = useDayKey();

  useEffect(() => {
    setBonus(0);
    let cancelled = false;
    const load = async () => {
      const { data: auth } = await supabase.auth.getUser();
      const uid = auth.user?.id;
      if (!uid) return;
      const { data } = await supabase
        .from("earned_balances")
        .select("bonus_min")
        .eq("user_id", uid)
        .eq("day", day)
        .maybeSingle();
      if (!cancelled) setBonus(data?.bonus_min ?? 0);
    };
    void load();
    const channel = supabase
      .channel("my-bonus-min")
      .on("postgres_changes", { event: "*", schema: "public", table: "earned_balances" }, () => void load())
      .subscribe();
    return () => {
      cancelled = true;
      void supabase.removeChannel(channel);
    };
  }, [day]);

  return bonus;
}

/** Saves the PRO rollover on/off choice to the account so every device agrees. */
export async function saveRolloverPref(on: boolean) {
  const { data: auth } = await supabase.auth.getUser();
  const uid = auth.user?.id;
  if (!uid) return;
  await supabase.from("user_settings").update({ st_rollover: on }).eq("user_id", uid);
}

/**
 * Today's PRO rollover, computed once per local day by the backend from
 * yesterday's earned + bonus + rollover - used, capped at the daily cap.
 */
export function useRolloverMin(isPro: boolean): number {
  const [min, setMin] = useState(0);
  const day = useDayKey();
  useEffect(() => {
    setMin(0);
    if (!isPro) return;
    let cancelled = false;
    void supabase.rpc("claim_rollover", { _day: day }).then(({ data }) => {
      if (!cancelled) setMin(typeof data === "number" ? data : 0);
    });
    return () => {
      cancelled = true;
    };
  }, [day, isPro]);
  return min;
}
