import { createFileRoute, Link } from "@tanstack/react-router";
import { ChevronRight, Flame, Footprints, MapPin, Trophy, Zap } from "lucide-react";
import { AppShell } from "@/components/AppShell";
import { ProgressRing } from "@/components/ProgressRing";
import { useT } from "@/lib/i18n";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "SetGoals UF — Today" },
      { name: "description", content: "Your daily steps, earned screen time, and goals." },
    ],
  }),
  component: Home,
});

const STEPS = 7240;
const GOAL = 10000;
const EARNED_MIN = 210;
const REMAINING_MIN = 72;

function formatMin(min: number) {
  const h = Math.floor(min / 60);
  const m = min % 60;
  return h ? `${h}h ${m}m` : `${m}m`;
}

function Home() {
  const { t, lang } = useT();
  const ringProgress = Math.min(1, STEPS / GOAL);
  const date = new Date().toLocaleDateString(lang === "sv" ? "sv-SE" : undefined, {
    weekday: "long",
    month: "short",
    day: "numeric",
  });

  return (
    <AppShell>
      <header className="flex items-end justify-between px-6 pb-4 pt-10 animate-rise">
        <div className="space-y-1">
          <p className="text-sm font-medium text-sage-600">{date}</p>
          <h1 className="text-2xl font-semibold tracking-tight">{t("home.morning")}, Lukas</h1>
        </div>
        <Link to="/profile" aria-label="Profile" className="size-10 rounded-full bg-sage-200 ring-1 ring-black/5 grid place-items-center text-[10px] font-semibold uppercase tracking-widest text-sage-700">
          LU
        </Link>
      </header>

      <div className="px-6 space-y-6">
        <section
          className="relative flex flex-col items-center gap-6 rounded-[28px] bg-card p-8 ring-1 ring-black/5 animate-rise"
          style={{ animationDelay: "60ms" }}
        >
          <ProgressRing progress={ringProgress} size={224}>
            <div className="text-center space-y-1">
              <span className="block text-4xl font-semibold leading-none tabular-nums">
                {STEPS.toLocaleString()}
              </span>
              <span className="block text-sm font-medium text-sage-600">
                {t("home.steps_of", { goal: GOAL.toLocaleString() })}
              </span>
            </div>
          </ProgressRing>

          <div className="grid w-full grid-cols-2 divide-x divide-sage-950/5 text-center">
            <div className="space-y-1">
              <p className="text-[10px] font-medium uppercase tracking-wider text-sage-600">{t("home.earned")}</p>
              <p className="text-lg font-medium tabular-nums">{formatMin(EARNED_MIN)}</p>
            </div>
            <div className="space-y-1">
              <p className="text-[10px] font-medium uppercase tracking-wider text-sage-600">{t("home.remaining")}</p>
              <p className="text-lg font-medium tabular-nums text-sage-600">{formatMin(REMAINING_MIN)}</p>
            </div>
          </div>
        </section>

        <section className="grid grid-cols-2 gap-4 animate-rise" style={{ animationDelay: "120ms" }}>
          <StatTile icon={<Flame className="size-4" />} label={t("home.energy")} value="342" unit="kcal" />
          <StatTile icon={<Footprints className="size-4" />} label={t("home.distance")} value="5.2" unit="km" />
        </section>

        <Quote />

        <section className="space-y-3 animate-rise" style={{ animationDelay: "240ms" }}>
          <SectionTitle>{t("home.achievements")}</SectionTitle>
          <div className="grid grid-cols-3 gap-3">
            <Badge icon={<Trophy className="size-5" />} label={t("home.badge.streak")} />
            <Badge icon={<Footprints className="size-5" />} label={t("home.badge.first5k")} />
            <Badge icon={<MapPin className="size-5" />} label={t("home.badge.explorer")} />
          </div>
        </section>

        <FamilyCard />

        <Link
          to="/leaderboards"
          className="flex items-center justify-between rounded-3xl bg-card p-5 ring-1 ring-black/5 animate-rise"
          style={{ animationDelay: "300ms" }}
        >
          <div className="flex items-center gap-3">
            <span className="grid size-9 place-items-center rounded-xl bg-sage-100 text-sage-700">
              <Zap className="size-4" />
            </span>
            <div>
              <p className="text-sm font-semibold">{t("home.leaderboards")}</p>
              <p className="text-xs text-sage-600">{t("home.lb_sub")}</p>
            </div>
          </div>
          <ChevronRight className="size-4 text-sage-600" />
        </Link>
      </div>
    </AppShell>
  );
}

function SectionTitle({ children }: { children: React.ReactNode }) {
  return <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{children}</h2>;
}

function StatTile({
  icon,
  label,
  value,
  unit,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  unit: string;
}) {
  return (
    <div className="space-y-3 rounded-3xl bg-card p-5 ring-1 ring-black/5">
      <div className="flex items-center gap-2">
        <span className="grid size-7 place-items-center rounded-lg bg-sage-100 text-sage-700">{icon}</span>
        <span className="text-xs font-medium text-sage-600">{label}</span>
      </div>
      <p className="text-xl font-medium tabular-nums">
        {value} <span className="text-xs text-sage-600/60">{unit}</span>
      </p>
    </div>
  );
}

function Badge({ icon, label }: { icon: React.ReactNode; label: string }) {
  return (
    <div className="flex flex-col items-center gap-2 rounded-2xl bg-card p-4 ring-1 ring-black/5">
      <span className="grid size-10 place-items-center rounded-full bg-sage-100 text-sage-700">{icon}</span>
      <span className="text-center text-[11px] font-medium leading-tight text-sage-900">{label}</span>
    </div>
  );
}

function Quote() {
  const { t } = useT();
  return (
    <section
      className="rounded-3xl bg-sage-600 p-6 text-primary-foreground ring-1 ring-sage-700/40 animate-rise"
      style={{ animationDelay: "210ms" }}
    >
      <p className="text-[10px] font-medium uppercase tracking-widest text-white/70">{t("home.quote_eyebrow")}</p>
      <p className="mt-2 text-pretty text-[17px] font-medium leading-snug text-white">
        "{t("home.quote.text")}"
      </p>
      <p className="mt-2 text-xs text-white/80">— Jim Rohn</p>
    </section>
  );
}

function FamilyCard() {
  const { t } = useT();
  const rows = [
    { name: "Maja", steps: 8420 },
    { name: "Lukas", steps: 7240 },
    { name: "Dad", steps: 6105 },
  ];
  return (
    <section className="rounded-3xl bg-card p-5 ring-1 ring-black/5 animate-rise" style={{ animationDelay: "270ms" }}>
      <div className="mb-4 flex items-center justify-between">
        <h2 className="text-sm font-semibold">{t("home.family")}</h2>
        <span className="text-[10px] font-medium uppercase tracking-widest text-sage-600">{t("home.today")}</span>
      </div>
      <div className="space-y-4">
        {rows.map((r) => (
          <div key={r.name} className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <span className="size-8 rounded-full bg-sage-100 ring-1 ring-black/5 grid place-items-center text-[10px] font-semibold uppercase text-sage-700">
                {r.name.slice(0, 2)}
              </span>
              <span className="text-sm font-medium">{r.name}</span>
            </div>
            <span className="text-sm font-medium tabular-nums">{r.steps.toLocaleString()}</span>
          </div>
        ))}
      </div>
    </section>
  );
}
