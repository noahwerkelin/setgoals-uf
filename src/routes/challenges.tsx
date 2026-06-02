import { createFileRoute } from "@tanstack/react-router";
import { CheckCircle2, Circle, Flame } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { useT } from "@/lib/i18n";
import { toast } from "sonner";

export const Route = createFileRoute("/challenges")({
  head: () => ({
    meta: [
      { title: "Goals & Challenges — SetGoals UF" },
      { name: "description", content: "Daily challenges and step goals to earn more screen time." },
    ],
  }),
  component: Page,
});

const TODAY = [
  { key: "t1", progress: 0.88, done: false },
  { key: "t2", progress: 0, done: false },
  { key: "t3", progress: 1, done: true },
];

const WEEKLY = [
  { key: "w1", progress: 0.6 },
  { key: "w2", progress: 0.66 },
];

function Page() {
  const { t } = useT();
  return (
    <AppShell>
      <PageHeader eyebrow={t("challenges.eyebrow")} title={t("challenges.title")} />
      <div className="px-6 space-y-6">
        <section className="rounded-3xl bg-sage-600 p-6 text-primary-foreground ring-1 ring-sage-700/40 animate-rise">
          <div className="flex items-center gap-2 text-[10px] font-medium uppercase tracking-widest text-sage-100/80">
            <Flame className="size-3.5" /> {t("challenges.streak")}
          </div>
          <p className="mt-1 text-3xl font-semibold tabular-nums">{t("challenges.streak_days", { n: 7 })}</p>
          <p className="text-sm text-sage-100/80">{t("challenges.streak_sub")}</p>
        </section>

        <section className="space-y-3">
          <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{t("challenges.today")}</h2>
          {TODAY.map((c, i) => (
            <ChallengeRow key={c.key} title={t(`challenges.${c.key}`)} progress={c.progress} done={c.done} delay={i * 50} />
          ))}
        </section>

        <section className="space-y-3">
          <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{t("challenges.week")}</h2>
          {WEEKLY.map((c, i) => (
            <ChallengeRow key={c.key} title={t(`challenges.${c.key}`)} progress={c.progress} done={false} delay={150 + i * 50} />
          ))}
        </section>

        <section className="rounded-3xl bg-card p-5 ring-1 ring-black/5">
          <h3 className="text-sm font-semibold">{t("challenges.custom")}</h3>
          <p className="mt-1 text-xs text-sage-600">{t("challenges.custom_desc")}</p>
          <button
            onClick={() => toast(t("challenges.edit_rules"))}
            className="mt-3 rounded-xl bg-sage-100 px-3 py-2 text-xs font-semibold text-sage-700"
          >
            {t("challenges.edit_rules")}
          </button>
        </section>
      </div>
    </AppShell>
  );
}

function ChallengeRow({
  title, progress, done, delay = 0,
}: { title: string; progress: number; done?: boolean; delay?: number }) {
  return (
    <article
      className="flex items-center gap-4 rounded-3xl bg-card p-4 ring-1 ring-black/5 animate-rise"
      style={{ animationDelay: `${delay}ms` }}
    >
      <span className={`grid size-10 place-items-center rounded-full ${done ? "bg-sage-600 text-white" : "bg-sage-100 text-sage-700"}`}>
        {done ? <CheckCircle2 className="size-5" /> : <Circle className="size-5" />}
      </span>
      <div className="min-w-0 flex-1">
        <p className={`text-sm font-medium ${done ? "line-through text-sage-600" : ""}`}>{title}</p>
        <div className="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-sage-100">
          <div className="h-full rounded-full bg-sage-600" style={{ width: `${progress * 100}%` }} />
        </div>
      </div>
      <span className="text-xs font-medium tabular-nums text-sage-600">{Math.round(progress * 100)}%</span>
    </article>
  );
}
