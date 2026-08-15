import { createFileRoute } from "@tanstack/react-router";
import { createHmac, timingSafeEqual } from "crypto";
import { z } from "zod";

const Body = z.object({
  user_id: z.string().uuid(),
  day: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  steps: z.number().int().min(0).max(200000),
  distance_km: z.number().min(0).max(1000).optional(),
  calories: z.number().int().min(0).max(20000).optional(),
  exercise_minutes: z.number().int().min(0).max(1440).optional(),
  source: z.enum(["healthkit", "healthconnect", "api"]),
});

export const Route = createFileRoute("/api/public/ingest-steps")({
  server: {
    handlers: {
      POST: async ({ request }) => {
        console.log("🔥 ingest-steps POST HIT");

        const secret = process.env.INGEST_HMAC_SECRET;
        if (!secret) return new Response("Server not configured", { status: 500 });

        const signature = request.headers.get("x-signature") ?? "";
        const raw = await request.text();
        const expected = createHmac("sha256", secret).update(raw).digest("hex");
        const sig = Buffer.from(signature);
        const exp = Buffer.from(expected);
        if (sig.length !== exp.length || !timingSafeEqual(sig, exp)) {
          return new Response("Invalid signature", { status: 401 });
        }

        let parsed;
        try {
          parsed = Body.parse(JSON.parse(raw));
        } catch (e) {
          return new Response("Bad request: " + (e instanceof Error ? e.message : "invalid"), { status: 400 });
        }

        const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
        const { error } = await supabaseAdmin.from("activity_steps").upsert(
          {
            user_id: parsed.user_id,
            day: parsed.day,
            source: parsed.source,
            steps: parsed.steps,
            distance_km: parsed.distance_km ?? 0,
            calories: parsed.calories ?? 0,
            exercise_minutes: parsed.exercise_minutes ?? 0,
          },
          { onConflict: "user_id,day,source" },
        );

        if (error) {
          console.error("ingest-steps upsert", error);
          return new Response("DB error", { status: 500 });
        }

        return Response.json({ ok: true });
      },
    },
  },
});
