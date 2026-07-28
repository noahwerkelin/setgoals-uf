import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { generateText, tool, stepCountIs } from "ai";
import { z } from "zod";
import { createLovableAiGatewayProvider } from "./ai-gateway.server";
import { findNearbyActivities, type Activity } from "./activities.functions";

const Msg = z.object({
  role: z.enum(["user", "assistant"]),
  content: z.string().min(1).max(4000),
});

const Input = z.object({
  messages: z.array(Msg).min(1).max(40),
  location: z
    .object({ lat: z.number().min(-90).max(90), lng: z.number().min(-180).max(180) })
    .optional(),
});

function todayISO() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function fmtScreenMin(min: number) {
  const h = Math.floor(min / 60);
  const m = min % 60;
  return h ? `${h}h ${m}m` : `${m}m`;
}

export const coachChat = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => Input.parse(d))
  .handler(async ({ data, context }) => {
    const key = process.env.LOVABLE_API_KEY;
    if (!key) throw new Error("AI not configured");
    const { supabase, userId } = context;

    // Profile + settings for context
    const [{ data: profile }, { data: settings }, { data: streak }] = await Promise.all([
      supabase.from("profiles").select("display_name, username").eq("id", userId).maybeSingle(),
      supabase
        .from("user_settings")
        .select("steps_per_30, daily_cap_hours, daily_goal, units")
        .eq("user_id", userId)
        .maybeSingle(),
      supabase.from("streaks").select("count, best, last_goal_met_date").eq("user_id", userId).maybeSingle(),
    ]);

    const gateway = createLovableAiGatewayProvider(key);
    const model = gateway("google/gemini-3-flash-preview");

    const tools = {
      get_screen_time_status: tool({
        description:
          "Get the user's current step count today, the screen time they have earned today, and how much screen time remains under their daily cap. Use whenever the user asks about steps, screen time earned, remaining, or progress.",
        inputSchema: z.object({}),
        execute: async () => {
          const { data: rows } = await supabase
            .from("activity_steps")
            .select("steps, distance_km, calories, exercise_minutes")
            .eq("user_id", userId)
            .eq("day", todayISO());
          const steps = (rows ?? []).reduce((a, r) => a + r.steps, 0);
          const distance_km = (rows ?? []).reduce((a, r) => a + Number(r.distance_km), 0);
          const stepsPer30 = settings?.steps_per_30 ?? 1000;
          const capHours = settings?.daily_cap_hours ?? 3;
          const capMin = capHours * 60;
          const earnedMin = Math.min(capMin, Math.floor(steps / Math.max(1, stepsPer30)) * 30);
          const remainingMin = Math.max(0, capMin - earnedMin);
          const goal = settings?.daily_goal ?? 8000;
          return {
            steps_today: steps,
            daily_goal: goal,
            distance_km: Number(distance_km.toFixed(2)),
            steps_per_30_minutes: stepsPer30,
            earned_screen_time: fmtScreenMin(earnedMin),
            earned_screen_time_minutes: earnedMin,
            remaining_screen_time: fmtScreenMin(remainingMin),
            remaining_screen_time_minutes: remainingMin,
            daily_cap: fmtScreenMin(capMin),
            steps_to_next_30_min:
              earnedMin >= capMin ? 0 : Math.max(0, stepsPer30 - (steps % stepsPer30)),
            current_streak_days: streak?.count ?? 0,
            best_streak_days: streak?.best ?? 0,
          };
        },
      }),
      find_nearby_activities: tool({
        description:
          "Find nearby parks, hiking trails, gyms, swim spots, running paths, and family-friendly outdoor activities around the user's current location. Use when the user asks for places to walk, hike, run, parks nearby, things to do outside, or a suggested route. Filter by kind when relevant.",
        inputSchema: z.object({
          kind: z
            .enum(["Hiking", "Running", "Cycling", "Swim", "Family", "Gym", "Nature", "Any"])
            .default("Any"),
          radius_km: z.number().min(1).max(25).default(8),
          limit: z.number().min(1).max(8).default(5),
        }),
        execute: async ({ kind, radius_km, limit }) => {
          if (!data.location) {
            return {
              error:
                "Location not shared. Ask the user to enable location so nearby places can be suggested, or have them open the Map page.",
            };
          }
          const { activities } = await findNearbyActivities({
            data: {
              lat: data.location.lat,
              lng: data.location.lng,
              radiusM: Math.round(radius_km * 1000),
            },
          });
          let list = activities;
          if (kind !== "Any") list = list.filter((a) => a.kind === kind);
          list = list.slice(0, limit);
          return {
            count: list.length,
            results: list.map((a) => ({
              name: a.name,
              kind: a.kind,
              distance_m: Math.round(a.distanceM),
              rating: a.rating,
              address: a.address,
              open_now: a.openNow,
            })),
          };
        },
      }),
    };

    const displayName = profile?.display_name || profile?.username || "there";
    const system = `You are SetGoals' built-in wellness coach. The user's name is ${displayName}.
You help them earn screen time by being active, suggest nearby places to walk/run/hike, and answer questions about their current step + screen time progress.
Always call the right tool when the user asks about their stats, screen time, or nearby places — never invent numbers or locations. Be concise (2-4 short sentences), warm, and concrete.
Units preference: ${settings?.units ?? "metric"}.`;

    const result = await generateText({
      model,
      system,
      messages: data.messages,
      tools,
      stopWhen: stepCountIs(6),
    });

    const reply = result.text?.trim() || "I'm here — could you ask that another way?";
    return { reply };
  });
