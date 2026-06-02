import { Link, useRouterState } from "@tanstack/react-router";
import { Home, Map, Trophy, Sparkles, User } from "lucide-react";

const items = [
  { to: "/", label: "Home", icon: Home },
  { to: "/map", label: "Map", icon: Map },
  { to: "/challenges", label: "Goals", icon: Trophy },
  { to: "/coach", label: "Coach", icon: Sparkles },
  { to: "/profile", label: "Profile", icon: User },
] as const;

export function BottomNav() {
  const { location } = useRouterState();
  const path = location.pathname;
  return (
    <nav
      className="fixed bottom-5 left-1/2 z-50 flex w-[calc(100%-32px)] max-w-[360px] -translate-x-1/2 items-center justify-around rounded-3xl bg-card/85 p-1.5 ring-1 ring-black/5 backdrop-blur-xl"
      style={{ boxShadow: "0 10px 30px -10px rgb(0 0 0 / 0.15)" }}
    >
      {items.map(({ to, label, icon: Icon }) => {
        const active = to === "/" ? path === "/" : path.startsWith(to);
        return (
          <Link
            key={to}
            to={to}
            aria-label={label}
            className={`flex min-h-11 min-w-11 flex-col items-center justify-center rounded-2xl px-3 py-2 transition-colors ${
              active ? "text-sage-700" : "text-sage-950/40 hover:text-sage-700"
            }`}
          >
            <Icon className="size-5" strokeWidth={active ? 2.4 : 1.8} />
          </Link>
        );
      })}
    </nav>
  );
}
