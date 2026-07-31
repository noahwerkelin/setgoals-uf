// Friends list backed by the database. Each friendship is a symmetric row
// normalized so user_id < friend_id; both users can see and delete the row.
import { useCallback, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { getFriendships, addFriendship, removeFriendship } from "@/lib/friends.functions";

export type Friend = {
  id: string;
  friend_id: string;
  username: string;
  name: string;
};

const FRIENDS_QUERY_KEY = ["friendships"];

export function useFriends() {
  const getFriends = useServerFn(getFriendships);
  const addFriendshipFn = useServerFn(addFriendship);
  const removeFriendshipFn = useServerFn(removeFriendship);
  const queryClient = useQueryClient();

  const { data: rows = [], isLoading } = useQuery({
    queryKey: FRIENDS_QUERY_KEY,
    queryFn: () => getFriends({ data: undefined }),
  });

  const addMut = useMutation({
    mutationFn: async (user: { id: string; username: string; name?: string }) => {
      const res = await addFriendshipFn({ data: { friend_id: user.id } });
      if ("error" in res) throw new Error(res.error);
      return user;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: FRIENDS_QUERY_KEY }),
  });

  const removeMut = useMutation({
    mutationFn: async (friendshipId: string) => {
      const res = await removeFriendshipFn({ data: { friendship_id: friendshipId } });
      if ("error" in res) throw new Error(res.error);
      return friendshipId;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: FRIENDS_QUERY_KEY }),
  });

  const addFriend = useCallback(
    (user: { id: string; username: string }) => {
      if (rows.some((f) => f.id === user.id || f.username.toLowerCase() === user.username.toLowerCase())) {
        return false;
      }
      addMut.mutate({ id: user.id, username: user.username, name: "" });
      return true;
    },
    [rows, addMut],
  );

  const removeFriend = useCallback(
    (friendshipId: string) => {
      removeMut.mutate(friendshipId);
    },
    [removeMut],
  );

  return {
    friends: rows,
    isLoading,
    addFriend,
    removeFriend,
  };
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

