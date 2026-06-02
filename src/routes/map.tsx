import { createFileRoute } from "@tanstack/react-router";
import { lazy, Suspense, useEffect, useMemo, useState } from "react";
import { Navigation, MapPin, Mountain, Bike, Waves, Trees, LocateFixed } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { useT } from "@/lib/i18n";
import { useSettings } from "@/lib/settings";
import { toast } from "sonner";

const ActivityMap = lazy(() =>
  import("@/components/ActivityMap").then((m) => ({ default: m.ActivityMap })),
);

export const Route = createFileRoute("/map")({
  head: () => ({
    meta: [
      { title: "Map — SetGoals UF" },
      { name: "description", content: "Find nearby trails, routes, and outdoor activities." },
    ],
  }),
  component: MapPage,
});

const ICONS = { Hiking: Mountain, Running: Navigation, Cycling: Bike, Swim: Waves, Family: Trees };

const BASE_ROUTES = [
  { id: "1", name: "Änggårdsbergen Loop", dist: "2.4 km", diff: "Moderate", kind: "Hiking", offset: [0.012, -0.018] },
  { id: "2", name: "Riverside Run", dist: "5.1 km", diff: "Easy", kind: "Running", offset: [-0.008, 0.022] },
  { id: "3", name: "Forest Cycle", dist: "12.8 km", diff: "Hard", kind: "Cycling", offset: [0.025, 0.03] },
  { id: "4", name: "Lake Swim Spot", dist: "0.9 km", diff: "Easy", kind: "Swim", offset: [-0.018, -0.012] },
  { id: "5", name: "Nature Reserve", dist: "3.2 km", diff: "Easy", kind: "Family", offset: [0.018, 0.008] },
];

const DEFAULT_CENTER: [number, number] = [57.7089, 11.9746]; // Gothenburg

function MapPage() {
  const { t } = useT();
  const { settings } = useSettings();
  const [center, setCenter] = useState<[number, number]>(DEFAULT_CENTER);
  const [filter, setFilter] = useState<string>("All");
  const [locating, setLocating] = useState(false);

  const requestLocation = () => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      toast.error(t("map.location_denied"));
      return;
    }
    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setCenter([pos.coords.latitude, pos.coords.longitude]);
        setLocating(false);
      },
      () => {
        toast.error(t("map.location_denied"));
        setLocating(false);
      },
      { enableHighAccuracy: true, timeout: 8000 },
    );
  };

  useEffect(() => {
    if (settings.shareLocation !== "off") requestLocation();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const points = useMemo(
    () =>
      BASE_ROUTES.filter((r) => filter === "All" || r.kind === filter).map((r) => ({
        id: r.id,
        name: r.name,
        kind: r.kind,
        dist: r.dist,
        diff: r.diff,
        lat: center[0] + r.offset[0],
        lng: center[1] + r.offset[1],
      })),
    [center, filter],
  );

  const filters = ["All", "Hiking", "Running", "Cycling", "Swim", "Family"];

  return (
    <AppShell>
      <PageHeader
        eyebrow={t("map.eyebrow")}
        title={t("map.title")}
        trailing={
          <button
            onClick={requestLocation}
            aria-label={t("map.use_location")}
            className="grid size-10 place-items-center rounded-full bg-card ring-1 ring-black/5 text-sage-700"
          >
            <LocateFixed className={`size-4 ${locating ? "animate-pulse" : ""}`} />
          </button>
        }
      />
      <div className="px-6 space-y-5">
        <div className="relative animate-rise">
          <Suspense fallback={<div className="aspect-[4/3] w-full rounded-[28px] bg-sage-100 animate-pulse" />}>
            <ActivityMap
              center={center}
              points={points}
              onSelect={(p) => toast(p.name, { description: `${p.kind} · ${p.dist} · ${p.diff}` })}
            />
          </Suspense>
          <div className="pointer-events-none absolute bottom-4 left-4 rounded-2xl bg-card/90 px-3 py-2 ring-1 ring-black/5 backdrop-blur">
            <p className="flex items-center gap-1.5 text-xs font-medium text-sage-900">
              <MapPin className="size-3.5 text-sage-600" /> {center[0].toFixed(3)}, {center[1].toFixed(3)}
            </p>
          </div>
        </div>

        <div className="flex gap-2 overflow-x-auto pb-1">
          {filters.map((c) => (
            <button
              key={c}
              onClick={() => setFilter(c)}
              className={`shrink-0 rounded-full px-4 py-2 text-xs font-medium ring-1 ring-black/5 transition-colors ${
                filter === c ? "bg-sage-600 text-primary-foreground" : "bg-card text-sage-700"
              }`}
            >
              {c}
            </button>
          ))}
        </div>

        <div className="space-y-3">
          {points.map((r, i) => {
            const Icon = ICONS[r.kind as keyof typeof ICONS] ?? Navigation;
            return (
              <article
                key={r.id}
                className="flex items-center gap-4 rounded-3xl bg-card p-4 ring-1 ring-black/5 animate-rise"
                style={{ animationDelay: `${i * 40}ms` }}
              >
                <span className="grid size-12 place-items-center rounded-2xl bg-sage-100 text-sage-700">
                  <Icon className="size-5" />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold">{r.name}</p>
                  <p className="text-xs text-sage-600">
                    {r.kind} · {r.dist} · {r.diff}
                  </p>
                </div>
                <button
                  onClick={() => toast.success(`${t("map.start")}: ${r.name}`)}
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
