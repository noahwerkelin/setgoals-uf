import { createFileRoute, Link } from "@tanstack/react-router";
import { useState } from "react";
import { useT } from "@/lib/i18n";

export const Route = createFileRoute("/auth")({
  head: () => ({
    meta: [
      { title: "Sign in — SetGoals UF" },
      { name: "description", content: "Sign in or create an account." },
    ],
  }),
  component: Page,
});

function Page() {
  const { t } = useT();
  const [mode, setMode] = useState<"signin" | "signup">("signin");
  return (
    <div className="min-h-dvh bg-background font-sans">
      <div className="mx-auto flex min-h-dvh w-full max-w-md flex-col px-6 pb-10 pt-16">
        <div className="space-y-2 animate-rise">
          <span className="inline-block rounded-full bg-sage-100 px-3 py-1 text-[10px] font-semibold uppercase tracking-widest text-sage-700">
            {t("onb.brand")}
          </span>
          <h1 className="text-3xl font-semibold tracking-tight">
            {mode === "signin" ? t("auth.welcome") : t("auth.create")}
          </h1>
          <p className="text-sm text-sage-600">
            {mode === "signin" ? t("auth.sub_signin") : t("auth.sub_signup")}
          </p>
        </div>

        <form
          className="mt-8 space-y-3 animate-rise"
          style={{ animationDelay: "80ms" }}
          onSubmit={(e) => {
            e.preventDefault();
            window.location.href = "/";
          }}
        >
          <label className="block">
            <span className="sr-only">{t("auth.email")}</span>
            <input
              type="email"
              required
              placeholder={t("auth.email")}
              className="w-full rounded-2xl bg-card px-4 py-3.5 text-sm ring-1 ring-black/5 outline-none placeholder:text-sage-600 focus:ring-sage-600"
            />
          </label>
          <label className="block">
            <span className="sr-only">{t("auth.password")}</span>
            <input
              type="password"
              required
              placeholder={t("auth.password")}
              className="w-full rounded-2xl bg-card px-4 py-3.5 text-sm ring-1 ring-black/5 outline-none placeholder:text-sage-600 focus:ring-sage-600"
            />
          </label>
          <button type="submit" className="w-full rounded-full bg-sage-600 py-3.5 text-sm font-semibold text-primary-foreground">
            {mode === "signin" ? t("auth.signin") : t("auth.create_btn")}
          </button>
        </form>

        <div className="my-6 flex items-center gap-3 text-[11px] font-medium uppercase tracking-widest text-sage-600">
          <span className="h-px flex-1 bg-sage-200" /> {t("auth.or")} <span className="h-px flex-1 bg-sage-200" />
        </div>

        <div className="space-y-2">
          <button className="w-full rounded-full bg-card py-3 text-sm font-semibold text-sage-900 ring-1 ring-black/5">
            {t("auth.google")}
          </button>
          <button className="w-full rounded-full bg-sage-950 py-3 text-sm font-semibold text-sage-50">
            {t("auth.apple")}
          </button>
        </div>

        <button
          onClick={() => setMode(mode === "signin" ? "signup" : "signin")}
          className="mt-8 text-center text-xs font-medium text-sage-600"
        >
          {mode === "signin" ? t("auth.switch_to_signup") : t("auth.switch_to_signin")}
        </button>

        <Link to="/" className="mt-3 text-center text-[11px] text-sage-600">
          {t("auth.guest")}
        </Link>
      </div>
    </div>
  );
}
