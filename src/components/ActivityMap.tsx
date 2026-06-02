import { useEffect, useRef, useState } from "react";
import L from "leaflet";
import { MapContainer, TileLayer, Marker, Popup, useMap } from "react-leaflet";
import iconUrl from "leaflet/dist/images/marker-icon.png";
import iconRetinaUrl from "leaflet/dist/images/marker-icon-2x.png";
import shadowUrl from "leaflet/dist/images/marker-shadow.png";

// Fix default icon paths for bundlers
const DefaultIcon = L.icon({
  iconUrl,
  iconRetinaUrl,
  shadowUrl,
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
});
L.Marker.prototype.options.icon = DefaultIcon;

const sageIcon = L.divIcon({
  className: "sg-marker",
  html: `<span style="display:block;width:14px;height:14px;border-radius:9999px;background:oklch(0.58 0.038 142);box-shadow:0 0 0 6px oklch(0.58 0.038 142 / 0.2),0 0 0 2px white;"></span>`,
  iconSize: [14, 14],
  iconAnchor: [7, 7],
});

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
}: {
  center: [number, number];
  points: RoutePoint[];
  onSelect?: (p: RoutePoint) => void;
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
        <Marker position={center} icon={sageIcon}>
          <Popup>You are here</Popup>
        </Marker>
        {points.map((p) => (
          <Marker
            key={p.id}
            position={[p.lat, p.lng]}
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
