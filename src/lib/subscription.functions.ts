import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const planSchema = z.enum(["monthly", "yearly", "family_monthly", "family_yearly"]);

export type SubscriptionState = {
  isPro: boolean;
  plan: z.infer<typeof planSchema>;
  autoRenew: boolean;
  since: string | null;
  expiresAt: string | null;
  paymentMethod: string;
};

function periodEnd(since: string, plan: string): string {
  const d = new Date(since);
  const now = Date.now();
  // Roll forward from the start date to the next unexpired period boundary.
  const step = plan.endsWith("yearly") ? 12 : 1;
  let guard = 0;
  while (d.getTime() <= now && guard++ < 200) d.setMonth(d.getMonth() + step);
  return d.toISOString();
}

async function readState(userId: string): Promise<SubscriptionState> {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  const { data } = await supabaseAdmin
    .from("user_settings")
    .select("is_pro, pro_plan, pro_auto_renew, pro_since, pro_expires_at, pro_payment_method")
    .eq("user_id", userId)
    .maybeSingle();
  const expired = !!data?.pro_expires_at && new Date(data.pro_expires_at).getTime() <= Date.now();
  return {
    isPro: (data?.is_pro ?? false) && !expired,
    plan: (data?.pro_plan ?? "monthly") as SubscriptionState["plan"],
    autoRenew: data?.pro_auto_renew ?? true,
    since: data?.pro_since ?? null,
    expiresAt: data?.pro_expires_at ?? null,
    paymentMethod: data?.pro_payment_method ?? "",
  };
}

/** Child accounts never own a subscription — they inherit PRO Family from a parent. */
async function assertNotChild(supabase: NonNullable<unknown>, userId: string) {
  const client = supabase as {
    from: (t: string) => {
      select: (c: string) => {
        eq: (c: string, v: string) => { maybeSingle: () => Promise<{ data: unknown }> };
      };
    };
  };
  const { data } = await client.from("children").select("id").eq("auth_user_id", userId).maybeSingle();
  if (data) throw new Error("Child accounts cannot manage a subscription.");
}

export const getSubscription = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<SubscriptionState> => readState(context.userId));

export const startSubscription = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ plan: planSchema }).parse(d))
  .handler(async ({ data, context }): Promise<SubscriptionState> => {
    await assertNotChild(context.supabase, context.userId);
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    await supabaseAdmin
      .from("user_settings")
      .update({
        is_pro: true,
        pro_plan: data.plan,
        pro_auto_renew: true,
        pro_since: new Date().toISOString(),
        pro_expires_at: null,
        pro_payment_method: "Visa •• 4242",
      })
      .eq("user_id", context.userId);
    return readState(context.userId);
  });

export const changeSubscriptionPlan = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ plan: planSchema }).parse(d))
  .handler(async ({ data, context }): Promise<SubscriptionState> => {
    await assertNotChild(context.supabase, context.userId);
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    await supabaseAdmin
      .from("user_settings")
      .update({ pro_plan: data.plan })
      .eq("user_id", context.userId);
    return readState(context.userId);
  });

export const updatePaymentMethod = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ method: z.string().min(3).max(40) }).parse(d))
  .handler(async ({ data, context }): Promise<SubscriptionState> => {
    await assertNotChild(context.supabase, context.userId);
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    await supabaseAdmin
      .from("user_settings")
      .update({ pro_payment_method: data.method })
      .eq("user_id", context.userId);
    return readState(context.userId);
  });

/**
 * Cancel: PRO (and PRO Family access for linked children) stays active until the
 * end of the period already paid for, then lapses automatically.
 */
export const cancelSubscription = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<SubscriptionState> => {
    await assertNotChild(context.supabase, context.userId);
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const current = await readState(context.userId);
    if (!current.isPro) return current;
    const ends = periodEnd(current.since ?? new Date().toISOString(), current.plan);
    await supabaseAdmin
      .from("user_settings")
      .update({ pro_auto_renew: false, pro_expires_at: ends })
      .eq("user_id", context.userId);
    return readState(context.userId);
  });

/** Undo a pending cancellation while the plan is still inside the paid period. */
export const resumeSubscription = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<SubscriptionState> => {
    await assertNotChild(context.supabase, context.userId);
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    const current = await readState(context.userId);
    if (!current.isPro) return current;
    await supabaseAdmin
      .from("user_settings")
      .update({ pro_auto_renew: true, pro_expires_at: null })
      .eq("user_id", context.userId);
    return readState(context.userId);
  });
