/**
 * Real bridge to the device health ecosystem.
 *
 * There is no browser API for Apple HealthKit, Google Fit or Health Connect —
 * permission can only be granted by the OS itself. When SetGoals runs inside
 * its native shell (Capacitor, a WKWebView on iOS or an Android WebView), that
 * shell exposes a bridge and we hand the request over to the platform, which
 * shows the real system permission sheet.
 *
 * In a plain browser there is nothing to talk to, so we report `unavailable`
 * instead of pretending the account is connected.
 */

export type HealthProvider = "healthkit" | "googlefit";

export type HealthBridgeResult =
  | { status: "granted" }
  | { status: "denied" }
  | { status: "unavailable"; reason: "no-native-shell" | "wrong-platform" }
  | { status: "error"; message: string };

type NativeCall = { provider: HealthProvider; action: "authorize" | "revoke"; requestId: string };

type CapacitorHealthPlugin = {
  isAvailable?: () => Promise<{ available: boolean } | boolean>;
  requestAuthorization: (opts: { read: string[] }) => Promise<{ granted?: boolean } | boolean | void>;
  revokeAuthorization?: () => Promise<unknown>;
};

const READ_TYPES = ["steps", "distance", "activeEnergy"];

declare global {
  interface Window {
    Capacitor?: { Plugins?: Record<string, unknown>; getPlatform?: () => string };
    webkit?: { messageHandlers?: Record<string, { postMessage: (msg: unknown) => void }> };
    AndroidHealth?: { request: (payload: string) => void };
    /** Called by the native shell to resolve a pending bridge request. */
    __setgoalsHealthResolve?: (requestId: string, status: string) => void;
  }
}

function capacitorPlugin(provider: HealthProvider): CapacitorHealthPlugin | null {
  const plugins = typeof window !== "undefined" ? window.Capacitor?.Plugins : undefined;
  if (!plugins) return null;
  const names = provider === "healthkit"
    ? ["HealthKit", "Health", "CapacitorHealthkit"]
    : ["HealthConnect", "GoogleFit", "Health"];
  for (const n of names) {
    const p = plugins[n] as CapacitorHealthPlugin | undefined;
    if (p && typeof p.requestAuthorization === "function") return p;
  }
  return null;
}

function platform(): string {
  if (typeof window === "undefined") return "server";
  const cap = window.Capacitor?.getPlatform?.();
  if (cap) return cap;
  const ua = navigator.userAgent;
  if (/iPad|iPhone|iPod/.test(ua)) return "ios";
  if (/Android/.test(ua)) return "android";
  return "web";
}

/** True when the current OS can host the given health provider at all. */
export function isProviderSupportedOnPlatform(provider: HealthProvider): boolean {
  const p = platform();
  return provider === "healthkit" ? p === "ios" : p === "android";
}

/** True when a native shell is present that can serve health requests. */
export function hasNativeHealthBridge(provider: HealthProvider): boolean {
  if (typeof window === "undefined") return false;
  if (capacitorPlugin(provider)) return true;
  if (provider === "healthkit") return !!window.webkit?.messageHandlers?.healthkit;
  return typeof window.AndroidHealth?.request === "function";
}

function callWebViewBridge(call: NativeCall): Promise<HealthBridgeResult> {
  return new Promise((resolve) => {
    const timeout = setTimeout(() => finish("error"), 120_000);
    const finish = (status: string) => {
      clearTimeout(timeout);
      delete pending[call.requestId];
      if (status === "granted" || status === "authorized") resolve({ status: "granted" });
      else if (status === "denied") resolve({ status: "denied" });
      else resolve({ status: "error", message: status });
    };
    pending[call.requestId] = finish;

    const payload = { ...call, read: READ_TYPES };
    if (call.provider === "healthkit") window.webkit!.messageHandlers!.healthkit!.postMessage(payload);
    else window.AndroidHealth!.request(JSON.stringify(payload));
  });
}

const pending: Record<string, (status: string) => void> = {};

if (typeof window !== "undefined") {
  window.__setgoalsHealthResolve = (requestId, status) => pending[requestId]?.(status);
}

/** Ask the operating system for real health permission. */
export async function requestHealthAccess(provider: HealthProvider): Promise<HealthBridgeResult> {
  if (typeof window === "undefined") return { status: "unavailable", reason: "no-native-shell" };

  const plugin = capacitorPlugin(provider);
  if (plugin) {
    try {
      if (plugin.isAvailable) {
        const avail = await plugin.isAvailable();
        const ok = typeof avail === "boolean" ? avail : avail?.available;
        if (!ok) return { status: "unavailable", reason: "wrong-platform" };
      }
      const res = await plugin.requestAuthorization({ read: READ_TYPES });
      const granted = typeof res === "boolean" ? res : res?.granted !== false;
      return granted ? { status: "granted" } : { status: "denied" };
    } catch (e) {
      return { status: "error", message: e instanceof Error ? e.message : String(e) };
    }
  }

  if (hasNativeHealthBridge(provider)) {
    return callWebViewBridge({ provider, action: "authorize", requestId: crypto.randomUUID() });
  }

  return {
    status: "unavailable",
    reason: isProviderSupportedOnPlatform(provider) ? "no-native-shell" : "wrong-platform",
  };
}

/** Tell the OS we no longer want to read health data. */
export async function revokeHealthAccess(provider: HealthProvider): Promise<void> {
  const plugin = capacitorPlugin(provider);
  if (plugin?.revokeAuthorization) {
    try {
      await plugin.revokeAuthorization();
    } catch {
      /* the user can always revoke from system settings */
    }
    return;
  }
  if (hasNativeHealthBridge(provider)) {
    await callWebViewBridge({ provider, action: "revoke", requestId: crypto.randomUUID() }).catch(() => {});
  }
}
