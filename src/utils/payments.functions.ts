import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { verifyAppleTransaction } from "@/lib/apple-jws.server";
import {
  PLAN_BY_PRODUCT_ID,
  clearEntitlement,
  reconcileStoredEntitlement,
  syncAppleTransaction,
} from "@/lib/entitlements.server";

type SyncResult =
  | { isPro: boolean; status: string; plan: string | null; expiresAt: string | null; paymentMethod: string }
  | { error: string };

function message(error: unknown): string {
  return error instanceof Error ? error.message : "Something went wrong with the App Store purchase.";
}

const INHERITED: SyncResult = {
  isPro: false,
  status: "inherited",
  plan: null,
  expiresAt: null,
  paymentMethod: "",
};

/**
 * Verify signed StoreKit 2 transactions handed over by the native app and grant
 * (or lapse) the PRO entitlement. This is the only way PRO can be unlocked —
 * the client never decides its own entitlement.
 */
export const syncStoreKitPurchase = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: { transactions: string[] }) => {
    if (!Array.isArray(data.transactions) || data.transactions.length === 0) {
      throw new Error("No App Store transactions to verify");
    }
    if (data.transactions.length > 25) throw new Error("Too many transactions");
    return data;
  })
  .handler(async ({ data, context }): Promise<SyncResult> => {
    try {
      const { userId, supabase } = context;

      // Child accounts inherit PRO Family — they never buy a plan themselves.
      const { data: childRow } = await supabase
        .from("children")
        .select("id")
        .eq("auth_user_id", userId)
        .maybeSingle();
      if (childRow) return INHERITED;

      const verified = [];
      for (const jws of data.transactions) {
        try {
          const txn = await verifyAppleTransaction(jws);
          if (PLAN_BY_PRODUCT_ID[txn.productId]) verified.push(txn);
        } catch {
          /* ignore transactions for other apps / products */
        }
      }
      if (!verified.length) return { error: "No valid SetGoals subscription was found on this Apple ID." };

      // Newest expiry wins — that is the subscription actually in force.
      verified.sort((a, b) => (b.expiresDate ?? 0) - (a.expiresDate ?? 0));
      const state = await syncAppleTransaction(verified[0], { userId });

      return {
        isPro: state.isPro,
        status: state.status,
        plan: state.plan,
        expiresAt: state.expiresAt,
        paymentMethod: state.isPro ? "Apple App Store" : "",
      };
    } catch (error) {
      return { error: message(error) };
    }
  });

/**
 * Re-evaluate the stored App Store entitlement (expiry, cancellation, refund).
 * Called whenever the PRO dashboard opens so a lapsed plan can never linger.
 */
export const syncSubscriptionStatus = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: Record<string, never> | undefined) => data ?? {})
  .handler(async ({ context }): Promise<SyncResult> => {
    try {
      const { userId, supabase } = context;

      const { data: childRow } = await supabase
        .from("children")
        .select("id")
        .eq("auth_user_id", userId)
        .maybeSingle();
      if (childRow) return INHERITED;

      const state = await reconcileStoredEntitlement(userId);
      if (!state) {
        return { isPro: false, status: "inactive", plan: null, expiresAt: null, paymentMethod: "" };
      }
      return {
        isPro: state.isPro,
        status: state.status,
        plan: state.plan,
        expiresAt: state.expiresAt,
        paymentMethod: state.isPro ? "Apple App Store" : "",
      };
    } catch (error) {
      return { error: message(error) };
    }
  });

/**
 * Used by account deletion: Apple subscriptions can only be cancelled by the
 * user in the App Store, so we just release the local entitlement.
 */
export const releaseEntitlement = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<{ ok: true } | { error: string }> => {
    try {
      await clearEntitlement(context.userId);
      return { ok: true };
    } catch (error) {
      return { error: message(error) };
    }
  });
