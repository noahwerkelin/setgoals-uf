import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { useT } from "@/lib/i18n";

export const Route = createFileRoute("/leaderboards")({
  head: () => ({
    meta: [
      { title: "Leaderboards — SetGoals UF" },
      { name: "description", content: "Compare your steps with friends, local, and national." },
    ],
  }),
  component: Page,
});

type Tab = "Friends" | "Local" | "National";
const TABS: Tab[] = ["Friends", "Local", "National"];
const RANGES = ["Daily", "Weekly", "Monthly"] as const;

const FRIEND_NAMES = ["Maja", "Erik", "Sofia", "Anton", "Olivia", "Noah", "Linnea"];
const LOCAL_NAMES = ["runner_42", "hiker.se", "morning.walk", "trailblazer", "fjord.go", "sunrise.run"];
const NATIONAL_NAMES = ["stepking", "wanderlust", "trailmix", "northern.steps", "pace.master", "ultra.lina"];

// Simple seeded PRNG (mulberry32)
function rng(seed: number) {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let t = seed;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function dayOfYear(d = new Date()) {
  const start = Date.UTC(d.getUTCFullYear(), 0, 0);
  return Math.floor((d.getTime() - start) / 86400000);
}

function buildRows(tab: Tab, range: (typeof RANGES)[number]) {
  const names =
    tab === "Friends" ? FRIEND_NAMES : tab === "Local" ? LOCAL_NAMES : NATIONAL_NAMES;
  const base = tab === "Friends" ? 6000 : tab === "Local" ? 9000 : 15000;
  const spread = tab === "Friends" ? 8000 : tab === "Local" ? 14000 : 22000;
  const multiplier = range === "Daily" ? 1 : range === "Weekly" ? 6.4 : 27;
  const day = dayOfYear();
  const seed = day * 1000 + (tab === "Friends" ? 1 : tab === "Local" ? 2 : 3) + (range === "Daily" ? 10 : range === "Weekly" ? 20 : 30);
  const r = rng(seed);
  const youSteps = Math.round((4500 + r() * 7000) * multiplier);
  const rows = names.map((n) => ({
    n,
    s: Math.round((base + r() * spread) * multiplier),
  }));
  rows.push({ n: "__you__", s: youSteps });
  rows.sort((a, b) => b.s - a.s);
  return rows.slice(0, 6);
}

function Page() {
  const { t, lang } = useT();
  const [tab, setTab] = useState<Tab>("Friends");
  const [range, setRange] = useState<(typeof RANGES)[number]>("Daily");

  const rows = useMemo(() => buildRows(tab, range), [tab, range]);

  const dateLabel = useMemo(
    () =>
      new Date().toLocaleDateString(lang === "sv" ? "sv-SE" : undefined, {
        weekday: "short",
        month: "short",
        day: "numeric",
      }),
    [lang],
  );

  return (
    <AppShell>
      <PageHeader eyebrow={t("lb.eyebrow", { range: t(`lb.range.${range}`) })} title={t("lb.title")} />
      <div className="px-6 space-y-5">
        <div className="grid grid-cols-3 gap-1 rounded-2xl bg-card p-1 ring-1 ring-black/5">
          {TABS.map((tk) => (
            <button
              key={tk}
              onClick={() => setTab(tk)}
              className={`rounded-xl py-2 text-xs font-semibold transition-colors ${
                tab === tk ? "bg-sage-600 text-primary-foreground" : "text-sage-700"
              }`}
            >
              {t(`lb.tab.${tk}`)}
            </button>
          ))}
        </div>

        <div className="flex items-center justify-between gap-2">
          <div className="flex gap-2">
            {RANGES.map((r) => (
              <button
                key={r}
                onClick={() => setRange(r)}
                className={`rounded-full px-3 py-1.5 text-xs font-medium ring-1 ring-black/5 ${
                  range === r ? "bg-sage-600 text-primary-foreground" : "bg-card text-sage-700"
                }`}
              >
                {t(`lb.range.${r}`)}
              </button>
            ))}
          </div>
          {range === "Daily" && (
            <span className="text-[10px] font-medium uppercase tracking-wider text-sage-600">
              {t("lb.today_label", { date: dateLabel })}
            </span>
          )}
        </div>

        <ol className="space-y-2">
          {rows.map((row, i) => (
            <li
              key={row.n + i}
              className={`flex items-center gap-4 rounded-2xl p-4 ring-1 animate-rise ${
                row.n === "__you__" ? "bg-sage-600 text-primary-foreground ring-sage-700/40" : "bg-card ring-black/5"
              }`}
              style={{ animationDelay: `${i * 40}ms` }}
            >
              <span className={`grid size-8 place-items-center rounded-full text-xs font-semibold tabular-nums ${row.n === "__you__" ? "bg-white/15 text-white" : "bg-sage-100 text-sage-700"}`}>
                {i + 1}
              </span>
              <span className="flex-1 text-sm font-medium">{row.n === "__you__" ? t("lb.you") : row.n}</span>
              <span className="text-sm font-semibold tabular-nums">{row.s.toLocaleString()}</span>
            </li>
          ))}
        </ol>

        <p className="px-1 text-center text-xs text-sage-600">{t("lb.refresh")} · {t("lb.anon")}</p>
      </div>
    </AppShell>
  );
}
