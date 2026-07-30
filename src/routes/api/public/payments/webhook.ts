import { createFileRoute } from "@tanstack/react-router";
import { createClient } from "@supabase/supabase-js";
import { type StripeEnv, verifyWebhook } from "@/lib/stripe.server";

let _supabase: any = null;
function getSupabase(): any {
  if (!_supabase) {
    _supabase = createClient<any, any, any>(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
    );
  }
  return _supabase;
}

const PLAN_BY_PRICE: Record<string, string> = {
  pro_monthly: "monthly",
  pro_yearly: "yearly",
  pro_family_monthly: "family_monthly",
  pro_family_yearly: "family_yearly",
};

function resolvePriceId(item: any): string {
  return item?.price?.lookup_key || item?.price?.metadata?.lovable_external_id || item?.price?.id || "";
}

function iso(seconds: number | null | undefined): string | null {
  return seconds ? new Date(seconds * 1000).toISOString() : null;
}

async function syncEntitlement(userId: string, subscription: any, priceId: string) {
  const plan = PLAN_BY_PRICE[priceId];
  const item = subscription.items?.data?.[0];
  const periodEnd = item?.current_period_end ?? subscription.current_period_end;
  const cancelling = !!subscription.cancel_at_period_end;
  const active = ["active", "trialing", "past_due"].includes(subscription.status);
  const canceled = subscription.status === "canceled";

  await getSupabase()
    .from("user_settings")
    .update({
      is_pro: active || (canceled && !!periodEnd && periodEnd * 1000 > Date.now()),
      ...(plan ? { pro_plan: plan } : {}),
      pro_auto_renew: !cancelling && !canceled,
      pro_since: iso(subscription.start_date) ?? new Date().toISOString(),
      pro_expires_at: cancelling || canceled ? iso(periodEnd) : null,
    })
    .eq("user_id", userId);
}

async function upsertSubscription(subscription: any, env: StripeEnv) {
  const userId = subscription.metadata?.userId;
  const item = subscription.items?.data?.[0];
  const priceId = resolvePriceId(item);
  const periodStart = item?.current_period_start ?? subscription.current_period_start;
  const periodEnd = item?.current_period_end ?? subscription.current_period_end;

  await getSupabase().from("subscriptions").upsert(
    {
      user_id: userId,
      stripe_subscription_id: subscription.id,
      stripe_customer_id:
        typeof subscription.customer === "string" ? subscription.customer : subscription.customer?.id,
      product_id: item?.price?.product ?? "",
      price_id: priceId,
      status: subscription.status,
      current_period_start: iso(periodStart),
      current_period_end: iso(periodEnd),
      cancel_at_period_end: subscription.cancel_at_period_end ?? false,
      environment: env,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "stripe_subscription_id" },
  );

  if (userId) await syncEntitlement(userId, subscription, priceId);
}

async function markDeleted(subscription: any, env: StripeEnv) {
  await getSupabase()
    .from("subscriptions")
    .update({ status: "canceled", updated_at: new Date().toISOString() })
    .eq("stripe_subscription_id", subscription.id)
    .eq("environment", env);

  const userId = subscription.metadata?.userId;
  if (userId) {
    await getSupabase()
      .from("user_settings")
      .update({ is_pro: false, pro_auto_renew: false, pro_expires_at: new Date().toISOString() })
      .eq("user_id", userId);
  }
}

async function handleWebhook(req: Request, env: StripeEnv) {
  const event = await verifyWebhook(req, env);

  switch (event.type) {
    case "customer.subscription.created":
    case "customer.subscription.updated":
      await upsertSubscription(event.data.object, env);
      break;
    case "customer.subscription.deleted":
      await markDeleted(event.data.object, env);
      break;
    default:
      console.log("Unhandled event:", event.type);
  }
}

export const Route = createFileRoute("/api/public/payments/webhook")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        const rawEnv = new URL(request.url).searchParams.get("env");
        if (rawEnv !== "sandbox" && rawEnv !== "live") {
          console.error("Webhook with invalid env:", rawEnv);
          return Response.json({ received: true, ignored: "invalid env" });
        }
        try {
          await handleWebhook(request, rawEnv as StripeEnv);
          return Response.json({ received: true });
        } catch (e) {
          console.error("Webhook error:", e);
          return new Response("Webhook error", { status: 400 });
        }
      },
    },
  },
});
