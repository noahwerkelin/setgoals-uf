import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const Input = z.object({
  period: z.enum(["daily", "weekly", "monthly", "alltime"]),
});

export type LeaderboardRow = {
  user_id: string;
  display_name: string;
  username: string;
  avatar_url: string | null;
  total_steps: number;
  rank: number;
};

export const getLeaderboard = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => Input.parse(d))
  .handler(async ({ data }): Promise<LeaderboardRow[]> => {
    // Use service-role client to call the locked-down leaderboard() function.
    // Caller is already verified as an authenticated user by the middleware.
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { data: rows, error } = await supabaseAdmin.rpc("leaderboard", {
      _period: data.period,
    });
    if (error) throw error;
    return (rows ?? []) as LeaderboardRow[];
  });
