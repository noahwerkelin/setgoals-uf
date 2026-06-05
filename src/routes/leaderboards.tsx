import { createFileRoute, redirect } from "@tanstack/react-router";

export const Route = createFileRoute("/leaderboards")({
  beforeLoad: () => {
    throw redirect({ to: "/challenges", search: { tab: "lb" } });
  },
  component: () => null,
});
