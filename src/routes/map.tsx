import { createFileRoute } from "@tanstack/react-router";
import * as React from "react";
import { lazy, Suspense, useEffect, useMemo, useState } from "react";
import { useServerFn } from "@tanstack/react-start";
import { useQuery } from "@tanstack/react-query";
import {
  Navigation,
  MapPin,
  Mountain,
  Bike,
  Waves,
  Trees,
  LocateFixed,
  Dumbbell,
  Users,
  Footprints,
  RefreshCw,
  Star,
  ChevronDown,
} from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { useT } from "@/lib/i18n";
import { useSettings, kmToDisplay } from "@/lib/settings";
import { toast } from "sonner";
import { findNearbyActivities, type Activity, type ActivityKind } from "@/lib/activities.functions";

// Inline SVG paths (mirror src/components/ActivityMap.tsx ICON_PATHS) so list
// icons visually match the markers on the map.
const PIN_ICON_PATHS: Record<string, string> = {
  Mountain:
    "M8 3 L12 11 L17 6 L21 20 L3 20 Z",
};
const KIND_TO_PIN: Record<ActivityKind | "All", string> = {
  All: "Mountain",
  Hiking: "Mountain",
  Running: "Running",
  Cycling: "Cycling",
  Swim: "Swim",
  Family: "Family",
  Gym: "Gym",
  Nature: "Mountain",
};

function SagePin({ kind, size = 44 }: { kind: ActivityKind; size?: number }) {
  const iconKey = KIND_TO_PIN[kind] ?? "Mountain";
  const inner: Record<string, React.ReactElement> = {
    Mountain: (
      <path d="m8 3 4 8 5-5 4 14H3z" fill="none" stroke="white" strokeWidth={2} strokeLinejoin="round" />
    ),
    Running: (
      <>
        <circle cx={13} cy={4} r={2} fill="white" />
        <path d="m4 22 5-7 4 2 3-4 4 5" fill="none" stroke="white" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
      </>
    ),
    Cycling: (
      <>
        <circle cx={5.5} cy={17.5} r={3.5} fill="none" stroke="white" strokeWidth={2} />
        <circle cx={18.5} cy={17.5} r={3.5} fill="none" stroke="white" strokeWidth={2} />
        <path d="M12 17.5 8 9h5l4 8" fill="none" stroke="white" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
        <circle cx={15} cy={5} r={1.5} fill="white" />
      </>
    ),
    Swim: (
      <>
        <path d="M2 18c1.5-1 3-1 4.5 0s3 1 4.5 0 3-1 4.5 0 3 1 4.5 0" fill="none" stroke="white" strokeWidth={2} strokeLinecap="round" />
        <path d="M2 13c1.5-1 3-1 4.5 0s3 1 4.5 0 3-1 4.5 0 3 1 4.5 0" fill="none" stroke="white" strokeWidth={2} strokeLinecap="round" />
        <circle cx={17} cy={6} r={2} fill="white" />
      </>
    ),
    Family: (
      <path d="M12 2 4 8v12h6v-6h4v6h6V8z" fill="none" stroke="white" strokeWidth={2} strokeLinejoin="round" />
    ),
    Gym: (
      <path d="M6 6v12M3 9v6M18 6v12M21 9v6M6 12h12" fill="none" stroke="white" strokeWidth={2} strokeLinecap="round" />
    ),
  };
  const inner_size = Math.round(size * 0.5);
  void PIN_ICON_PATHS;
  void iconKey;
  return (
    <span
      style={{ width: size, height: size + size * 0.18 }}
      className="relative inline-block shrink-0 drop-shadow-[0_4px_6px_rgba(0,0,0,0.18)]"
      aria-hidden
    >
      <svg width={size} height={size + size * 0.18} viewBox="0 0 40 48" xmlns="http://www.w3.org/2000/svg">
        <path
          d="M20 47 C20 47 4 30 4 18 A16 16 0 1 1 36 18 C36 30 20 47 20 47 Z"
          fill="oklch(0.58 0.038 142)"
          stroke="white"
          strokeWidth={2.5}
        />
      </svg>
      <span
        className="absolute grid place-items-center"
        style={{ top: size * 0.2, left: (size - inner_size) / 2, width: inner_size, height: inner_size }}
      >
        <svg width={inner_size} height={inner_size} viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          {inner[KIND_TO_PIN[kind] ?? "Mountain"] ?? inner.Mountain}
        </svg>
      </span>
    </span>
  );
}

