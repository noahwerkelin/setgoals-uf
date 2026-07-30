import { createFileRoute, Link } from "@tanstack/react-router";
import { Footprints, Shield, Sparkles } from "lucide-react";
import { useT } from "@/lib/i18n";

export const Route = createFileRoute("/onboarding")({
  head: () => ({
    meta: [
      { title: "Welcome to SetGoals" },
      { name: "description", content: "Earn screen time by walking. Build healthier habits." },
    ],
  }),
  component: Page,
});

const STEPS = [
  { icon: Footprints, key: "s1" },
  { icon: Shield, key: "s2" },
  { icon: Sparkles, key: "s3" },
];

function Page() {
  const { t } = useT();
  return (
    <div className="min-h-dvh bg-background font-sans">
      <div className="mx-auto flex min-h-dvh w-full max-w-md flex-col justify-between px-6 pb-10 pt-16">
        <div className="space-y-10">
          <header className="space-y-3 animate-rise">
            <span className="inline-block rounded-full bg-sage-100 px-3 py-1 text-[10px] font-semibold uppercase tracking-widest text-sage-700">
              {t("onb.brand")}
            </span>
            <h1 className="text-balance text-4xl font-semibold tracking-tight text-sage-950">{t("onb.headline")}</h1>
            <p className="text-pretty text-sage-600">{t("onb.sub")}</p>
          </header>

          <ul className="space-y-4">
            {STEPS.map((s, i) => (
              <li
                key={s.key}
                className="flex gap-4 rounded-3xl bg-card p-5 ring-1 ring-black/5 animate-rise"
                style={{ animationDelay: `${100 + i * 80}ms` }}
              >
                <span className="grid size-11 shrink-0 place-items-center rounded-2xl bg-sage-100 text-sage-700">
                  <s.icon className="size-5" />
                </span>
                <div>
                  <p className="text-sm font-semibold">{t(`onb.${s.key}.title`)}</p>
                  <p className="text-xs text-sage-600">{t(`onb.${s.key}.desc`)}</p>
                </div>
              </li>
            ))}
          </ul>
        </div>

        <div className="space-y-3 pt-8">
          <Link to="/auth" className="block rounded-full bg-sage-600 py-4 text-center text-sm font-semibold text-primary-foreground">
            {t("onb.cta")}
          </Link>
          <Link to="/" className="block text-center text-xs font-medium text-sage-600">
            {t("onb.skip")}
          </Link>
        </div>
      </div>
    </div>
  );
}
