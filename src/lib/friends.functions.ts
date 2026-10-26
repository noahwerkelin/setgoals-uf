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
    const { data: rows, error } = await context.supabase.rpc("search_friend_users", { _query: data.query });
    if (error) throw error;
    return rows ?? [];
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
    const { data: rows, error } = await context.supabase.rpc("my_friends");
    if (error) throw error;
    return (rows ?? []).map((r) => ({ id: r.id, friend_id: r.friendship_id, username: r.username, name: r.name }));
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
      .rpc("add_my_friend", { _friend_id: data.friend_id });
    if (error) return { error: error.message };
    return { ok: true };
  });

/** Remove a friendship. */
export const removeFriendship = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ friendship_id: z.string().uuid() }).parse(d))
  .handler(async ({ data, context }): Promise<{ ok: true } | { error: string }> => {
    const { error } = await context.supabase.rpc("remove_my_friend", { _friendship_id: data.friendship_id });
    if (error) return { error: error.message };
    return { ok: true };
  });

export type FriendRequest = { id: string; user_id: string; username: string; name: string; direction: "incoming" | "outgoing" };
export const getFriendRequests = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<FriendRequest[]> => {
    const { data, error } = await context.supabase.rpc("my_friend_requests");
    if (error) throw error;
    return (data ?? []).map((r) => ({ ...r, direction: r.direction === "incoming" ? "incoming" : "outgoing" }));
  });
export const respondToFriendRequest = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ id: z.string().uuid(), accept: z.boolean() }).parse(d))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.rpc(data.accept ? "accept_friend_request" : "dismiss_friend_request", { _request_id: data.id });
    if (error) throw error;
    return { ok: true };
  });
