import { createFileRoute, Link } from "@tanstack/react-router";
import { Footprints, Shield, Sparkles } from "lucide-react";

export const Route = createFileRoute("/onboarding")({
  head: () => ({
    meta: [
      { title: "Welcome to SetGoals UF" },
      { name: "description", content: "Earn screen time by walking. Build healthier habits." },
    ],
  }),
  component: Page,
});

const STEPS = [
  {
    icon: Footprints,
    title: "Walk to earn screen time",
    desc: "Default: 1,000 steps unlocks 30 minutes of your favorite apps.",
  },
  {
    icon: Shield,
    title: "Family-friendly controls",
    desc: "Parents can approve apps, set goals, and grant bonus minutes.",
  },
  {
    icon: Sparkles,
    title: "Coach, routes & rewards",
    desc: "Personal AI coach, nearby trails, badges, and partner offers.",
  },
];

function Page() {
  return (
    <div className="min-h-dvh bg-background font-sans">
      <div className="mx-auto flex min-h-dvh w-full max-w-md flex-col justify-between px-6 pb-10 pt-16">
        <div className="space-y-10">
          <header className="space-y-3 animate-rise">
            <span className="inline-block rounded-full bg-sage-100 px-3 py-1 text-[10px] font-semibold uppercase tracking-widest text-sage-700">
              SetGoals UF
            </span>
            <h1 className="text-balance text-4xl font-semibold tracking-tight text-sage-950">
              Earn screen time by moving.
            </h1>
            <p className="text-pretty text-sage-600">
              A calmer, healthier way to use your phone — for the whole family.
            </p>
          </header>

          <ul className="space-y-4">
            {STEPS.map((s, i) => (
              <li
                key={s.title}
                className="flex gap-4 rounded-3xl bg-card p-5 ring-1 ring-black/5 animate-rise"
                style={{ animationDelay: `${100 + i * 80}ms` }}
              >
                <span className="grid size-11 shrink-0 place-items-center rounded-2xl bg-sage-100 text-sage-700">
                  <s.icon className="size-5" />
                </span>
                <div>
                  <p className="text-sm font-semibold">{s.title}</p>
                  <p className="text-xs text-sage-600">{s.desc}</p>
                </div>
              </li>
            ))}
          </ul>
        </div>

        <div className="space-y-3 pt-8">
          <Link
            to="/auth"
            className="block rounded-full bg-sage-600 py-4 text-center text-sm font-semibold text-primary-foreground"
          >
            Get started
          </Link>
          <Link to="/" className="block text-center text-xs font-medium text-sage-600">
            Skip — explore the app
          </Link>
        </div>
      </div>
    </div>
  );
}
