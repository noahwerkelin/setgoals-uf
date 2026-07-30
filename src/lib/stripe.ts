import { loadStripe, type Stripe } from "@stripe/stripe-js";

type StripeEnv = "sandbox" | "live";

const clientToken = import.meta.env.VITE_PAYMENTS_CLIENT_TOKEN;

function paymentsEnvironment(): StripeEnv {
  if (clientToken?.startsWith("pk_test_")) return "sandbox";
  if (clientToken?.startsWith("pk_live_")) return "live";
  throw new Error(
    "Payments are not configured for this build. Complete go-live in your Lovable project to enable production checkout.",
  );
}

let stripePromise: Promise<Stripe | null> | null = null;

export function getStripe(): Promise<Stripe | null> {
  if (!stripePromise) {
    paymentsEnvironment();
    stripePromise = loadStripe(clientToken as string);
  }
  return stripePromise;
}

export function getStripeEnvironment(): StripeEnv {
  return paymentsEnvironment();
}

/**
 * Same as getStripeEnvironment() but never throws. Used by entitlement checks
 * that must keep working in builds where payments aren't configured yet.
 */
export function getStripeEnvironmentSafe(): StripeEnv | null {
  try {
    return paymentsEnvironment();
  } catch {
    return null;
  }
}

/** App plan ids -> catalog price ids created in the payment provider. */
export const PLAN_PRICE_IDS = {
  monthly: "pro_monthly",
  yearly: "pro_yearly",
  family_monthly: "pro_family_monthly",
  family_yearly: "pro_family_yearly",
} as const;

export type PlanId = keyof typeof PLAN_PRICE_IDS;
