/**
 * Bridge to Apple StoreKit (In-App Purchase).
 *
 * There is no browser API for StoreKit — purchases can only be made by the OS.
 * When SetGoals runs inside its native shell (Capacitor or a WKWebView), the
 * shell exposes a bridge and we hand the purchase over to StoreKit, which shows
 * the real App Store payment sheet. The shell returns the signed transactions
 * (JWS, StoreKit 2) which the server verifies against Apple's certificate chain
 * before granting PRO.
 *
 * In a plain browser there is nothing to talk to, so we say so honestly instead
 * of faking a purchase.
 */

export type PlanId = "monthly" | "yearly" | "family_monthly" | "family_yearly";

/** App Store product identifiers — must match App Store Connect exactly. */
export const PLAN_PRODUCT_IDS: Record<PlanId, string> = {
  monthly: "app.setgoals.pro.monthly",
  yearly: "app.setgoals.pro.yearly",
  family_monthly: "app.setgoals.pro.family.monthly",
  family_yearly: "app.setgoals.pro.family.yearly",
};

export const PLAN_BY_PRODUCT_ID: Record<string, PlanId> = Object.fromEntries(
  Object.entries(PLAN_PRODUCT_IDS).map(([plan, id]) => [id, plan as PlanId]),
) as Record<string, PlanId>;

export type StoreKitResult =
  | { status: "purchased"; transactions: string[] }
  | { status: "restored"; transactions: string[] }
  | { status: "nothing-to-restore" }
  | { status: "cancelled" }
  | { status: "pending" }
  | { status: "unavailable"; reason: "no-native-shell" | "wrong-platform" }
  | { status: "error"; message: string };

type NativePayload = {
  status?: string;
  transactions?: string[];
  jws?: string;
  message?: string;
};

type StoreKitPlugin = {
  purchase?: (opts: { productId: string }) => Promise<NativePayload>;
  purchaseProduct?: (opts: { productId: string }) => Promise<NativePayload>;
  restorePurchases?: () => Promise<NativePayload>;
  restore?: () => Promise<NativePayload>;
  manageSubscriptions?: () => Promise<unknown>;
};

declare global {
  interface Window {
    Capacitor?: { Plugins?: Record<string, unknown>; getPlatform?: () => string };
    webkit?: { messageHandlers?: Record<string, { postMessage: (msg: unknown) => void }> };
    /** Called by the native shell to resolve a pending StoreKit request. */
    __setgoalsStoreKitResolve?: (requestId: string, payload: NativePayload | string) => void;
  }
}

function capacitorPlugin(): StoreKitPlugin | null {
  const plugins = typeof window !== "undefined" ? window.Capacitor?.Plugins : undefined;
  if (!plugins) return null;
  for (const n of ["StoreKit", "CapacitorStoreKit", "InAppPurchase", "InAppPurchases", "Purchases"]) {
    const p = plugins[n] as StoreKitPlugin | undefined;
    if (p && (typeof p.purchase === "function" || typeof p.purchaseProduct === "function")) return p;
  }
  return null;
}

export function platform(): string {
  if (typeof window === "undefined") return "server";
  const cap = window.Capacitor?.getPlatform?.();
  if (cap) return cap;
  const ua = navigator.userAgent;
  if (/iPad|iPhone|iPod/.test(ua) || (/Macintosh/.test(ua) && "ontouchend" in document)) return "ios";
  if (/Android/.test(ua)) return "android";
  return "web";
}

/** StoreKit only exists on Apple platforms. */
export function isStoreKitSupportedOnPlatform(): boolean {
  return platform() === "ios";
}

/** True when a native shell is present that can serve StoreKit requests. */
export function hasStoreKitBridge(): boolean {
  if (typeof window === "undefined") return false;
  if (capacitorPlugin()) return true;
  return !!window.webkit?.messageHandlers?.storekit;
}

const pending: Record<string, (payload: NativePayload) => void> = {};

