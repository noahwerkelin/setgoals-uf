import { createFileRoute } from "@tanstack/react-router";
import { Shield, Check, X, Plus } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";

export const Route = createFileRoute("/parent")({
  head: () => ({
    meta: [
      { title: "Parent dashboard — SetGoals UF" },
      { name: "description", content: "Approve apps, set goals, and view your child's activity." },
    ],
  }),
  component: Page,
});

const KIDS = [
  { name: "Maja", age: 12, steps: 8420, earned: "2h 10m", goal: 10000 },
  { name: "Lukas", age: 15, steps: 7240, earned: "1h 45m", goal: 10000 },
];

const APPS = [
  { name: "YouTube", state: "approved" },
  { name: "TikTok", state: "blocked" },
  { name: "Instagram", state: "approved" },
  { name: "Roblox", state: "approved" },
];

function Page() {
  return (
    <AppShell>
      <PageHeader
        eyebrow="Family controls"
        title="Parent dashboard"
        trailing={
          <span className="grid size-10 place-items-center rounded-full bg-sage-100 text-sage-700">
            <Shield className="size-4" />
          </span>
        }
      />
      <div className="px-6 space-y-6">
        <section className="space-y-3">
          <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">Children</h2>
          {KIDS.map((k, i) => (
            <article
              key={k.name}
              className="rounded-3xl bg-card p-5 ring-1 ring-black/5 animate-rise"
              style={{ animationDelay: `${i * 60}ms` }}
            >
              <div className="flex items-center gap-3">
                <span className="grid size-11 place-items-center rounded-full bg-sage-200 text-xs font-semibold uppercase text-sage-700">
                  {k.name.slice(0, 2)}
                </span>
                <div className="flex-1">
                  <p className="text-sm font-semibold">{k.name}</p>
                  <p className="text-xs text-sage-600">Age {k.age}</p>
                </div>
                <button className="rounded-xl bg-sage-600 px-3 py-1.5 text-xs font-semibold text-primary-foreground">
                  +15 min bonus
                </button>
              </div>
              <div className="mt-4 grid grid-cols-3 gap-3 text-center">
                <Stat label="Steps" value={k.steps.toLocaleString()} />
                <Stat label="Earned" value={k.earned} />
                <Stat label="Goal" value={`${Math.round((k.steps / k.goal) * 100)}%`} />
              </div>
            </article>
          ))}
          <button className="flex w-full items-center justify-center gap-2 rounded-3xl border border-dashed border-sage-300 p-4 text-sm font-medium text-sage-700">
            <Plus className="size-4" /> Add child
          </button>
        </section>

        <section className="space-y-3">
          <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">App approvals</h2>
          <div className="rounded-3xl bg-card ring-1 ring-black/5">
            {APPS.map((a, i) => (
              <div
                key={a.name}
                className={`flex items-center justify-between p-4 ${i > 0 ? "border-t border-sage-100" : ""}`}
              >
                <span className="text-sm font-medium">{a.name}</span>
                <div className="flex gap-1">
                  <button
                    aria-label={`Approve ${a.name}`}
                    className={`grid size-8 place-items-center rounded-full ${a.state === "approved" ? "bg-sage-600 text-white" : "bg-sage-100 text-sage-600"}`}
                  >
                    <Check className="size-4" />
                  </button>
                  <button
                    aria-label={`Block ${a.name}`}
                    className={`grid size-8 place-items-center rounded-full ${a.state === "blocked" ? "bg-destructive text-white" : "bg-sage-100 text-sage-600"}`}
                  >
                    <X className="size-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </section>

        <section className="rounded-3xl bg-card p-5 ring-1 ring-black/5">
          <h3 className="text-sm font-semibold">Custom earning rules</h3>
          <p className="mt-1 text-xs text-sage-600">
            Currently: 1,000 steps = 30 min · Max 3h per day · Unused time does not carry over.
          </p>
          <button className="mt-3 rounded-xl bg-sage-100 px-3 py-2 text-xs font-semibold text-sage-700">
            Configure rules
          </button>
        </section>
      </div>
    </AppShell>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl bg-sage-50 p-3 ring-1 ring-black/5">
      <p className="text-sm font-semibold tabular-nums">{value}</p>
      <p className="text-[10px] font-medium uppercase tracking-wider text-sage-600">{label}</p>
    </div>
  );
}
