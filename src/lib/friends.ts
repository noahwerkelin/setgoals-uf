// Simple local friends list with username-based discovery.
import { useCallback, useEffect, useState } from "react";

export type Friend = {
  id: string;
  username: string;
  name: string;
  steps: number;
};

const KEY = "sg.friends.v2";

const DEFAULT_FRIENDS: Friend[] = [];

const SEED_USERS: Friend[] = [
  { id: "f1", username: "maja_w", name: "Maja", steps: 9120 },
  { id: "f2", username: "erikrun", name: "Erik", steps: 6740 },
  { id: "f3", username: "sofia.s", name: "Sofia", steps: 11_430 },
  { id: "f4", username: "antonh", name: "Anton", steps: 4980 },
  { id: "f5", username: "oli.v", name: "Olivia", steps: 8260 },
];

// Mock pool of discoverable users for username search.
export const DISCOVERABLE_USERS: Friend[] = [
  ...DEFAULT_FRIENDS,
  { id: "u6", username: "noah_p", name: "Noah", steps: 7430 },
  { id: "u7", username: "linnea", name: "Linnea", steps: 10_220 },
  { id: "u8", username: "hugo.b", name: "Hugo", steps: 5810 },
  { id: "u9", username: "alma_k", name: "Alma", steps: 12_900 },
  { id: "u10", username: "wilma", name: "Wilma", steps: 6320 },
  { id: "u11", username: "lucas99", name: "Lucas", steps: 4410 },
  { id: "u12", username: "ebba.r", name: "Ebba", steps: 9580 },
  { id: "u13", username: "elias_t", name: "Elias", steps: 7120 },
  { id: "u14", username: "astrid", name: "Astrid", steps: 13_640 },
  { id: "u15", username: "oskar_l", name: "Oskar", steps: 5290 },
  { id: "u16", username: "saga.m", name: "Saga", steps: 8740 },
  { id: "u17", username: "axel", name: "Axel", steps: 6100 },
  { id: "u18", username: "freja_n", name: "Freja", steps: 11_010 },
  { id: "u19", username: "viktor", name: "Viktor", steps: 4860 },
  { id: "u20", username: "selma.b", name: "Selma", steps: 9430 },
];

function read(): Friend[] {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return DEFAULT_FRIENDS;
    const v = JSON.parse(raw);
    if (Array.isArray(v)) return v as Friend[];
  } catch {}
  return DEFAULT_FRIENDS;
}

function write(list: Friend[]) {
  try { localStorage.setItem(KEY, JSON.stringify(list)); } catch {}
  try { window.dispatchEvent(new CustomEvent("sg:friends-changed")); } catch {}
}

export function useFriends() {
  const [friends, setFriends] = useState<Friend[]>(() => read());

  useEffect(() => {
    const sync = () => setFriends(read());
    window.addEventListener("sg:friends-changed", sync);
    return () => window.removeEventListener("sg:friends-changed", sync);
  }, []);

  const addFriend = useCallback((user: Friend) => {
    const list = read();
    if (list.some((f) => f.username.toLowerCase() === user.username.toLowerCase())) return false;
    const next = [...list, user];
    write(next);
    setFriends(next);
    return true;
  }, []);

  const removeFriend = useCallback((id: string) => {
    const next = read().filter((f) => f.id !== id);
    write(next);
    setFriends(next);
  }, []);

  return { friends, addFriend, removeFriend };
}

export function searchUsers(query: string, excludeUsernames: string[] = []): Friend[] {
  const q = query.trim().toLowerCase();
  if (!q) return [];
  const skip = new Set(excludeUsernames.map((u) => u.toLowerCase()));
  return DISCOVERABLE_USERS.filter(
    (u) => !skip.has(u.username.toLowerCase()) && u.username.toLowerCase().includes(q),
  ).slice(0, 8);
}

/**
 * Deterministic step count for a friend on a given local day.
 * Keeps the friends leaderboard stable within a day and resets it at midnight.
 */
export function friendStepsForDay(f: Friend, dayKey: string): number {
  let h = 2166136261;
  const seed = `${f.id}:${dayKey}`;
  for (let i = 0; i < seed.length; i++) {
    h ^= seed.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  const r = ((h >>> 0) % 1000) / 1000; // 0..1
  const base = f.steps || 6000;
  return Math.round(base * (0.55 + r * 0.9));
}

/** Friends ranked by today's steps, including the current user. */
export function friendsRankToday(
  friends: Friend[],
  myStepsToday: number,
  dayKey: string,
): { rank: number; total: number } {
  const scores = friends.map((f) => friendStepsForDay(f, dayKey));
  const total = scores.length + 1;
  const ahead = scores.filter((s) => s > myStepsToday).length;
  return { rank: ahead + 1, total };
}
