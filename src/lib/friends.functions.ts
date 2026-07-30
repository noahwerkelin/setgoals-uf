import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const SearchInput = z.object({ query: z.string().min(2).max(20) });
const StepsInput = z.object({
  ids: z.array(z.string().uuid()).max(50),
  day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
});

export type PublicUser = { id: string; username: string; name: string };

/** Search real accounts by username. Signed-in users only. */
export const searchUsersByUsername = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => SearchInput.parse(d))
  .handler(async ({ data, context }): Promise<PublicUser[]> => {
    const q = data.query.trim().toLowerCase().replace(/[%_]/g, "");
    if (q.length < 2) return [];
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { data: rows, error } = await supabaseAdmin
      .from("profiles")
      .select("id, username, display_name")
      .ilike("username", `%${q}%`)
      .neq("id", context.userId)
      .limit(8);
    if (error) throw error;
    return (rows ?? []).map((r) => ({
      id: r.id,
      username: r.username,
      name: r.display_name || r.username,
    }));
  });

/** Today's real step totals for a set of friend ids. */
export const getFriendsSteps = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => StepsInput.parse(d))
  .handler(async ({ data }): Promise<Record<string, number>> => {
    if (data.ids.length === 0) return {};
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { data: rows, error } = await supabaseAdmin
      .from("activity_steps")
      .select("user_id, steps")
      .in("user_id", data.ids)
      .eq("day", data.day);
    if (error) throw error;
    const out: Record<string, number> = {};
    for (const id of data.ids) out[id] = 0;
    for (const r of rows ?? []) out[r.user_id] = (out[r.user_id] ?? 0) + (r.steps ?? 0);
    return out;
  });
