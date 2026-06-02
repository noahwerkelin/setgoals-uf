import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Gift, Lock, Sparkles, Ticket } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { useT } from "@/lib/i18n";
import { useSettings } from "@/lib/settings";
import { ProUpgradeDialog } from "@/components/Pro";
import { toast } from "sonner";

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
  { key: "r1", icon: Ticket },
  { key: "r2", icon: Gift },
  { key: "r3", icon: Sparkles },
];

function Page() {
  const { t } = useT();
  const { settings } = useSettings();
  const [proOpen, setProOpen] = useState(false);

  // 4 free + 4 PRO-exclusive avatars
  const avatars = [
    { label: "LU", pro: false, owned: true },
    { label: "MA", pro: false, owned: true },
    { label: "FX", pro: false, owned: true },
    { label: "★", pro: false, owned: true },
    { label: "🌲", pro: true, owned: settings.isPro },
    { label: "🏔", pro: true, owned: settings.isPro },
    { label: "🌊", pro: true, owned: settings.isPro },
    { label: "⚡", pro: true, owned: settings.isPro },
  ];

  return (
    <AppShell>
      <PageHeader eyebrow={t("rewards.eyebrow")} title={t("rewards.title")} />
      <div className="px-6 space-y-5">
        <section className="rounded-3xl bg-sage-600 p-6 text-primary-foreground ring-1 ring-sage-700/40 animate-rise">
          <p className="text-[10px] font-medium uppercase tracking-widest text-sage-100/80">{t("rewards.balance")}</p>
          <p className="mt-1 text-3xl font-semibold tabular-nums">18,420 {t("parent.steps").toLowerCase()}</p>
          <p className="text-sm text-sage-100/80">{t("rewards.balance_sub")}</p>
        </section>

        <div className="space-y-3">
          {REWARDS.map((r, i) => (
            <article
              key={r.key}
              className="flex items-center gap-4 rounded-3xl bg-card p-4 ring-1 ring-black/5 animate-rise"
              style={{ animationDelay: `${i * 60}ms` }}
            >
              <span className="grid size-12 place-items-center rounded-2xl bg-sage-100 text-sage-700">
                <r.icon className="size-5" />
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold">{t(`rewards.${r.key}`)}</p>
                <p className="text-xs text-sage-600">{t(`rewards.${r.key}_sub`)}</p>
              </div>
              <button
                onClick={() => toast.success(t(`rewards.${r.key}`))}
                className="rounded-xl bg-sage-600 px-3 py-2 text-xs font-semibold text-primary-foreground"
              >
                {t(`rewards.${r.key}_cost`)}
              </button>
            </article>
          ))}
        </div>

        <section className="rounded-3xl bg-card p-5 ring-1 ring-black/5">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-semibold">{t("rewards.your_avatars")}</h3>
            {!settings.isPro && (
              <button
                onClick={() => setProOpen(true)}
                className="rounded-full bg-sage-100 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-widest text-sage-700"
              >
                {t("pro.badge")} ✦
              </button>
            )}
          </div>
          <div className="mt-3 grid grid-cols-4 gap-3">
            {avatars.map((a, i) => (
              <button
                key={i}
                onClick={() => {
                  if (a.pro && !settings.isPro) setProOpen(true);
                  else toast.success(a.label);
                }}
                className={`relative grid aspect-square place-items-center rounded-2xl text-base font-semibold transition-colors ${
                  a.owned
                    ? a.pro
                      ? "bg-sage-600 text-primary-foreground"
                      : "bg-sage-200 text-sage-700"
                    : "bg-sage-100 text-sage-600/40"
                }`}
                aria-label={a.pro && !settings.isPro ? t("rewards.locked_pro") : a.label}
              >
                {a.owned ? a.label : <Lock className="size-4" />}
                {a.pro && (
                  <span className="absolute right-1 top-1 text-[8px] font-bold tracking-wider opacity-80">
                    PRO
                  </span>
                )}
              </button>
            ))}
          </div>
        </section>
      </div>
      <ProUpgradeDialog open={proOpen} onOpenChange={setProOpen} />
    </AppShell>
  );
}

