import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";

/**
 * Username availability for the iOS app during sign-up (no session yet).
 * Returns only a boolean; the underlying DB function stays service-role only.
 */
const Input = z.object({ username: z.string().min(1).max(40) });

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}

export const Route = createFileRoute("/api/public/username-available")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        let parsed;
        try {
          parsed = Input.safeParse(await request.json());
        } catch {
          return json({ error: "invalid_json" }, 400);
        }
        if (!parsed.success) return json({ error: "invalid_input" }, 400);
        const clean = parsed.data.username.trim().toLowerCase();
        if (!/^[a-z0-9_]{3,20}$/.test(clean)) return json({ available: false });
        const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
        const { data, error } = await supabaseAdmin.rpc("username_available", { _username: clean });
        if (error) return json({ error: "check_failed" }, 500);
        return json({ available: data === true });
      },
    },
  },
});
