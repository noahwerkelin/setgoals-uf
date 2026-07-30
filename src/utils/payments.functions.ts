import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { type StripeEnv, createStripeClient, getStripeErrorMessage } from "@/lib/stripe.server";
import { clearEntitlement, fetchCardLabel, syncSubscription } from "@/lib/entitlements.server";

type CheckoutSessionResult = { clientSecret: string } | { error: string };
type PortalSessionResult = { url: string } | { error: string };
type MutationResult = { ok: true } | { error: string };
type SyncResult =
  | { isPro: boolean; status: string; plan: string | null; paymentMethod: string }
  | { error: string };


async function resolveOrCreateCustomer(
  stripe: ReturnType<typeof createStripeClient>,
  options: { email?: string; userId?: string },
): Promise<string> {
  if (options.userId && !/^[a-zA-Z0-9_-]+$/.test(options.userId)) {
    throw new Error("Invalid userId");
  }
  if (options.userId) {
    const found = await stripe.customers.search({
      query: `metadata['userId']:'${options.userId}'`,
      limit: 1,
    });
    if (found.data.length) return found.data[0].id;
  }
  if (options.email) {
    const existing = await stripe.customers.list({ email: options.email, limit: 1 });
    if (existing.data.length) {
      const customer = existing.data[0];
      if (options.userId && customer.metadata?.userId !== options.userId) {
        await stripe.customers.update(customer.id, {
          metadata: { ...customer.metadata, userId: options.userId },
        });
      }
      return customer.id;
    }
  }
  const created = await stripe.customers.create({
    ...(options.email && { email: options.email }),
    ...(options.userId && { metadata: { userId: options.userId } }),
  });
  return created.id;
}

/** Find the caller's active-ish subscription in the given environment. */
async function findSubscription(
  stripe: ReturnType<typeof createStripeClient>,
  userId: string,
) {
  if (!/^[a-zA-Z0-9_-]+$/.test(userId)) throw new Error("Invalid userId");
  const subs = await stripe.subscriptions.search({
    query: `metadata['userId']:'${userId}'`,
    limit: 20,
  });
  const usable = subs.data.filter((s) =>
    ["active", "trialing", "past_due", "paused", "incomplete"].includes(s.status),
  );
  return usable[0] ?? null;
}

export const createCheckoutSession = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: { priceId: string; returnUrl: string; environment: StripeEnv }) => {
    if (!/^[a-zA-Z0-9_-]+$/.test(data.priceId)) throw new Error("Invalid priceId");
    return data;
  })
  .handler(async ({ data, context }): Promise<CheckoutSessionResult> => {
    try {
      const { userId, supabase } = context;

      // Child accounts inherit PRO Family — they never buy a plan themselves.
      const { data: childRow } = await supabase
        .from("children")
        .select("id")
        .eq("auth_user_id", userId)
        .maybeSingle();
      if (childRow) return { error: "Child accounts cannot purchase a subscription." };

      const {
        data: { user },
      } = await supabase.auth.getUser();

      const stripe = createStripeClient(data.environment);
      const prices = await stripe.prices.list({ lookup_keys: [data.priceId] });
      if (!prices.data.length) return { error: "Price not found" };
      const stripePrice = prices.data[0];
      const isRecurring = stripePrice.type === "recurring";

      const customerId = await resolveOrCreateCustomer(stripe, {
        email: user?.email ?? undefined,
        userId,
      });

      const session = await stripe.checkout.sessions.create({
        line_items: [{ price: stripePrice.id, quantity: 1 }],
        mode: isRecurring ? "subscription" : "payment",
        ui_mode: "embedded_page",
        return_url: data.returnUrl,
        customer: customerId,
        managed_payments: { enabled: true },
        metadata: { userId, managed_payments: "true" },
        ...(isRecurring && { subscription_data: { metadata: { userId } } }),
      } as any);

      return { clientSecret: session.client_secret ?? "" };
    } catch (error) {
      return { error: getStripeErrorMessage(error) };
    }
  });

export const createPortalSession = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: { returnUrl?: string; environment: StripeEnv }) => data)
  .handler(async ({ data, context }): Promise<PortalSessionResult> => {
    try {
      const stripe = createStripeClient(data.environment);
      const sub = await findSubscription(stripe, context.userId);
      let customerId = sub
        ? typeof sub.customer === "string"
          ? sub.customer
          : sub.customer?.id
        : undefined;
      if (!customerId) {
        const customers = await stripe.customers.search({
          query: `metadata['userId']:'${context.userId}'`,
          limit: 1,
        });
        customerId = customers.data[0]?.id;
      }
      if (!customerId) return { error: "No billing account found" };

      const portal = await stripe.billingPortal.sessions.create({
        customer: customerId,
        ...(data.returnUrl && { return_url: data.returnUrl }),
      });
      return { url: portal.url };
    } catch (error) {
      return { error: getStripeErrorMessage(error) };
    }
  });

/** Cancel at the end of the paid period (access stays until then). */
export const cancelStripeSubscription = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: { environment: StripeEnv }) => data)
  .handler(async ({ data, context }): Promise<MutationResult> => {
    try {
      const stripe = createStripeClient(data.environment);
      const sub = await findSubscription(stripe, context.userId);
      if (!sub) return { error: "No active subscription found" };
      await stripe.subscriptions.update(sub.id, { cancel_at_period_end: true });
      return { ok: true };
    } catch (error) {
      return { error: getStripeErrorMessage(error) };
    }
  });

/** Undo a pending cancellation while still inside the paid period. */
export const resumeStripeSubscription = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: { environment: StripeEnv }) => data)
  .handler(async ({ data, context }): Promise<MutationResult> => {
    try {
      const stripe = createStripeClient(data.environment);
      const sub = await findSubscription(stripe, context.userId);
      if (!sub) return { error: "No active subscription found" };
      await stripe.subscriptions.update(sub.id, { cancel_at_period_end: false });
      return { ok: true };
    } catch (error) {
      return { error: getStripeErrorMessage(error) };
    }
  });

/** Switch plans on the existing subscription, prorated. */
export const changeStripePlan = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: { priceId: string; environment: StripeEnv }) => {
    if (!/^[a-zA-Z0-9_-]+$/.test(data.priceId)) throw new Error("Invalid priceId");
    return data;
  })
  .handler(async ({ data, context }): Promise<MutationResult> => {
    try {
      const stripe = createStripeClient(data.environment);
      const sub = await findSubscription(stripe, context.userId);
      if (!sub) return { error: "No active subscription found" };
      const prices = await stripe.prices.list({ lookup_keys: [data.priceId] });
      if (!prices.data.length) return { error: "Price not found" };
      const item = sub.items.data[0];
      await stripe.subscriptions.update(sub.id, {
        items: [{ id: item.id, price: prices.data[0].id }],
        proration_behavior: "create_prorations",
        cancel_at_period_end: false,
      });
      return { ok: true };
    } catch (error) {
      return { error: getStripeErrorMessage(error) };
    }
  });
