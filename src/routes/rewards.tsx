import { createFileRoute } from "@tanstack/react-router";
import { Gift, Sparkles, Ticket } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";

export const Route = createFileRoute("/rewards")({
  head: () => ({
    meta: [
      { title: "Rewards — SetGoals UF" },
      { name: "description", content: "Discount vouchers, partner offers, and unlockable avatars." },
    ],
  }),
  component: Page,
});

const REWARDS = [
  { icon: Ticket, name: "10% off Stadium", desc: "Sports gear voucher", cost: "20,000 steps" },
  { icon: Gift, name: "Free coffee · Espresso House", desc: "Partner offer", cost: "8,000 steps" },
  { icon: Sparkles, name: "Forest Explorer avatar", desc: "Unlockable cosmetic", cost: "7-day streak" },
];

function Page() {
  return (
    <AppShell>
      <PageHeader eyebrow="Earn through activity" title="Rewards" />
      <div className="px-6 space-y-5">
        <section className="rounded-3xl bg-sage-600 p-6 text-primary-foreground ring-1 ring-sage-700/40 animate-rise">
          <p className="text-[10px] font-medium uppercase tracking-widest text-sage-100/80">Balance</p>
          <p className="mt-1 text-3xl font-semibold tabular-nums">18,420 steps</p>
          <p className="text-sm text-sage-100/80">Spend on vouchers, offers, and avatars.</p>
        </section>

        <div className="space-y-3">
          {REWARDS.map((r, i) => (
            <article
              key={r.name}
              className="flex items-center gap-4 rounded-3xl bg-card p-4 ring-1 ring-black/5 animate-rise"
              style={{ animationDelay: `${i * 60}ms` }}
            >
              <span className="grid size-12 place-items-center rounded-2xl bg-sage-100 text-sage-700">
                <r.icon className="size-5" />
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold">{r.name}</p>
                <p className="text-xs text-sage-600">{r.desc}</p>
              </div>
              <button className="rounded-xl bg-sage-600 px-3 py-2 text-xs font-semibold text-primary-foreground">
                {r.cost}
              </button>
            </article>
          ))}
        </div>

        <section className="rounded-3xl bg-card p-5 ring-1 ring-black/5">
          <h3 className="text-sm font-semibold">Your avatars</h3>
          <div className="mt-3 grid grid-cols-4 gap-3">
            {["LU", "MA", "FX", "★", "?", "?", "?", "?"].map((a, i) => (
              <div
                key={i}
                className={`grid aspect-square place-items-center rounded-2xl text-sm font-semibold ${
                  i < 4 ? "bg-sage-200 text-sage-700" : "bg-sage-100 text-sage-600/40"
                }`}
              >
                {a}
              </div>
            ))}
          </div>
        </section>
      </div>
    </AppShell>
  );
}
