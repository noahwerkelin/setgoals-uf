import { createFileRoute } from "@tanstack/react-router";
import { type StripeEnv, createStripeClient, verifyWebhook } from "@/lib/stripe.server";
import {
  adminClient,
  clearEntitlement,
  fetchCardLabel,
  resolveUserId,
  syncSubscription,
} from "@/lib/entitlements.server";

async function syncById(subscriptionId: string, env: StripeEnv) {
  const stripe = createStripeClient(env);
  const sub: any = await stripe.subscriptions.retrieve(subscriptionId);
  const paymentMethod = await fetchCardLabel(stripe, sub);
  await syncSubscription(sub, env, { paymentMethod });
}

async function handleSubscriptionEvent(subscription: any, env: StripeEnv) {
  const stripe = createStripeClient(env);
  const paymentMethod = await fetchCardLabel(stripe, subscription);
  await syncSubscription(subscription, env, { paymentMethod });
}

async function markDeleted(subscription: any, env: StripeEnv) {
  await adminClient()
    .from("subscriptions")
    .update({ status: "canceled", updated_at: new Date().toISOString() })
    .eq("stripe_subscription_id", subscription.id)
    .eq("environment", env);

  const userId = await resolveUserId(subscription, env);
  if (userId) await clearEntitlement(userId, env);
}

async function handleWebhook(req: Request, env: StripeEnv) {
  const event = await verifyWebhook(req, env);
  const object: any = event.data.object;

  switch (event.type) {
    case "customer.subscription.created":
    case "customer.subscription.updated":
      await handleSubscriptionEvent(object, env);
      break;
    case "customer.subscription.deleted":
      await markDeleted(object, env);
      break;
    // Checkout finished — grant access immediately instead of waiting for
    // the subscription event, which can arrive out of order.
    case "checkout.session.completed":
    case "checkout.session.async_payment_succeeded":
      if (object.subscription) {
        await syncById(
          typeof object.subscription === "string" ? object.subscription : object.subscription.id,
          env,
        );
      }
      break;
    // Renewals, dunning and recovery: refresh period end + status.
    case "invoice.paid":
    case "invoice.payment_succeeded":
    case "invoice.payment_failed": {
      const subId = object.subscription ?? object.parent?.subscription_details?.subscription;
      if (subId) await syncById(typeof subId === "string" ? subId : subId.id, env);
      break;
    }
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
