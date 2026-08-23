import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const Input = z.object({
  scope: z.enum(["local", "national", "friends"]),
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
  .handler(async ({ data, context }): Promise<LeaderboardRow[]> => {
    // Use service-role client to call the locked-down leaderboard function.
    // Caller is already verified as an authenticated user by the middleware,
    // so the verified user id is passed explicitly (there is no auth.uid()
    // under the service-role connection).
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { data: rows, error } = await supabaseAdmin.rpc("leaderboard_ranked", {
      _scope: data.scope,
      _uid: context.userId,
    });
    if (error) throw error;
    return (rows ?? []) as LeaderboardRow[];
  });