const ActivityMap = lazy(() =>
  import("@/components/ActivityMap").then((m) => ({ default: m.ActivityMap })),
);

export const Route = createFileRoute("/map")({
  head: () => ({
    meta: [
      { title: "Map — SetGoals UF" },
      { name: "description", content: "Discover verified nearby trails, parks, and outdoor activities." },
    ],
  }),
  component: MapPage,
});

const ICONS: Record<ActivityKind, typeof Navigation> = {
  Hiking: Mountain,
  Running: Footprints,
  Cycling: Bike,
  Swim: Waves,
  Family: Users,
  Gym: Dumbbell,
  Nature: Trees,
};

const FILTERS: Array<"All" | ActivityKind> = [
  "All",
  "Hiking",
  "Running",
  "Cycling",
  "Swim",
  "Gym",
  "Nature",
  "Family",
];

function MapPage() {
  const { t } = useT();
  const { settings } = useSettings();
  const [center, setCenter] = useState<[number, number] | null>(null);
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>("All");
  const [locating, setLocating] = useState(false);
  const [denied, setDenied] = useState(false);

  const find = useServerFn(findNearbyActivities);

  const requestLocation = () => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      setDenied(true);
      toast.error(t("map.location_denied"));
      return;
    }
    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setCenter([pos.coords.latitude, pos.coords.longitude]);
        setDenied(false);
        setLocating(false);
      },
      () => {
        setDenied(true);
        setLocating(false);
        toast.error(t("map.location_denied"));
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 },
    );
  };

  useEffect(() => {
    requestLocation();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const query = useQuery({
    queryKey: ["nearby", center?.[0].toFixed(3), center?.[1].toFixed(3)],
    queryFn: () =>
      find({ data: { lat: center![0], lng: center![1], radiusM: 8000 } }),
    enabled: !!center,
    staleTime: 5 * 60 * 1000,
  });

  const activities: Activity[] = query.data?.activities ?? [];
  const visible = useMemo(
    () => (filter === "All" ? activities : activities.filter((a) => a.kind === filter)),
    [activities, filter],
  );

  const points = useMemo(
    () =>
      visible.map((a) => {
        const d = kmToDisplay(a.distanceM / 1000, settings.units);
        return {
          id: a.id,
          name: a.name,
          kind: a.kind,
          lat: a.lat,
          lng: a.lng,
          dist: `${d.value.toFixed(d.value < 10 ? 1 : 0)} ${d.unit}`,
          diff: t(`map.source.${a.source}`),
        };
      }),
    [visible, settings.units, t],
  );

  const openDirections = (a: Activity) => {
    const url = `https://www.google.com/maps/dir/?api=1&destination=${a.lat},${a.lng}&destination_place_id=${a.source === "google_maps" ? a.sourceId : ""}`;
    window.open(url, "_blank", "noopener,noreferrer");
  };

  return (
    <AppShell>
      <PageHeader
        eyebrow={t("map.eyebrow")}
        title={t("map.title")}
        trailing={
          <div className="flex gap-2">
            <button
              onClick={() => query.refetch()}
              aria-label={t("map.refresh")}
              className="grid size-10 place-items-center rounded-full bg-card ring-1 ring-black/5 text-sage-700"
            >
              <RefreshCw className={`size-4 ${query.isFetching ? "animate-spin" : ""}`} />
            </button>
            <button
              onClick={requestLocation}
              aria-label={t("map.use_location")}
              className="grid size-10 place-items-center rounded-full bg-card ring-1 ring-black/5 text-sage-700"
            >
              <LocateFixed className={`size-4 ${locating ? "animate-pulse" : ""}`} />
            </button>
          </div>
        }
      />
      <div className="px-6 space-y-5">
        <div className="relative animate-rise">
          {center ? (
            <Suspense fallback={<div className="aspect-[4/3] w-full rounded-[28px] bg-sage-100 animate-pulse" />}>
              <ActivityMap
                center={center}
                points={points}
                youHereLabel={t("map.you_here")}
                onSelect={(p) => {
                  const a = activities.find((x) => x.id === p.id);
                  if (a) toast(a.name, { description: `${t(`map.kind.${a.kind}`)} · ${t(`map.source.${a.source}`)}` });
                }}
              />
            </Suspense>
          ) : (
            <div className="aspect-[4/3] w-full rounded-[28px] bg-sage-100 grid place-items-center text-sage-700 text-sm">
              {denied ? t("map.location_denied") : t("map.locating")}
            </div>
          )}
          {center && (
            <div className="pointer-events-none absolute bottom-4 left-4 rounded-2xl bg-card/90 px-3 py-2 ring-1 ring-black/5 backdrop-blur">
              <p className="flex items-center gap-1.5 text-xs font-medium text-sage-900">
                <MapPin className="size-3.5 text-sage-600" /> {center[0].toFixed(3)}, {center[1].toFixed(3)}
              </p>
            </div>
          )}
        </div>

        <div className="flex gap-2 overflow-x-auto pb-1">
          {FILTERS.map((c) => (
            <button
              key={c}
              onClick={() => setFilter(c)}
              className={`shrink-0 rounded-full px-4 py-2 text-xs font-medium ring-1 ring-black/5 transition-colors ${
                filter === c ? "bg-sage-600 text-primary-foreground" : "bg-card text-sage-700"
              }`}
            >
              {t(`map.kind.${c}`)}
            </button>
          ))}
        </div>

        {query.isLoading && center && (
          <p className="text-center text-sm text-sage-600 py-6">{t("map.loading")}</p>
        )}

        {!query.isLoading && center && visible.length === 0 && (
          <p className="text-center text-sm text-sage-600 py-6">{t("map.none")}</p>
        )}

        <div className="space-y-3">
          {visible.map((a, i) => {
            const Icon = ICONS[a.kind] ?? Navigation;
            const d = kmToDisplay(a.distanceM / 1000, settings.units);
            return (
              <article
                key={a.id}
                className="flex items-center gap-4 rounded-3xl bg-card p-4 ring-1 ring-black/5 animate-rise"
                style={{ animationDelay: `${Math.min(i, 8) * 40}ms` }}
              >
                {a.photoUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={a.photoUrl}
                    alt={a.name}
                    loading="lazy"
                    className="size-12 rounded-2xl object-cover ring-1 ring-black/5"
                  />
                ) : (
                  <span className="grid size-12 place-items-center rounded-2xl bg-sage-100 text-sage-700">
                    <Icon className="size-5" />
                  </span>
                )}
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold">{a.name}</p>
                  <p className="truncate text-xs text-sage-600">
                    {t(`map.kind.${a.kind}`)} · {d.value.toFixed(d.value < 10 ? 1 : 0)} {d.unit}
                    {typeof a.rating === "number" && (
                      <>
                        {" · "}
                        <Star className="inline size-3 -mt-0.5 fill-sage-600 text-sage-600" />{" "}
                        {a.rating.toFixed(1)}
                        {a.userRatingsTotal ? ` (${a.userRatingsTotal})` : ""}
                      </>
                    )}
                  </p>
                  <p className="truncate text-[10px] uppercase tracking-wide text-sage-500 mt-0.5">
                    {t(`map.source.${a.source}`)}
                    {a.openNow === true && ` · ${t("map.open_now")}`}
                    {a.openNow === false && ` · ${t("map.closed")}`}
                  </p>
                </div>
                <button
                  onClick={() => openDirections(a)}
                  className="rounded-xl bg-sage-100 px-3 py-2 text-xs font-semibold text-sage-700 hover:bg-sage-200"
                >
                  {t("map.start")}
                </button>
              </article>
            );
          })}
        </div>
      </div>
    </AppShell>
  );
}
