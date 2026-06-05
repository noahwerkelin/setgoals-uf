// Lightweight geolocation + reverse-geocoding for the leaderboards.
// Uses BigDataCloud's free, no-key, CORS-friendly client endpoint.
import { useEffect, useState } from "react";

export type UserLocation = {
  country: string; // e.g. "Sweden"
  countryCode: string; // e.g. "SE"
  region: string; // principal subdivision, e.g. "Stockholms län"
};

const KEY = "sg.location";
const FALLBACK: UserLocation = {
  country: "Sweden",
  countryCode: "SE",
  region: "Stockholms län",
};

function read(): UserLocation | null {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const p = JSON.parse(raw) as { at: number; loc: UserLocation };
    if (Date.now() - p.at > 1000 * 60 * 60 * 24 * 7) return null;
    return p.loc;
  } catch {
    return null;
  }
}

function write(loc: UserLocation) {
  try {
    localStorage.setItem(KEY, JSON.stringify({ at: Date.now(), loc }));
  } catch {}
}

async function reverseGeocode(lat: number, lng: number): Promise<UserLocation> {
  const url = `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lng}&localityLanguage=en`;
  const res = await fetch(url);
  if (!res.ok) throw new Error("geocode failed");
  const j = await res.json();
  return {
    country: j.countryName || FALLBACK.country,
    countryCode: j.countryCode || FALLBACK.countryCode,
    region: j.principalSubdivision || FALLBACK.region,
  };
}

export function useUserLocation() {
  const [loc, setLoc] = useState<UserLocation | null>(() => read());
  const [loading, setLoading] = useState(!loc);

  useEffect(() => {
    if (loc) return;
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      setLoc(FALLBACK);
      setLoading(false);
      return;
    }
    let cancelled = false;
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          const next = await reverseGeocode(pos.coords.latitude, pos.coords.longitude);
          if (cancelled) return;
          write(next);
          setLoc(next);
        } catch {
          if (!cancelled) setLoc(FALLBACK);
        } finally {
          if (!cancelled) setLoading(false);
        }
      },
      () => {
        if (cancelled) return;
        setLoc(FALLBACK);
        setLoading(false);
      },
      { enableHighAccuracy: false, timeout: 8000, maximumAge: 1000 * 60 * 60 },
    );
    return () => {
      cancelled = true;
    };
  }, [loc]);

  return { location: loc ?? FALLBACK, loading };
}
