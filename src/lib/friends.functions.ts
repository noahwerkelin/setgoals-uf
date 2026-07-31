import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const SearchInput = z.object({ query: z.string().min(2).max(20) });
const StepsInput = z.object({
  ids: z.array(z.string().uuid()).max(50),
  day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
});

export type PublicUser = { id: string; username: string; name: string };
export type Friendship = { id: string; friend_id: string; username: string; name: string };

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

/** Return the authenticated user's confirmed friends. */
export const getFriendships = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<Friendship[]> => {
    const { data: rows, error } = await context.supabase
      .from("friendships")
      .select("id, user_id, friend_id")
      .or(`user_id.eq.${context.userId},friend_id.eq.${context.userId}`);
    if (error) throw error;
    if (!rows?.length) return [];

    const friendIds = rows.map((r) => (r.user_id === context.userId ? r.friend_id : r.user_id));
    const { data: profiles } = await context.supabase
      .from("profiles")
      .select("id, username, display_name")
      .in("id", friendIds);
    const profileMap = new Map((profiles ?? []).map((p) => [p.id, p]));

    return rows.map((r) => {
      const fid = r.user_id === context.userId ? r.friend_id : r.user_id;
      const p = profileMap.get(fid);
      return {
        id: fid,
        friend_id: r.id, // friendship row id, for deletion
        username: p?.username ?? "",
        name: p?.display_name || p?.username || "",
      };
    });
  });

/** Add a friend by user id. Returns the new friend id. */
export const addFriendship = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ friend_id: z.string().uuid() }).parse(d))
  .handler(async ({ data, context }): Promise<{ ok: true } | { error: string }> => {
    if (data.friend_id === context.userId) return { error: "Cannot add yourself" };
    const { data: existing } = await context.supabase
      .from("friendships")
      .select("id")
      .or(
        `and(user_id.eq.${context.userId},friend_id.eq.${data.friend_id}),and(user_id.eq.${data.friend_id},friend_id.eq.${context.userId})`,
      )
      .maybeSingle();
    if (existing) return { error: "Already friends" };

    const { error } = await context.supabase
      .from("friendships")
      .insert({ user_id: context.userId, friend_id: data.friend_id });
    if (error) return { error: error.message };
    return { ok: true };
  });

/** Remove a friendship. */
export const removeFriendship = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ friendship_id: z.string().uuid() }).parse(d))
  .handler(async ({ data, context }): Promise<{ ok: true } | { error: string }> => {
    const { error } = await context.supabase
      .from("friendships")
      .delete()
      .eq("id", data.friendship_id)
      .or(`user_id.eq.${context.userId},friend_id.eq.${context.userId}`);
    if (error) return { error: error.message };
    return { ok: true };
  });
