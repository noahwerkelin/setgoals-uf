import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const BadgeId = z.string().min(1).max(80);

export type UserBadge = {
  id: string;
  badge_id: string;
  earned_at: string;
};

/** Return all badges earned by the authenticated user. */
export const getUserBadges = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<UserBadge[]> => {
    const { data, error } = await context.supabase
      .from("user_badges")
      .select("id, badge_id, earned_at")
      .eq("user_id", context.userId)
      .order("earned_at", { ascending: true });
    if (error) throw error;
    return (data ?? []) as UserBadge[];
  });

/** Award a badge to the authenticated user. Idempotent. */
export const awardBadge = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => BadgeId.parse(d))
  .handler(async ({ data, context }): Promise<{ newlyAwarded: boolean }> => {
    const { data: existing } = await context.supabase
      .from("user_badges")
      .select("id")
      .eq("user_id", context.userId)
      .eq("badge_id", data)
      .maybeSingle();
    if (existing) return { newlyAwarded: false };

    const { error } = await context.supabase
      .from("user_badges")
      .insert({ user_id: context.userId, badge_id: data });
    if (error) throw error;
    return { newlyAwarded: true };
  });

/** Return badges earned by a child (called from the parent dashboard). */
export const getChildBadges = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ child_user_id: z.string().uuid() }).parse(d))
  .handler(async ({ data, context }): Promise<UserBadge[]> => {
    const { supabase } = context;
    // Verify the caller is a parent of this child.
    const { data: rel } = await supabase
      .from("parent_child_relationships")
      .select("id")
      .eq("parent_id", context.userId)
      .eq("child_user_id", data.child_user_id)
      .maybeSingle();
    if (!rel) return [];

    const { data: rows, error } = await supabase
      .from("user_badges")
      .select("id, badge_id, earned_at")
      .eq("user_id", data.child_user_id)
      .order("earned_at", { ascending: true });
    if (error) throw error;
    return (rows ?? []) as UserBadge[];
  });
