// Simple local friends list with username-based discovery.
import { useCallback, useEffect, useState } from "react";

export type Friend = {
  id: string;
  username: string;
  name: string;
  steps: number;
};

const KEY = "sg.friends";

const DEFAULT_FRIENDS: Friend[] = [
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
