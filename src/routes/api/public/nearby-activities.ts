import { createFileRoute } from "@tanstack/react-router";
import { createClient } from "@supabase/supabase-js";
import { NearbyInput, searchNearbyActivities } from "@/lib/activities.server";

/**
 * Nearby activities for the native iOS app.
 * Public prefix (no site auth), so the caller is verified here with the
 * user's Supabase access token before any provider call is made.
 */
export const Route = createFileRoute("/api/public/nearby-activities")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        console.log("🔥 nearby-activities POST HIT");

        const token = (request.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
        if (!token) return new Response("Unauthorized", { status: 401 });

        const url = process.env.SUPABASE_URL;
        const key = process.env.SUPABASE_PUBLISHABLE_KEY ?? process.env.SUPABASE_ANON_KEY;
        if (!url || !key) return new Response("Server not configured", { status: 500 });

        const supabase = createClient(url, key, {
          auth: { persistSession: false, autoRefreshToken: false },
        });

        const { data: userData, error } = await supabase.auth.getUser(token);
        if (error || !userData?.user) {
          return new Response("Unauthorized", { status: 401 });
        }

        let input;
        try {
          input = NearbyInput.parse(await request.json());
        } catch (e) {
          return new Response("Bad request: " + (e instanceof Error ? e.message : "invalid"), { status: 400 });
        }

        const result = await searchNearbyActivities(input);

        return new Response(JSON.stringify(result), {
          headers: { "content-type": "application/json" },
        });
      },
    },
  },
});