if (typeof window !== "undefined") {
  window.__setgoalsStoreKitResolve = (requestId, payload) => {
    const parsed: NativePayload = typeof payload === "string" ? { status: payload } : payload ?? {};
    pending[requestId]?.(parsed);
  };
}

function callWebViewBridge(action: "purchase" | "restore" | "manage", productId?: string): Promise<StoreKitResult> {
  return new Promise((resolve) => {
    const requestId = crypto.randomUUID();
    const timeout = setTimeout(() => finish({ status: "error", message: "timeout" }), 180_000);
    const finish = (payload: NativePayload) => {
      clearTimeout(timeout);
      delete pending[requestId];
      resolve(normalize(payload));
    };
    pending[requestId] = finish;
    window.webkit!.messageHandlers!.storekit!.postMessage({ action, productId, requestId });
  });
}

function normalize(payload: NativePayload): StoreKitResult {
  const txns = payload.transactions ?? (payload.jws ? [payload.jws] : []);
  const status = (payload.status ?? (txns.length ? "purchased" : "error")).toLowerCase();
  if (status === "purchased" || status === "success" || status === "ok") {
    return { status: "purchased", transactions: txns };
  }
  if (status === "restored") {
    return txns.length ? { status: "restored", transactions: txns } : { status: "nothing-to-restore" };
  }
  if (status === "cancelled" || status === "canceled" || status === "userCancelled".toLowerCase()) {
    return { status: "cancelled" };
  }
  if (status === "pending" || status === "deferred") return { status: "pending" };
  if (status === "nothing-to-restore" || status === "empty") return { status: "nothing-to-restore" };
  return { status: "error", message: payload.message ?? status };
}

function unavailable(): StoreKitResult {
  return {
    status: "unavailable",
    reason: isStoreKitSupportedOnPlatform() ? "no-native-shell" : "wrong-platform",
  };
}

/** Start a real StoreKit purchase for a plan. */
export async function purchasePlan(plan: PlanId): Promise<StoreKitResult> {
  if (typeof window === "undefined") return unavailable();
  const productId = PLAN_PRODUCT_IDS[plan];

  const plugin = capacitorPlugin();
  if (plugin) {
    try {
      const fn = plugin.purchase ?? plugin.purchaseProduct!;
      return normalize((await fn.call(plugin, { productId })) ?? {});
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (/cancel/i.test(msg)) return { status: "cancelled" };
      return { status: "error", message: msg };
    }
  }

  if (hasStoreKitBridge()) return callWebViewBridge("purchase", productId);
  return unavailable();
}

/** Ask StoreKit for the current entitlements on this Apple ID. */
export async function restorePurchases(): Promise<StoreKitResult> {
  if (typeof window === "undefined") return unavailable();

  const plugin = capacitorPlugin();
  if (plugin && (plugin.restorePurchases || plugin.restore)) {
    try {
      const fn = plugin.restorePurchases ?? plugin.restore!;
      const res = normalize((await fn.call(plugin)) ?? {});
      if (res.status === "purchased") return { status: "restored", transactions: res.transactions };
      return res;
    } catch (e) {
      return { status: "error", message: e instanceof Error ? e.message : String(e) };
    }
  }

  if (hasStoreKitBridge()) return callWebViewBridge("restore");
  return unavailable();
}

/**
 * Open Apple's subscription management sheet.
 * Apple requires cancellations and plan changes to happen there — an app may
 * not cancel an App Store subscription on the user's behalf.
 */
export async function openManageSubscriptions(): Promise<void> {
  const plugin = capacitorPlugin();
  if (plugin?.manageSubscriptions) {
    try {
      await plugin.manageSubscriptions();
      return;
    } catch {
      /* fall through to the URL below */
    }
  }
  if (hasStoreKitBridge() && window.webkit?.messageHandlers?.storekit) {
    await callWebViewBridge("manage");
    return;
  }
  if (typeof window !== "undefined") {
    window.open("https://apps.apple.com/account/subscriptions", "_blank", "noopener,noreferrer");
  }
}
