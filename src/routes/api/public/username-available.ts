import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";
import { normalizeUsername, validUsername } from "@/lib/username";

/**
 * Username availability for the iOS app during sign-up (no session yet).
 * Returns only a boolean; the underlying DB function stays service-role only.
 */
const Input = z.object({ username: z.string().min(1).max(40), childId: z.string().uuid().optional() });

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
        const clean = normalizeUsername(parsed.data.username);
        if (!validUsername(clean)) return json({ available: false });
        const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
        if (parsed.data.childId) {
          const token = request.headers.get("authorization")?.match(/^Bearer (.+)$/i)?.[1];
          if (!token) return json({ error: "unauthorized" }, 401);
          const { data: auth, error: authError } = await supabaseAdmin.auth.getUser(token);
          if (authError || !auth.user) return json({ error: "unauthorized" }, 401);
          const { data: child, error: childError } = await supabaseAdmin.from("children")
            .select("username,auth_user_id").eq("id", parsed.data.childId).eq("parent_id", auth.user.id).maybeSingle();
          if (childError) return json({ error: "check_failed" }, 500);
          if (!child) return json({ error: "forbidden" }, 403);
          if (child.username && normalizeUsername(child.username) === clean) return json({ available: true });
          if (child.auth_user_id) {
            const { data: profile, error: profileError } = await supabaseAdmin.from("profiles")
              .select("username").eq("id", child.auth_user_id).maybeSingle();
            if (profileError) return json({ error: "check_failed" }, 500);
            if (profile && normalizeUsername(profile.username) === clean) return json({ available: true });
          }
        }
        const { data, error } = await supabaseAdmin.rpc("username_available", { _username: clean });
        if (error) return json({ error: "check_failed" }, 500);
        return json({ available: data === true });
      },
    },
  },
});
