import { createFileRoute } from "@tanstack/react-router";
import { Shield, Check, X, Plus, Lock, Sparkles } from "lucide-react";
import { useState } from "react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { useT } from "@/lib/i18n";
import { useSettings } from "@/lib/settings";
import { ProUpgradeDialog } from "@/components/Pro";
import { toast } from "sonner";

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

type AppState = "approved" | "blocked";
const INITIAL_APPS: { name: string; state: AppState }[] = [
  { name: "YouTube", state: "approved" },
  { name: "TikTok", state: "blocked" },
  { name: "Instagram", state: "approved" },
  { name: "Roblox", state: "approved" },
];

function Page() {
  const { t } = useT();
  const [apps, setApps] = useState(INITIAL_APPS);

  const setState = (name: string, state: AppState) => {
    setApps((a) => a.map((x) => (x.name === name ? { ...x, state } : x)));
    toast.success(`${name}: ${state === "approved" ? "✓" : "✕"}`);
  };

  return (
    <AppShell>
      <PageHeader
        eyebrow={t("parent.eyebrow")}
        title={t("parent.title")}
        trailing={
          <span className="grid size-10 place-items-center rounded-full bg-sage-100 text-sage-700">
            <Shield className="size-4" />
          </span>
        }
      />
      <div className="px-6 space-y-6">
        <section className="space-y-3">
          <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{t("parent.children")}</h2>
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
                  <p className="text-xs text-sage-600">{t("parent.age", { n: k.age })}</p>
                </div>
                <button
                  onClick={() => toast.success(`${k.name}: ${t("parent.bonus")}`)}
                  className="rounded-xl bg-sage-600 px-3 py-1.5 text-xs font-semibold text-primary-foreground"
                >
                  {t("parent.bonus")}
                </button>
              </div>
              <div className="mt-4 grid grid-cols-3 gap-3 text-center">
                <Stat label={t("parent.steps")} value={k.steps.toLocaleString()} />
                <Stat label={t("parent.earned")} value={k.earned} />
                <Stat label={t("parent.goal")} value={`${Math.round((k.steps / k.goal) * 100)}%`} />
              </div>
            </article>
          ))}
          <button
            onClick={() => toast(t("parent.add_child"))}
            className="flex w-full items-center justify-center gap-2 rounded-3xl border border-dashed border-sage-300 p-4 text-sm font-medium text-sage-700"
          >
            <Plus className="size-4" /> {t("parent.add_child")}
          </button>
        </section>

        <section className="space-y-3">
          <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{t("parent.apps")}</h2>
          <div className="rounded-3xl bg-card ring-1 ring-black/5">
            {apps.map((a, i) => (
              <div
                key={a.name}
                className={`flex items-center justify-between p-4 ${i > 0 ? "border-t border-sage-100" : ""}`}
              >
                <span className="text-sm font-medium">{a.name}</span>
                <div className="flex gap-1">
                  <button
                    onClick={() => setState(a.name, "approved")}
                    aria-label={t("parent.approve", { n: a.name })}
                    className={`grid size-8 place-items-center rounded-full ${a.state === "approved" ? "bg-sage-600 text-white" : "bg-sage-100 text-sage-600"}`}
                  >
                    <Check className="size-4" />
                  </button>
                  <button
                    onClick={() => setState(a.name, "blocked")}
                    aria-label={t("parent.block", { n: a.name })}
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
          <h3 className="text-sm font-semibold">{t("parent.rules")}</h3>
          <p className="mt-1 text-xs text-sage-600">{t("parent.rules_sub")}</p>
          <button
            onClick={() => toast(t("parent.configure"))}
            className="mt-3 rounded-xl bg-sage-100 px-3 py-2 text-xs font-semibold text-sage-700"
          >
            {t("parent.configure")}
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
