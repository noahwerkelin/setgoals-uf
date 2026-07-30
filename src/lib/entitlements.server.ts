/**
 * Server-only entitlement sync.
 *
 * The `user_settings` billing columns are protected by a DB trigger: only the
 * service role may write them. Both the payment webhook and the authenticated
 * "reconcile my subscription" server function funnel through here so the
 * entitlement rules live in exactly one place.
 */
import { createClient } from "@supabase/supabase-js";
import type { StripeEnv, createStripeClient } from "@/lib/stripe.server";

type Stripe = ReturnType<typeof createStripeClient>;

let _admin: any = null;
/** Service-role client (bypasses RLS + the billing guard trigger). */
export function adminClient(): any {
  if (!_admin) {
    _admin = createClient<any, any, any>(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
    );
  }
  return _admin;
}

export const PLAN_BY_PRICE: Record<string, string> = {
  pro_monthly: "monthly",
  pro_yearly: "yearly",
  pro_family_monthly: "family_monthly",
  pro_family_yearly: "family_yearly",
};

/** Statuses that still grant access. `past_due` keeps access while Stripe retries. */
export const ACTIVE_STATUSES = ["active", "trialing", "past_due"];

export function resolvePriceId(item: any): string {
  return (
    item?.price?.lookup_key || item?.price?.metadata?.lovable_external_id || item?.price?.id || ""
  );
}

function iso(seconds: number | null | undefined): string | null {
  return seconds ? new Date(seconds * 1000).toISOString() : null;
}

function customerId(subscription: any): string {
  return typeof subscription.customer === "string" ? subscription.customer : subscription.customer?.id ?? "";
}

/** Human label for the card on file, e.g. "Visa •• 4242". */
export async function fetchCardLabel(stripe: Stripe, subscription: any): Promise<string> {
  try {
    const pmId =
      typeof subscription.default_payment_method === "string"
        ? subscription.default_payment_method
        : subscription.default_payment_method?.id;
    let pm: any = typeof subscription.default_payment_method === "object" ? subscription.default_payment_method : null;
    if (!pm && pmId) pm = await stripe.paymentMethods.retrieve(pmId);
    if (!pm) {
      const cust: any = await stripe.customers.retrieve(customerId(subscription));
      const defId = cust?.invoice_settings?.default_payment_method;
      if (defId) pm = await stripe.paymentMethods.retrieve(typeof defId === "string" ? defId : defId.id);
    }
    if (!pm) return "";
    if (pm.card) {
      const brand = String(pm.card.brand ?? "card");
      return `${brand.charAt(0).toUpperCase()}${brand.slice(1)} •• ${pm.card.last4}`;
    }
    return String(pm.type ?? "");
  } catch {
    return "";
  }
}

/** Find the app user behind a Stripe subscription, with DB fallbacks. */
export async function resolveUserId(subscription: any, env: StripeEnv): Promise<string | null> {
  const fromMeta = subscription.metadata?.userId;
  if (fromMeta) return fromMeta;
  const db = adminClient();
  const bySub = await db
    .from("subscriptions")
    .select("user_id")
    .eq("stripe_subscription_id", subscription.id)
    .maybeSingle();
  if (bySub.data?.user_id) return bySub.data.user_id;
  const cust = customerId(subscription);
  if (!cust) return null;
  const byCust = await db
    .from("subscriptions")
    .select("user_id")
    .eq("stripe_customer_id", cust)
    .eq("environment", env)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  return byCust.data?.user_id ?? null;
}

export type SyncResult = {
  userId: string | null;
  isPro: boolean;
  plan: string | null;
  status: string;
  expiresAt: string | null;
};

/**
 * Write the Stripe subscription state into `subscriptions` + `user_settings`.
 * `paymentMethod` is optional; pass "" to leave the stored card untouched.
 */
export async function syncSubscription(
  subscription: any,
  env: StripeEnv,
  opts: { userId?: string | null; paymentMethod?: string } = {},
): Promise<SyncResult> {
  const db = adminClient();
  const userId = opts.userId ?? (await resolveUserId(subscription, env));
  const item = subscription.items?.data?.[0];
  const priceId = resolvePriceId(item);
  const plan = PLAN_BY_PRICE[priceId] ?? null;
  const periodStart = item?.current_period_start ?? subscription.current_period_start;
  const periodEnd = item?.current_period_end ?? subscription.current_period_end;
  const cancelling = !!subscription.cancel_at_period_end;
  const status: string = subscription.status;
  const stillInPaidPeriod = !!periodEnd && periodEnd * 1000 > Date.now();
  const isPro =
    ACTIVE_STATUSES.includes(status) || (status === "canceled" && stillInPaidPeriod);

  await db.from("subscriptions").upsert(
    {
      ...(userId ? { user_id: userId } : {}),
      stripe_subscription_id: subscription.id,
      stripe_customer_id: customerId(subscription),
      product_id: item?.price?.product ?? "",
      price_id: priceId,
      status,
      current_period_start: iso(periodStart),
      current_period_end: iso(periodEnd),
      cancel_at_period_end: cancelling,
      environment: env,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "stripe_subscription_id" },
  );

  const expiresAt = cancelling || status === "canceled" ? iso(periodEnd) : null;

  if (userId) {
    await db
      .from("user_settings")
      .update({
        is_pro: isPro,
        ...(plan ? { pro_plan: plan } : {}),
        pro_auto_renew: !cancelling && status !== "canceled",
        pro_since: iso(subscription.start_date) ?? new Date().toISOString(),
        pro_expires_at: expiresAt,
        pro_environment: env,
        pro_status: status,
        ...(opts.paymentMethod ? { pro_payment_method: opts.paymentMethod } : {}),
      })
      .eq("user_id", userId);
  }

  return { userId, isPro, plan, status, expiresAt };
}

/** No subscription at all in this environment — drop the entitlement. */
export async function clearEntitlement(userId: string, env: StripeEnv): Promise<void> {
  const db = adminClient();
  const { data: current } = await db
    .from("user_settings")
    .select("pro_environment,is_pro")
    .eq("user_id", userId)
    .maybeSingle();
  // Never clear an entitlement that belongs to the other environment.
  if (current && current.pro_environment !== env && current.is_pro) return;
  await db
    .from("user_settings")
    .update({
      is_pro: false,
      pro_auto_renew: false,
      pro_status: "inactive",
      pro_expires_at: new Date().toISOString(),
      pro_payment_method: "",
    })
    .eq("user_id", userId);
}
