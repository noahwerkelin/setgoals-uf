import { createFileRoute } from "@tanstack/react-router";
import {
  verifyAppleJws,
  verifyAppleTransaction,
  type AppleRenewalInfo,
} from "@/lib/apple-jws.server";
import { PLAN_BY_PRODUCT_ID, syncAppleTransaction } from "@/lib/entitlements.server";

/**
 * App Store Server Notifications V2.
 *
 * Apple calls this endpoint for renewals, cancellations, expirations, refunds
 * and billing problems. Every payload is signed by Apple and verified against
 * Apple's certificate chain before we touch an entitlement — the URL being
 * public is fine because an unsigned request can never change anything.
 */

type NotificationPayload = {
  notificationType?: string;
  subtype?: string;
  data?: {
    signedTransactionInfo?: string;
    signedRenewalInfo?: string;
  };
};

export const Route = createFileRoute("/api/public/payments/apple-notifications")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        let body: { signedPayload?: string };
        try {
          body = (await request.json()) as { signedPayload?: string };
        } catch {
          return new Response("Invalid body", { status: 400 });
        }
        if (!body.signedPayload) return new Response("Missing signedPayload", { status: 400 });

        let payload: NotificationPayload;
        try {
          payload = await verifyAppleJws<NotificationPayload>(body.signedPayload);
        } catch {
          return new Response("Invalid signature", { status: 401 });
        }

        const signedTxn = payload.data?.signedTransactionInfo;
        if (!signedTxn) return new Response("ok");

        try {
          const txn = await verifyAppleTransaction(signedTxn);
          if (!PLAN_BY_PRODUCT_ID[txn.productId]) return new Response("ok");

          let autoRenew = true;
          if (payload.data?.signedRenewalInfo) {
            try {
              const renewal = await verifyAppleJws<AppleRenewalInfo>(payload.data.signedRenewalInfo);
              autoRenew = renewal.autoRenewStatus !== 0;
            } catch {
              /* fall back to the notification type below */
            }
          }
          if (payload.notificationType === "DID_CHANGE_RENEWAL_STATUS") {
            autoRenew = payload.subtype === "AUTO_RENEW_ENABLED";
          }
          if (payload.notificationType === "EXPIRED" || payload.notificationType === "REFUND") {
            autoRenew = false;
          }

          await syncAppleTransaction(txn, { autoRenew });
        } catch {
          return new Response("Invalid transaction", { status: 401 });
        }

        return new Response("ok");
      },
    },
  },
});
