import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { NearbyInput, searchNearbyActivities } from "@/lib/activities.server";

export type { Activity, ActivityKind } from "@/lib/activities.server";

export const findNearbyActivities = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => NearbyInput.parse(d))
  .handler(async ({ data }) => searchNearbyActivities(data));
