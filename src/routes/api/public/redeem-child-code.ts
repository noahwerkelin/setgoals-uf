import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";

/**
 * iOS kid-code entry (no session yet). Same single-use logic as the web
 * server function; a valid unused code is the only credential accepted.
 */
const Input = z.object({
  code: z
    .string()
    .trim()
    .toUpperCase()
    .transform((s) => s.replace(/[^A-Z0-9]/g, ""))
    .refine((s) => s.length === 8, "Invalid code"),
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

export const Route = createFileRoute("/api/public/redeem-child-code")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        let parsed;
        try {
          parsed = Input.safeParse(await request.json());
        } catch {
          return json({ error: "invalid_json" }, 400);
        }
        if (!parsed.success) return json({ error: "Invalid code" }, 400);
        try {
          const { redeemChildCodeServer } = await import("@/lib/children.server");
          return json(await redeemChildCodeServer(parsed.data.code));
        } catch (e) {
          return json({ error: e instanceof Error ? e.message : "Could not redeem code" }, 400);
        }
      },
    },
  },
});
