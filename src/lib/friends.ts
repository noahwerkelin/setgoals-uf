// Friends list (stored per device) backed by real accounts and real step data.
import { useCallback, useEffect, useState } from "react";

export type Friend = {
  id: string;
  username: string;
  name: string;
};

const KEY = "sg.friends.v3";

function read(): Friend[] {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return [];
    const v = JSON.parse(raw);
    if (Array.isArray(v)) return (v as Friend[]).filter((f) => f && f.id && f.username);
  } catch {}
  return [];
}

function write(list: Friend[]) {
  try { localStorage.setItem(KEY, JSON.stringify(list)); } catch {}
  try { window.dispatchEvent(new CustomEvent("sg:friends-changed")); } catch {}
}

export function useFriends() {
  const [friends, setFriends] = useState<Friend[]>([]);

  useEffect(() => {
    setFriends(read());
    const sync = () => setFriends(read());
    window.addEventListener("sg:friends-changed", sync);
    return () => window.removeEventListener("sg:friends-changed", sync);
  }, []);

  const addFriend = useCallback((user: Friend) => {
    const list = read();
    if (list.some((f) => f.id === user.id || f.username.toLowerCase() === user.username.toLowerCase())) return false;
    const next = [...list, { id: user.id, username: user.username, name: user.name }];
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

/** Rank among friends using their real step totals for the day. */
export function friendsRankToday(
  stepsByFriend: Record<string, number>,
  myStepsToday: number,
): { rank: number; total: number } {
  const scores = Object.values(stepsByFriend);
  const total = scores.length + 1;
  const ahead = scores.filter((s) => s > myStepsToday).length;
  return { rank: ahead + 1, total };
}
