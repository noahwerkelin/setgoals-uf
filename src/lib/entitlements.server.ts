/**
 * Server-only entitlement sync for Apple StoreKit purchases.
 *
 * The `user_settings` billing columns are protected by a DB trigger: only the
 * service role may write them. Both the App Store server notification route and
 * the authenticated "sync my purchase" server function funnel through here so
 * the entitlement rules live in exactly one place.
 */
import { createClient } from "@supabase/supabase-js";
import type { AppleTransaction } from "@/lib/apple-jws.server";
import { appleEnv } from "@/lib/apple-jws.server";

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

/** App Store product id -> app plan id. Mirrors src/lib/storekit.ts. */
export const PLAN_BY_PRODUCT_ID: Record<string, string> = {
  "app.setgoals.pro.monthly": "monthly",
  "app.setgoals.pro.yearly": "yearly",
  "app.setgoals.pro.family.monthly": "family_monthly",
  "app.setgoals.pro.family.yearly": "family_yearly",
};

const PAYMENT_METHOD = "Apple App Store";

function iso(ms: number | null | undefined): string | null {
  return ms ? new Date(ms).toISOString() : null;
}

export type EntitlementState = {
  isPro: boolean;
  plan: string | null;
  status: string;
  expiresAt: string | null;
  autoRenew: boolean;
  environment: "sandbox" | "live";
};

/** Work out what a verified transaction means right now. */
export function evaluateTransaction(
  txn: AppleTransaction,
  opts: { autoRenew?: boolean } = {},
): EntitlementState {
  const plan = PLAN_BY_PRODUCT_ID[txn.productId] ?? null;
  const env = appleEnv(txn.environment);
  const expiresAt = txn.expiresDate ?? null;
  const revoked = !!txn.revocationDate;
  const active = !revoked && (!expiresAt || expiresAt > Date.now());
  const autoRenew = opts.autoRenew ?? true;

  let status = "inactive";
  if (revoked) status = "revoked";
  else if (active) status = autoRenew ? "active" : "canceled";
  else status = "expired";

  return {
    isPro: active,
    plan,
    status,
    expiresAt: iso(expiresAt),
    autoRenew: active && autoRenew,
    environment: env,
  };
}

/**
 * Persist a verified App Store transaction into `subscriptions` + `user_settings`.
 * `userId` may be null for notifications we cannot attribute yet — the row is
 * still recorded so a later sync can pick it up.
 */
export async function syncAppleTransaction(
  txn: AppleTransaction,
  opts: { userId?: string | null; autoRenew?: boolean } = {},
): Promise<EntitlementState & { userId: string | null }> {
  const db = adminClient();
  const state = evaluateTransaction(txn, opts);
  const userId = opts.userId ?? (await resolveUserId(txn));

  await db.from("subscriptions").upsert(
    {
      ...(userId ? { user_id: userId } : {}),
      provider: "apple",
      provider_txn_id: txn.originalTransactionId,
      provider_account_id: txn.appAccountToken ?? "",
      product_id: txn.productId,
      price_id: state.plan ?? txn.productId,
      status: state.status,
      current_period_start: iso(txn.purchaseDate ?? txn.originalPurchaseDate ?? null),
      current_period_end: state.expiresAt,
      cancel_at_period_end: state.isPro && !state.autoRenew,
      environment: state.environment,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "provider_txn_id" },
  );

  if (userId) {
    await db
      .from("user_settings")
      .update({
        is_pro: state.isPro,
        ...(state.plan ? { pro_plan: state.plan } : {}),
        pro_auto_renew: state.autoRenew,
        pro_since: iso(txn.originalPurchaseDate ?? txn.purchaseDate ?? Date.now()),
        pro_expires_at: state.isPro && state.autoRenew ? null : state.expiresAt,
        pro_environment: state.environment,
        pro_status: state.status,
        pro_payment_method: PAYMENT_METHOD,
      })
      .eq("user_id", userId);
  }

  return { ...state, userId };
}

/** Find the app user behind an App Store transaction. */
export async function resolveUserId(txn: AppleTransaction): Promise<string | null> {
  // The app sets appAccountToken to the Supabase user id when starting checkout.
  const token = txn.appAccountToken;
  if (token && /^[0-9a-f-]{36}$/i.test(token)) return token;
  const db = adminClient();
  const { data } = await db
    .from("subscriptions")
    .select("user_id")
    .eq("provider_txn_id", txn.originalTransactionId)
    .maybeSingle();
  return data?.user_id ?? null;
}

/** Re-check a stored subscription and lapse the entitlement once it expires. */
export async function reconcileStoredEntitlement(userId: string): Promise<EntitlementState | null> {
  const db = adminClient();
  const { data: row } = await db
    .from("subscriptions")
    .select("*")
    .eq("user_id", userId)
    .eq("provider", "apple")
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (!row) {
    await clearEntitlement(userId);
    return null;
  }

  const expiresMs = row.current_period_end ? new Date(row.current_period_end).getTime() : null;
  const active = row.status !== "revoked" && (!expiresMs || expiresMs > Date.now());
  const autoRenew = active && !row.cancel_at_period_end;
  const status = row.status === "revoked" ? "revoked" : active ? (autoRenew ? "active" : "canceled") : "expired";

  if (!active && row.status !== status) {
    await db.from("subscriptions").update({ status, updated_at: new Date().toISOString() }).eq("id", row.id);
  }

  await db
    .from("user_settings")
    .update({
      is_pro: active,
      pro_plan: row.price_id || "monthly",
      pro_auto_renew: autoRenew,
      pro_expires_at: active && autoRenew ? null : row.current_period_end,
      pro_environment: row.environment,
      pro_status: status,
      pro_payment_method: active ? PAYMENT_METHOD : "",
    })
    .eq("user_id", userId);

  return {
    isPro: active,
    plan: row.price_id || null,
    status,
    expiresAt: row.current_period_end,
    autoRenew,
    environment: row.environment,
  };
}

/** No App Store subscription at all — drop the entitlement. */
export async function clearEntitlement(userId: string): Promise<void> {
  await adminClient()
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
