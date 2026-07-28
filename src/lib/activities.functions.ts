import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { z } from "zod";

export type ActivityKind =
  | "Hiking"
  | "Running"
  | "Cycling"
  | "Swim"
  | "Family"
  | "Gym"
  | "Nature";

export type Activity = {
  id: string;
  name: string;
  kind: ActivityKind;
  lat: number;
  lng: number;
  distanceM: number;
  source: "google_maps" | "openstreetmap";
  sourceId: string;
  rating?: number;
  userRatingsTotal?: number;
  photoUrl?: string;
  openNow?: boolean;
  address?: string;
  lengthM?: number;
  difficulty?: string;
};

const Input = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  radiusM: z.number().int().min(500).max(50000).default(8000),
});

function haversine(aLat: number, aLng: number, bLat: number, bLng: number) {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(bLat - aLat);
  const dLng = toRad(bLng - aLng);
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

const GATEWAY = "https://connector-gateway.lovable.dev/google_maps";

// Google Places (New) categories → our ActivityKind
const PLACE_TYPES: { type: string; kind: ActivityKind }[] = [
  { type: "park", kind: "Family" },
  { type: "national_park", kind: "Nature" },
  { type: "hiking_area", kind: "Hiking" },
  { type: "gym", kind: "Gym" },
  { type: "swimming_pool", kind: "Swim" },
  { type: "beach", kind: "Swim" },
  { type: "tourist_attraction", kind: "Family" },
];

async function fetchGooglePlaces(
  lat: number,
  lng: number,
  radiusM: number,
): Promise<Activity[]> {
  const LOVABLE_API_KEY = process.env.LOVABLE_API_KEY;
  const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY;
  if (!LOVABLE_API_KEY || !GOOGLE_MAPS_API_KEY) return [];

  const out: Activity[] = [];
  await Promise.all(
    PLACE_TYPES.map(async ({ type, kind }) => {
      try {
        const res = await fetch(`${GATEWAY}/places/v1/places:searchNearby`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${LOVABLE_API_KEY}`,
            "X-Connection-Api-Key": GOOGLE_MAPS_API_KEY,
            "Content-Type": "application/json",
            "X-Goog-FieldMask":
              "places.id,places.displayName,places.location,places.rating,places.userRatingCount,places.formattedAddress,places.currentOpeningHours.openNow,places.photos.name",
          },
          body: JSON.stringify({
            includedTypes: [type],
            maxResultCount: 15,
            locationRestriction: {
              circle: { center: { latitude: lat, longitude: lng }, radius: Math.min(radiusM, 50000) },
            },
          }),
        });
        if (!res.ok) return;
        const data = (await res.json()) as {
          places?: Array<{
            id: string;
            displayName?: { text?: string };
            location?: { latitude: number; longitude: number };
            rating?: number;
            userRatingCount?: number;
            formattedAddress?: string;
            currentOpeningHours?: { openNow?: boolean };
            photos?: Array<{ name: string }>;
          }>;
        };
        for (const p of data.places ?? []) {
          if (!p.location || !p.displayName?.text) continue;
          const photo = p.photos?.[0]?.name;
          out.push({
            id: `g:${p.id}`,
            sourceId: p.id,
            source: "google_maps",
            name: p.displayName.text,
            kind,
            lat: p.location.latitude,
            lng: p.location.longitude,
            distanceM: haversine(lat, lng, p.location.latitude, p.location.longitude),
            rating: p.rating,
            userRatingsTotal: p.userRatingCount,
            address: p.formattedAddress,
            openNow: p.currentOpeningHours?.openNow,
            photoUrl: photo ? `__resolve__:${photo}` : undefined,
          });
        }
      } catch {
        /* ignore single-type failure */
      }
    }),
  );
  return out;
}

type OsmEl = {
  type: "node" | "way" | "relation";
  id: number;
  lat?: number;
  lon?: number;
  center?: { lat: number; lon: number };
  tags?: Record<string, string>;
};

function classifyOsm(tags: Record<string, string>): ActivityKind | null {
  if (tags.route === "hiking" || tags.sac_scale || tags.highway === "path") return "Hiking";
  if (tags.route === "bicycle" || tags.highway === "cycleway") return "Cycling";
  if (tags.route === "foot" || tags.highway === "footway") return "Running";
  if (tags.leisure === "fitness_station" || tags.leisure === "fitness_centre") return "Gym";
  if (
    tags.natural === "beach" ||
    tags.sport === "swimming" ||
    tags.leisure === "swimming_area" ||
    tags.leisure === "swimming_pool"
  )
    return "Swim";
  if (tags.leisure === "nature_reserve" || tags.boundary === "national_park") return "Nature";
  if (tags.leisure === "park" || tags.leisure === "playground") return "Family";
  return null;
}

async function fetchOverpass(
  lat: number,
  lng: number,
  radiusM: number,
): Promise<Activity[]> {
  const q = `
    [out:json][timeout:25];
    (
      node["leisure"~"park|playground|nature_reserve|fitness_station|fitness_centre|swimming_area"](around:${radiusM},${lat},${lng});
      way["leisure"~"park|nature_reserve|swimming_area"](around:${radiusM},${lat},${lng});
      node["natural"="beach"](around:${radiusM},${lat},${lng});
      way["natural"="beach"](around:${radiusM},${lat},${lng});
      relation["route"~"hiking|bicycle|foot"](around:${radiusM},${lat},${lng});
      way["highway"~"path|cycleway|footway"]["name"](around:${radiusM},${lat},${lng});
      relation["boundary"="national_park"](around:${radiusM},${lat},${lng});
    );
    out tags center 60;
  `;
  try {
    const res = await fetch("https://overpass-api.de/api/interpreter", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: "data=" + encodeURIComponent(q),
    });
    if (!res.ok) return [];
    const data = (await res.json()) as { elements?: OsmEl[] };
    const out: Activity[] = [];
    for (const el of data.elements ?? []) {
      const tags = el.tags ?? {};
      const name = tags.name || tags["name:en"] || tags["name:sv"];
      if (!name) continue;
      const kind = classifyOsm(tags);
      if (!kind) continue;
      const eLat = el.lat ?? el.center?.lat;
      const eLng = el.lon ?? el.center?.lon;
      if (eLat == null || eLng == null) continue;
      out.push({
        id: `o:${el.type}/${el.id}`,
        sourceId: `${el.type}/${el.id}`,
        source: "openstreetmap",
        name,
        kind,
        lat: eLat,
        lng: eLng,
        distanceM: haversine(lat, lng, eLat, eLng),
        difficulty: tags.sac_scale,
      });
    }
    return out;
  } catch {
    return [];
  }
}

export const findNearbyActivities = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => Input.parse(d))
  .handler(async ({ data }) => {
    const [google, osm] = await Promise.all([
      fetchGooglePlaces(data.lat, data.lng, data.radiusM),
      fetchOverpass(data.lat, data.lng, data.radiusM),
    ]);
    const merged = [...google, ...osm];

    // de-dupe by name + ~50m proximity
    const kept: Activity[] = [];
    for (const a of merged.sort((x, y) => x.distanceM - y.distanceM)) {
      const dup = kept.find(
        (k) =>
          k.name.toLowerCase() === a.name.toLowerCase() &&
          haversine(k.lat, k.lng, a.lat, a.lng) < 80,
      );
      if (!dup) kept.push(a);
    }

    // Resolve Google Places photo references to real CDN URLs the browser can load.
    const LOVABLE_API_KEY = process.env.LOVABLE_API_KEY;
    const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY;
    const result = kept.slice(0, 80);
    if (LOVABLE_API_KEY && GOOGLE_MAPS_API_KEY) {
      await Promise.all(
        result.map(async (a) => {
          if (!a.photoUrl?.startsWith("__resolve__:")) return;
          const name = a.photoUrl.slice("__resolve__:".length);
          try {
            const r = await fetch(
              `${GATEWAY}/places/v1/${name}/media?maxWidthPx=640&skipHttpRedirect=true`,
              {
                headers: {
                  Authorization: `Bearer ${LOVABLE_API_KEY}`,
                  "X-Connection-Api-Key": GOOGLE_MAPS_API_KEY,
                },
              },
            );
            if (!r.ok) {
              a.photoUrl = undefined;
              return;
            }
            const j = (await r.json()) as { photoUri?: string };
            a.photoUrl = j.photoUri;
          } catch {
            a.photoUrl = undefined;
          }
        }),
      );
    } else {
      // Strip unresolved markers so the client doesn't try to load them.
      for (const a of result) if (a.photoUrl?.startsWith("__resolve__:")) a.photoUrl = undefined;
    }
    return { activities: result };
  });
