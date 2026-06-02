import { createFileRoute } from "@tanstack/react-router";
import { ChevronRight } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";

export const Route = createFileRoute("/settings")({
  head: () => ({
    meta: [
      { title: "Settings — SetGoals UF" },
      { name: "description", content: "Notifications, integrations, privacy, and account." },
    ],
  }),
  component: Page,
});

const GROUPS: { title: string; rows: { label: string; meta?: string }[] }[] = [
  {
    title: "Earning rules",
    rows: [
      { label: "Steps per 30 min", meta: "1,000" },
      { label: "Daily screen-time cap", meta: "3h" },
      { label: "Carry over unused time", meta: "Off" },
    ],
  },
  {
    title: "Integrations",
    rows: [
      { label: "Apple HealthKit", meta: "Connected" },
      { label: "Google Fit / Health Connect", meta: "Connect" },
      { label: "Push notifications", meta: "On" },
    ],
  },
  {
    title: "Privacy",
    rows: [
      { label: "Anonymous on leaderboards", meta: "Off" },
      { label: "Share location for routes", meta: "While using" },
    ],
  },
  {
    title: "Account",
    rows: [{ label: "Email" }, { label: "Sign out" }],
  },
];

function Page() {
  return (
    <AppShell>
      <PageHeader title="Settings" />
      <div className="px-6 space-y-6">
        {GROUPS.map((g) => (
          <section key={g.title} className="space-y-2">
            <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{g.title}</h2>
            <div className="rounded-3xl bg-card ring-1 ring-black/5">
              {g.rows.map((r, i) => (
                <button
                  key={r.label}
                  className={`flex w-full items-center justify-between p-4 text-left ${i > 0 ? "border-t border-sage-100" : ""}`}
                >
                  <span className="text-sm font-medium">{r.label}</span>
                  <span className="flex items-center gap-1 text-xs font-medium text-sage-600">
                    {r.meta} <ChevronRight className="size-4" />
                  </span>
                </button>
              ))}
            </div>
          </section>
        ))}
        <p className="pt-4 text-center text-[11px] text-sage-600">SetGoals UF · v1.0.0</p>
      </div>
    </AppShell>
  );
}
