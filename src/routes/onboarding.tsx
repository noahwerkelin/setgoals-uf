import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { Check, Footprints, HeartPulse, MapPin, Shield, Sparkles } from "lucide-react";
import { useT } from "@/lib/i18n";
import {
  requestHealthAccess,
  isProviderSupportedOnPlatform,
  type HealthProvider,
} from "@/lib/health-bridge";

export const Route = createFileRoute("/onboarding")({
  head: () => ({
    meta: [
      { title: "Welcome to SetGoals" },
      { name: "description", content: "Earn screen time by walking. Build healthier habits." },
      { property: "og:title", content: "Welcome to SetGoals" },
      { property: "og:description", content: "Earn screen time by walking. Build healthier habits." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Page,
});

const STEPS = [
  { icon: Footprints, key: "s1" },
  { icon: Shield, key: "s2" },
  { icon: Sparkles, key: "s3" },
];

type PermState = "idle" | "busy" | "granted" | "unavailable";

function Page() {
  const { t } = useT();
  const navigate = useNavigate();
  const [screen, setScreen] = useState<"intro" | "perm">("intro");
  const [health, setHealth] = useState<PermState>("idle");
  const [loc, setLoc] = useState<PermState>("idle");

  const provider: HealthProvider =
    typeof navigator !== "undefined" && /Android/.test(navigator.userAgent) ? "googlefit" : "healthkit";

  const askHealth = async () => {
    setHealth("busy");
    const res = await requestHealthAccess(provider);
    if (res.status === "granted") setHealth("granted");
    else if (res.status === "unavailable") setHealth("unavailable");
    else setHealth("idle");
    // Location is the natural next step once health has been answered.
  };

  const askLocation = () => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      setLoc("unavailable");
      return;
    }
    setLoc("busy");
    navigator.geolocation.getCurrentPosition(
      () => setLoc("granted"),
      () => setLoc("idle"),
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 },
    );
  };

  return (
    <div className="min-h-dvh bg-background font-sans">
      <div className="mx-auto flex min-h-dvh w-full max-w-md flex-col justify-between px-6 pb-10 pt-16">
        {screen === "intro" ? (
          <>
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
              <button
                onClick={() => setScreen("perm")}
                className="block w-full rounded-full bg-sage-600 py-4 text-center text-sm font-semibold text-primary-foreground"
              >
                {t("onb.cta")}
              </button>
              <Link to="/" className="block text-center text-xs font-medium text-sage-600">
                {t("onb.skip")}
              </Link>
            </div>
          </>
        ) : (
          <>
            <div className="space-y-8">
              <header className="space-y-3 animate-rise">
                <span className="inline-block rounded-full bg-sage-100 px-3 py-1 text-[10px] font-semibold uppercase tracking-widest text-sage-700">
                  {t("onb.brand")}
                </span>
                <h1 className="text-balance text-3xl font-semibold tracking-tight text-sage-950">
                  {t("onb.perm.title")}
                </h1>
                <p className="text-pretty text-sm text-sage-600">{t("onb.perm.sub")}</p>
              </header>

              <div className="space-y-4">
                <PermCard
                  icon={<HeartPulse className="size-5" />}
                  title={t("onb.perm.health")}
                  desc={t("onb.perm.health_desc")}
                  state={health}
                  note={health === "unavailable" ? t(provider === "healthkit" ? "health.needs_ios_app" : "health.needs_android_app") : null}
                  disabled={!isProviderSupportedOnPlatform(provider) && health === "unavailable"}
                  actionLabel={
                    health === "granted"
                      ? t("onb.perm.allowed")
                      : health === "unavailable"
                        ? t("onb.perm.unavailable")
                        : t("onb.perm.allow")
                  }
                  onAction={askHealth}
                />
                <PermCard
                  icon={<MapPin className="size-5" />}
                  title={t("onb.perm.location")}
                  desc={t("onb.perm.location_desc")}
                  state={loc}
                  note={null}
                  disabled={false}
                  actionLabel={
                    loc === "granted"
                      ? t("onb.perm.allowed")
                      : loc === "unavailable"
                        ? t("onb.perm.unavailable")
                        : t("onb.perm.allow")
                  }
                  onAction={askLocation}
                />
              </div>
            </div>

            <div className="space-y-3 pt-8">
              <button
                onClick={() => navigate({ to: "/auth" })}
                className="block w-full rounded-full bg-sage-600 py-4 text-center text-sm font-semibold text-primary-foreground"
              >
                {t("onb.perm.continue")}
              </button>
              <button
                onClick={() => navigate({ to: "/auth" })}
                className="block w-full text-center text-xs font-medium text-sage-600"
              >
                {t("onb.perm.later")}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function PermCard({
  icon,
  title,
  desc,
  state,
  note,
  disabled,
  actionLabel,
  onAction,
}: {
  icon: React.ReactNode;
  title: string;
  desc: string;
  state: PermState;
  note: string | null;
  disabled: boolean;
  actionLabel: string;
  onAction: () => void;
}) {
  const granted = state === "granted";
  return (
    <div className="rounded-3xl bg-card p-5 ring-1 ring-black/5 animate-rise">
      <div className="flex gap-4">
        <span className="grid size-11 shrink-0 place-items-center rounded-2xl bg-sage-100 text-sage-700">{icon}</span>
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold">{title}</p>
          <p className="text-xs text-sage-600">{desc}</p>
        </div>
        <button
          onClick={onAction}
          disabled={granted || disabled || state === "busy"}
          className={`h-9 shrink-0 self-start rounded-full px-3 text-xs font-semibold transition-colors ${
            granted ? "bg-sage-100 text-sage-700" : "bg-sage-600 text-primary-foreground disabled:opacity-60"
          }`}
        >
          {granted ? (
            <span className="flex items-center gap-1">
              <Check className="size-3.5" /> {actionLabel}
            </span>
          ) : (
            actionLabel
          )}
        </button>
      </div>
      {note && <p className="mt-3 rounded-2xl bg-sage-50 p-3 text-xs text-sage-600">{note}</p>}
    </div>
  );
}
