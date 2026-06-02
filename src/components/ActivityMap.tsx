import { useEffect, useRef, useState } from "react";
import L from "leaflet";
import { MapContainer, TileLayer, Marker, Popup, useMap } from "react-leaflet";

// Sage tokens (resolved from CSS where possible)
const SAGE = "oklch(0.58 0.038 142)";
const SAGE_DARK = "oklch(0.42 0.04 142)";

// Lucide-style 24x24 path data for each activity
const ICON_PATHS: Record<string, string> = {
  Hiking:
    '<path d="m12 3 4 8 5 1-3.5 3.5L18 21l-6-3-6 3 .5-5.5L3 12l5-1z" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>', // mountain-ish star fallback
  Mountain:
    '<path d="m8 3 4 8 5-5 4 14H3z" fill="none" stroke="white" stroke-width="2" stroke-linejoin="round"/>',
  Running:
    '<circle cx="13" cy="4" r="2" fill="white"/><path d="m4 22 5-7 4 2 3-4 4 5" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
  Cycling:
    '<circle cx="5.5" cy="17.5" r="3.5" fill="none" stroke="white" stroke-width="2"/><circle cx="18.5" cy="17.5" r="3.5" fill="none" stroke="white" stroke-width="2"/><path d="M12 17.5 8 9h5l4 8" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><circle cx="15" cy="5" r="1.5" fill="white"/>',
  Swim:
    '<path d="M2 18c1.5-1 3-1 4.5 0s3 1 4.5 0 3-1 4.5 0 3 1 4.5 0" fill="none" stroke="white" stroke-width="2" stroke-linecap="round"/><path d="M2 13c1.5-1 3-1 4.5 0s3 1 4.5 0 3-1 4.5 0 3 1 4.5 0" fill="none" stroke="white" stroke-width="2" stroke-linecap="round"/><circle cx="17" cy="6" r="2" fill="white"/>',
  Family:
    '<path d="M12 2 4 8v12h6v-6h4v6h6V8z" fill="none" stroke="white" stroke-width="2" stroke-linejoin="round"/>',
  You:
    '<circle cx="12" cy="12" r="3" fill="white"/>',
};

const KIND_TO_ICON: Record<string, string> = {
  Hiking: "Mountain",
  Running: "Running",
  Cycling: "Cycling",
  Swim: "Swim",
  Family: "Family",
  Gym: "Gym",
  Nature: "Mountain",
};

function makeSageIcon(kind: string, opts?: { you?: boolean }) {
  const iconKey = opts?.you ? "You" : KIND_TO_ICON[kind] ?? "Mountain";
  const path = ICON_PATHS[iconKey];
  const size = 40;
  const html = `
    <div style="position:relative;width:${size}px;height:${size + 8}px;filter:drop-shadow(0 4px 6px rgb(0 0 0 / 0.18));">
      <svg width="${size}" height="${size + 8}" viewBox="0 0 40 48" xmlns="http://www.w3.org/2000/svg">
        <path d="M20 47 C20 47 4 30 4 18 A16 16 0 1 1 36 18 C36 30 20 47 20 47 Z"
              fill="${SAGE}" stroke="white" stroke-width="2.5"/>
      </svg>
      <div style="position:absolute;top:8px;left:8px;width:24px;height:24px;display:grid;place-items:center;">
        <svg width="20" height="20" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">${path}</svg>
      </div>
    </div>`;
  return L.divIcon({
    className: "sg-pin",
    html,
    iconSize: [size, size + 8],
    iconAnchor: [size / 2, size + 6],
    popupAnchor: [0, -size],
  });
}

const youDotIcon = L.divIcon({
  className: "sg-you",
  html: `<span style="display:block;width:16px;height:16px;border-radius:9999px;background:${SAGE};box-shadow:0 0 0 8px ${SAGE.replace(
    ")",
    " / 0.2)",
  )},0 0 0 3px white,0 4px 10px rgb(0 0 0 / 0.2);"></span>`,
  iconSize: [16, 16],
  iconAnchor: [8, 8],
});
void SAGE_DARK;

export type RoutePoint = {
  id: string;
  name: string;
  kind: string;
  lat: number;
  lng: number;
  dist: string;
  diff: string;
};

function Recenter({ center }: { center: [number, number] }) {
  const map = useMap();
  useEffect(() => {
    map.setView(center, map.getZoom(), { animate: true });
  }, [center, map]);
  return null;
}

export function ActivityMap({
  center,
  points,
  onSelect,
  youHereLabel,
}: {
  center: [number, number];
  points: RoutePoint[];
  onSelect?: (p: RoutePoint) => void;
  youHereLabel?: string;
}) {
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  const ref = useRef<L.Map | null>(null);

  if (!mounted) {
    return <div className="aspect-[4/3] w-full rounded-[28px] bg-sage-100 animate-pulse" />;
  }
  return (
    <div className="aspect-[4/3] w-full overflow-hidden rounded-[28px] ring-1 ring-black/5">
      <MapContainer
        center={center}
        zoom={13}
        scrollWheelZoom={false}
        ref={ref as never}
        style={{ height: "100%", width: "100%" }}
      >
        <Recenter center={center} />
        <TileLayer
          attribution='&copy; OpenStreetMap'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <Marker position={center} icon={youDotIcon}>
          <Popup>{youHereLabel ?? "You are here"}</Popup>
        </Marker>
        {points.map((p) => (
          <Marker
            key={p.id}
            position={[p.lat, p.lng]}
            icon={makeSageIcon(p.kind)}
            eventHandlers={{ click: () => onSelect?.(p) }}
          >
            <Popup>
              <strong>{p.name}</strong>
              <br />
              {p.kind} · {p.dist} · {p.diff}
            </Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
}
