import { createFileRoute, Link } from "@tanstack/react-router";
import { useRef, useState } from "react";
import { BarChart3, Camera, ChevronRight, Flame, Gift, Settings, Shield, Trash2 } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { ProfileBadgeStrip } from "@/components/ProfileBadgeStrip";
import { FriendsCard } from "@/components/FriendsCard";
import { useT } from "@/lib/i18n";
import { currentStreak, useSettings, earnedMinFromSteps, formatScreenMin } from "@/lib/settings";
import { useTodaySteps } from "@/lib/steps";

export const Route = createFileRoute("/profile")({
  head: () => ({
    meta: [
      { title: "Profile — SetGoals UF" },
      { name: "description", content: "Your profile, streak, stats, and account." },
    ],
  }),
  component: Page,
});

function Page() {
  const { t } = useT();
  const { settings, update } = useSettings();
  const { data: today } = useTodaySteps();
  const stepsToday = today?.steps ?? 0;
  const isChild = settings.role === "child";
  const displayName = settings.displayName || settings.username || "You";
  const initials = displayName
    .split(" ")
    .map((s) => s[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();

  const streakCount = currentStreak(settings.streak);
  const goalMetToday = (() => {
    const d = new Date();
    const iso = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    return settings.streak.lastGoalMetDate === iso;
  })();

  const fileRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);

  const onPick = async (file: File) => {
    setUploading(true);
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === "string") update("avatar", reader.result);
      setUploading(false);
    };
    reader.onerror = () => setUploading(false);
    reader.readAsDataURL(file);
  };

  const streakLabel =
    streakCount === 0
      ? t("profile.streak.zero")
      : streakCount === 1
        ? t("profile.streak.day")
        : t("profile.streak.days", { n: String(streakCount) });

  return (
    <AppShell>
      <PageHeader title={t("profile.title")} />
      <div className="px-6 space-y-6 pb-8">
        {/* Hero */}
        <section
          className="relative overflow-hidden rounded-[28px] bg-gradient-to-br from-sage-200 via-card to-card p-6 ring-1 ring-black/5 animate-rise"
        >
          <div className="absolute -right-10 -top-10 size-40 rounded-full bg-sage-300/40 blur-2xl" aria-hidden />
          <div className="relative flex flex-col items-center text-center gap-3">
            <button
              type="button"
              onClick={() => fileRef.current?.click()}
              className="group relative grid size-24 place-items-center overflow-hidden rounded-full bg-sage-200 ring-4 ring-card shadow-lg shadow-sage-900/10"
              aria-label={t("profile.change_photo")}
            >
              {settings.avatar ? (
                <img src={settings.avatar} alt={displayName} className="size-full object-cover" />
              ) : (
                <span className="text-xl font-semibold uppercase tracking-widest text-sage-700">
                  {initials}
                </span>
              )}
              <span className="pointer-events-none absolute inset-x-0 bottom-0 flex h-7 items-center justify-center bg-black/45 text-white opacity-0 transition group-hover:opacity-100">
                <Camera className="size-3.5" />
              </span>
              {uploading && (
                <span className="absolute inset-0 grid place-items-center bg-black/30 text-[10px] font-medium text-white">
                  …
                </span>
              )}
            </button>
            <input
              ref={fileRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) onPick(f);
                e.target.value = "";
              }}
            />
            <div>
              <p className="text-lg font-semibold leading-tight">{displayName}</p>
              <p className="mt-0.5 text-xs text-sage-600">@{settings.username}</p>
            </div>
            <div className="flex items-center gap-2 pt-1">
              <button
                type="button"
                onClick={() => fileRef.current?.click()}
                className="rounded-full bg-sage-700 px-3.5 py-1.5 text-[11px] font-semibold text-white shadow-sm"
              >
                {t("profile.change_photo")}
              </button>
              {settings.avatar && (
                <button
                  type="button"
                  onClick={() => update("avatar", null)}
                  className="grid size-8 place-items-center rounded-full bg-sage-100 text-sage-700"
                  aria-label={t("profile.remove_photo")}
                >
                  <Trash2 className="size-3.5" />
                </button>
              )}
            </div>
          </div>
        </section>

        {/* Streak */}
        <section
          className="relative overflow-hidden rounded-3xl bg-card p-5 ring-1 ring-black/5 animate-rise"
          style={{ animationDelay: "60ms" }}
        >
          <div className="flex items-center gap-4">
            <span
              className={`relative grid size-14 place-items-center rounded-2xl ${
                streakCount > 0 ? "bg-orange-100 text-orange-600" : "bg-sage-100 text-sage-600"
              }`}
            >
              <Flame className="size-6" />
            </span>
            <div className="min-w-0 flex-1">
              <p className="text-[10px] font-medium uppercase tracking-wider text-sage-600">
                {t("profile.streak.title")}
              </p>
              <p className="text-2xl font-semibold tabular-nums leading-tight">{streakCount}</p>
              <p className="mt-0.5 text-xs text-sage-600">{streakLabel}</p>
            </div>
            <div className="text-right text-[10px] font-medium uppercase tracking-wider text-sage-600">
              {t("profile.streak.best", { n: String(settings.streak.best) })}
            </div>
          </div>
          <p
            className={`mt-3 rounded-xl px-3 py-2 text-xs ${
              goalMetToday
                ? "bg-sage-100 text-sage-700"
                : streakCount > 0
                  ? "bg-amber-50 text-amber-700"
                  : "bg-sage-50 text-sage-600"
            }`}
          >
            {goalMetToday
              ? t("profile.streak.active")
              : streakCount > 0
                ? t("profile.streak.at_risk")
                : t("profile.streak.zero")}
          </p>
        </section>

        {/* Stats — today */}
        <section className="grid grid-cols-3 gap-3 animate-rise" style={{ animationDelay: "120ms" }}>
          <Mini label={t("profile.mini.steps")} value={stepsToday.toLocaleString()} />
          <Mini label={t("profile.mini.earned")} value={formatScreenMin(earnedMinFromSteps(stepsToday, settings.stepsPer30, settings.dailyCapHours))} />
          <Mini label={t("profile.mini.streak")} value={`${streakCount}d`} />
        </section>

        {/* Badges */}
        <ProfileBadgeStrip />

        {/* Friends */}
        <FriendsCard />


        {/* Nav */}
        <nav className="space-y-2 animate-rise" style={{ animationDelay: "180ms" }}>
          <Row to="/stats" icon={<BarChart3 className="size-4" />} label={t("profile.row.stats")} subtitle={t("profile.row.stats_sub")} />
          <Row to="/rewards" icon={<Gift className="size-4" />} label={t("profile.row.rewards")} subtitle={t("profile.row.rewards_sub")} />
          {!isChild && (
            <Row
              to="/parent"
              icon={<Shield className="size-4" />}
              label={settings.role === "parent" ? t("profile.row.parent") : t("profile.row.screentime")}
              subtitle={settings.role === "parent" ? t("profile.row.parent_sub") : t("profile.row.screentime_sub")}
            />
          )}
          <Row to="/settings" icon={<Settings className="size-4" />} label={t("profile.row.settings")} subtitle={t("profile.row.settings_sub")} />
        </nav>
      </div>
    </AppShell>
  );
}

function Mini({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl bg-card p-3 text-center ring-1 ring-black/5">
      <p className="text-base font-semibold tabular-nums">{value}</p>
      <p className="mt-0.5 text-[10px] font-medium uppercase tracking-wider text-sage-600">{label}</p>
    </div>
  );
}

function Row({ to, icon, label, subtitle }: { to: string; icon: React.ReactNode; label: string; subtitle: string }) {
  return (
    <Link to={to} className="flex items-center gap-4 rounded-2xl bg-card p-4 ring-1 ring-black/5">
      <span className="grid size-9 place-items-center rounded-xl bg-sage-100 text-sage-700">{icon}</span>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold">{label}</p>
        <p className="text-xs text-sage-600">{subtitle}</p>
      </div>
      <ChevronRight className="size-4 text-sage-600" />
    </Link>
  );
}
