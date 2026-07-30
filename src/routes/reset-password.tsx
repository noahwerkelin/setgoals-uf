import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import { useT } from "@/lib/i18n";

export const Route = createFileRoute("/reset-password")({
  head: () => ({
    meta: [
      { title: "Reset password — SetGoals" },
      { name: "description", content: "Set a new password for your SetGoals account." },
    ],
  }),
  component: Page,
});

function Page() {
  const navigate = useNavigate();
  const [pw, setPw] = useState("");
  const [pw2, setPw2] = useState("");
  const [busy, setBusy] = useState(false);
  const { t } = useT();

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (pw.length < 8) return toast.error(t("auth.password_short"));
    if (pw !== pw2) return toast.error(t("auth.password_mismatch"));
    setBusy(true);
    const { error } = await supabase.auth.updateUser({ password: pw });
    setBusy(false);
    if (error) return toast.error(error.message);
    toast.success(t("account.password_updated"));
    navigate({ to: "/" });
  };

  return (
    <div className="min-h-dvh bg-background font-sans">
      <div className="mx-auto flex min-h-dvh w-full max-w-md flex-col justify-center px-6">
        <h1 className="text-3xl font-semibold tracking-tight">{t("auth.reset_title")}</h1>
        <p className="mt-2 text-sm text-sage-600">{t("auth.reset_enter_confirm")}</p>
        <form className="mt-8 space-y-3" onSubmit={submit}>
          <input
            type="password"
            placeholder={t("auth.new_password")}
            value={pw}
            onChange={(e) => setPw(e.target.value)}
            required
            minLength={8}
            autoComplete="new-password"
            className="w-full rounded-2xl bg-card px-4 py-3.5 text-sm ring-1 ring-black/5 outline-none focus:ring-sage-400"
          />
          <input
            type="password"
            placeholder={t("auth.confirm_password")}
            value={pw2}
            onChange={(e) => setPw2(e.target.value)}
            required
            minLength={8}
            autoComplete="new-password"
            className="w-full rounded-2xl bg-card px-4 py-3.5 text-sm ring-1 ring-black/5 outline-none focus:ring-sage-400"
          />
          <button disabled={busy} type="submit" className="mt-2 w-full rounded-full bg-sage-600 py-3.5 text-sm font-semibold text-primary-foreground disabled:opacity-50">
            {busy ? t("auth.saving") : t("auth.save_password")}
          </button>
        </form>
      </div>
    </div>
  );
}
