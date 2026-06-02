import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { AppShell, PageHeader } from "@/components/AppShell";

export const Route = createFileRoute("/leaderboards")({
  head: () => ({
    meta: [
      { title: "Leaderboards — SetGoals UF" },
      { name: "description", content: "Compare your steps with friends, local, and national." },
    ],
  }),
  component: Page,
});

const DATA = {
  Friends: [
    { n: "Maja", s: 12420 },
    { n: "Erik", s: 10980 },
    { n: "Sofia", s: 9540 },
    { n: "You", s: 7240, you: true },
    { n: "Anton", s: 6120 },
  ],
  Local: [
    { n: "runner_42", s: 18900 },
    { n: "hiker.se", s: 16320 },
    { n: "morning.walk", s: 14010 },
    { n: "You", s: 7240, you: true },
  ],
  National: [
    { n: "stepking", s: 32100 },
    { n: "wanderlust", s: 28400 },
    { n: "trailmix", s: 26110 },
    { n: "You", s: 7240, you: true },
  ],
};

type Tab = keyof typeof DATA;
const TABS: Tab[] = ["Friends", "Local", "National"];
const RANGES = ["Daily", "Weekly", "Monthly"] as const;

function Page() {
  const [tab, setTab] = useState<Tab>("Friends");
  const [range, setRange] = useState<(typeof RANGES)[number]>("Daily");

  return (
    <AppShell>
      <PageHeader eyebrow={range + " rankings"} title="Leaderboards" />
      <div className="px-6 space-y-5">
        <div className="grid grid-cols-3 gap-1 rounded-2xl bg-card p-1 ring-1 ring-black/5">
          {TABS.map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`rounded-xl py-2 text-xs font-semibold transition-colors ${
                tab === t ? "bg-sage-600 text-primary-foreground" : "text-sage-700"
              }`}
            >
              {t}
            </button>
          ))}
        </div>

        <div className="flex gap-2">
          {RANGES.map((r) => (
            <button
              key={r}
              onClick={() => setRange(r)}
              className={`rounded-full px-3 py-1.5 text-xs font-medium ring-1 ring-black/5 ${
                range === r ? "bg-sage-600 text-primary-foreground" : "bg-card text-sage-700"
              }`}
            >
              {r}
            </button>
          ))}
        </div>

        <ol className="space-y-2">
          {DATA[tab].map((row, i) => (
            <li
              key={row.n + i}
              className={`flex items-center gap-4 rounded-2xl p-4 ring-1 animate-rise ${
                row.you ? "bg-sage-600 text-primary-foreground ring-sage-700/40" : "bg-card ring-black/5"
              }`}
              style={{ animationDelay: `${i * 40}ms` }}
            >
              <span className={`grid size-8 place-items-center rounded-full text-xs font-semibold tabular-nums ${row.you ? "bg-white/15 text-white" : "bg-sage-100 text-sage-700"}`}>
                {i + 1}
              </span>
              <span className="flex-1 text-sm font-medium">{row.n}</span>
              <span className="text-sm font-semibold tabular-nums">{row.s.toLocaleString()}</span>
            </li>
          ))}
        </ol>

        <p className="px-1 text-center text-xs text-sage-600">
          Anonymous mode is available in settings.
        </p>
      </div>
    </AppShell>
  );
}
