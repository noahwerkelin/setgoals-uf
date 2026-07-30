import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";

export function todayKey(d = new Date()) {
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-${String(d.getUTCDate()).padStart(2, "0")}`;
}

/**
 * Bonus screen-time minutes gifted by a parent for today.
 * Lives on the same daily balance row the Screen Time bridge reads.
 */
export function useBonusMin(): number {
  const [bonus, setBonus] = useState(0);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      const { data: auth } = await supabase.auth.getUser();
      const uid = auth.user?.id;
      if (!uid) return;
      const { data } = await supabase
        .from("earned_balances")
        .select("bonus_min")
        .eq("user_id", uid)
        .eq("day", todayKey())
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
  }, []);

  return bonus;
}
