// Simple local friends list. Persisted in localStorage.
import { useEffect, useState } from "react";

export type Friend = { id: string; name: string; steps: number };

const KEY = "sg.friends";
const DEFAULTS: Friend[] = [
  { id: "f1", name: "Maja", steps: 9120 },
  { id: "f2", name: "Erik", steps: 6740 },
  { id: "f3", name: "Sofia", steps: 11_430 },
  { id: "f4", name: "Anton", steps: 4980 },
  { id: "f5", name: "Olivia", steps: 8260 },
];

function read(): Friend[] {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return DEFAULTS;
    const v = JSON.parse(raw);
    if (Array.isArray(v)) return v;
  } catch {}
  return DEFAULTS;
}

export function useFriends() {
  const [friends, setFriends] = useState<Friend[]>(() => read());
  useEffect(() => {
    try { localStorage.setItem(KEY, JSON.stringify(friends)); } catch {}
  }, [friends]);
  return { friends, setFriends };
}
