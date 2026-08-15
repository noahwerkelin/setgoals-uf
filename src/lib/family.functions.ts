import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

export type FamilyTodayRow = {
  member_id: string;
  name: string;
  avatar: string | null;
  steps: number;
  relation: string;
  is_self: boolean;
};

export type FamilyProStatusRow = {
  active: boolean;
  cancelling: boolean;
  ends_at: string | null;
  environment: string | null;
  status: string | null;
};

/** Today's family overview for the authenticated caller. */
export const getFamilyToday = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<FamilyTodayRow[]> => {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { data, error } = await supabaseAdmin.rpc("family_today", { _uid: context.userId });
    if (error) throw error;
    return (data ?? []) as FamilyTodayRow[];
  });

/** PRO Family status inherited from the caller's linked parent, if any. */
export const getParentFamilyProStatus = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<FamilyProStatusRow | null> => {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const { data, error } = await supabaseAdmin.rpc("parent_family_pro_status", {
      _uid: context.userId,
    });
    if (error) throw error;
    return ((data ?? []) as FamilyProStatusRow[])[0] ?? null;
  });
