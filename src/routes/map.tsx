import { createFileRoute } from "@tanstack/react-router";
import { Navigation, MapPin, Mountain, Bike, Waves, Trees } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";

export const Route = createFileRoute("/map")({
  head: () => ({
    meta: [
      { title: "Map — SetGoals UF" },
      { name: "description", content: "Find nearby trails, routes, and outdoor activities." },
    ],
  }),
  component: MapPage,
});

const ROUTES = [
  { name: "Änggårdsbergen Loop", dist: "2.4 km", diff: "Moderate", icon: Mountain, kind: "Hiking" },
  { name: "Riverside Run", dist: "5.1 km", diff: "Easy", icon: Navigation, kind: "Running" },
  { name: "Forest Cycle", dist: "12.8 km", diff: "Hard", icon: Bike, kind: "Cycling" },
  { name: "Lake Swim Spot", dist: "0.9 km", diff: "Easy", icon: Waves, kind: "Swim" },
  { name: "Nature Reserve", dist: "3.2 km", diff: "Easy", icon: Trees, kind: "Family" },
];

function MapPage() {
  return (
    <AppShell>
      <PageHeader eyebrow="Discover" title="Nearby activities" />
      <div className="px-6 space-y-5">
        <div
          className="relative aspect-[4/3] overflow-hidden rounded-[28px] ring-1 ring-black/5 animate-rise"
          style={{
            background:
              "radial-gradient(120% 80% at 20% 10%, oklch(0.92 0.018 142) 0%, oklch(0.965 0.008 130) 60%)",
          }}
          role="img"
          aria-label="Map of nearby routes"
        >
          <svg viewBox="0 0 400 300" className="absolute inset-0 size-full">
            <path
              d="M40,240 C90,180 140,260 200,180 S320,80 380,120"
              stroke="oklch(0.58 0.038 142)"
              strokeWidth="3"
              fill="none"
              strokeLinecap="round"
              strokeDasharray="4 6"
            />
            <path
              d="M30,80 C100,90 160,40 230,90 S360,180 390,200"
              stroke="oklch(0.66 0.035 140)"
              strokeWidth="2"
              fill="none"
              strokeLinecap="round"
              opacity="0.6"
            />
            {[
              [80, 220],
              [200, 160],
              [310, 110],
              [140, 80],
              [330, 200],
            ].map(([x, y], i) => (
              <g key={i}>
                <circle cx={x} cy={y} r="10" fill="oklch(0.58 0.038 142 / 0.15)" />
                <circle cx={x} cy={y} r="4" fill="oklch(0.58 0.038 142)" />
              </g>
            ))}
          </svg>
          <div className="absolute bottom-4 left-4 rounded-2xl bg-card/90 px-3 py-2 ring-1 ring-black/5 backdrop-blur">
            <p className="flex items-center gap-1.5 text-xs font-medium text-sage-900">
              <MapPin className="size-3.5 text-sage-600" /> Göteborg, SE
            </p>
          </div>
        </div>

        <div className="flex gap-2 overflow-x-auto pb-1">
          {["All", "Hiking", "Running", "Cycling", "Swim", "Family"].map((c, i) => (
            <button
              key={c}
              className={`shrink-0 rounded-full px-4 py-2 text-xs font-medium ring-1 ring-black/5 ${
                i === 0 ? "bg-sage-600 text-primary-foreground" : "bg-card text-sage-700"
              }`}
            >
              {c}
            </button>
          ))}
        </div>

        <div className="space-y-3">
          {ROUTES.map((r, i) => (
            <article
              key={r.name}
              className="flex items-center gap-4 rounded-3xl bg-card p-4 ring-1 ring-black/5 animate-rise"
              style={{ animationDelay: `${i * 40}ms` }}
            >
              <span className="grid size-12 place-items-center rounded-2xl bg-sage-100 text-sage-700">
                <r.icon className="size-5" />
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold">{r.name}</p>
                <p className="text-xs text-sage-600">
                  {r.kind} · {r.dist} · {r.diff}
                </p>
              </div>
              <button className="rounded-xl bg-sage-100 px-3 py-2 text-xs font-semibold text-sage-700">
                Start
              </button>
            </article>
          ))}
        </div>
      </div>
    </AppShell>
  );
}
