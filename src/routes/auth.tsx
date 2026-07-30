import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { toast } from "sonner";
import { ArrowLeft } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { lovable } from "@/integrations/lovable";
import { useAuth } from "@/lib/auth";
import { useT } from "@/lib/i18n";
import { redeemChildCode } from "@/lib/children.functions";
import { isUsernameAvailable } from "@/lib/username.functions";

export const Route = createFileRoute("/auth")({
  head: () => ({
    meta: [
      { title: "Sign in — SetGoals" },
      { name: "description", content: "Sign in or create your SetGoals account." },
    ],
  }),
  component: Page,
});

type Mode = "signin" | "signup" | "forgot" | "join";

function Page() {
  const navigate = useNavigate();
  const { user, loading } = useAuth();
  const { t } = useT();
  const [mode, setMode] = useState<Mode>("signin");

  useEffect(() => {
    if (!loading && user) navigate({ to: "/" });
  }, [loading, user, navigate]);

  return (
    <div className="min-h-dvh bg-background font-sans">
      <div className="mx-auto flex min-h-dvh w-full max-w-md flex-col px-6 pb-10 pt-10">
        {mode !== "signin" && (
          <button
            onClick={() => setMode("signin")}
            className="mb-4 inline-flex w-fit items-center gap-1.5 rounded-full bg-card px-3 py-1.5 text-xs font-medium text-sage-700 ring-1 ring-black/5"
          >
            <ArrowLeft className="h-3.5 w-3.5" /> {t("auth.back")}
          </button>
        )}
        <div className="space-y-2">
          <span className="inline-block rounded-full bg-sage-100 px-3 py-1 text-[10px] font-semibold uppercase tracking-widest text-sage-700">
            SetGoals
          </span>
          <h1 className="text-3xl font-semibold tracking-tight">
            {mode === "signin"
              ? t("auth.welcome")
              : mode === "signup"
                ? t("auth.create")
                : mode === "join"
                  ? t("auth.join_title")
                  : t("auth.forgot_title")}
          </h1>
          <p className="text-sm text-sage-600">
            {mode === "signin"
              ? t("auth.sub_signin")
              : mode === "signup"
                ? t("auth.sub_signup")
                : mode === "join"
                  ? t("auth.join_sub")
                  : t("auth.forgot_sub")}
          </p>
        </div>

        <div className="mt-8">
          {mode === "signin" && (
            <SignIn
              onForgot={() => setMode("forgot")}
              onSignup={() => setMode("signup")}
              onJoin={() => setMode("join")}
            />
          )}
          {mode === "signup" && <SignUp onSignin={() => setMode("signin")} />}
          {mode === "forgot" && <Forgot onDone={() => setMode("signin")} />}
          {mode === "join" && <JoinWithCode />}
        </div>
      </div>
    </div>
  );
}


function Field(props: React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      {...props}
      className={`w-full rounded-2xl bg-card px-4 py-3.5 text-sm ring-1 ring-black/5 outline-none focus:ring-sage-400 ${props.className ?? ""}`}
    />
  );
}

async function withGoogle() {
  const r = await lovable.auth.signInWithOAuth("google", { redirect_uri: window.location.origin });
  if (r.error) toast.error(r.error.message);
}
async function withApple() {
  const r = await lovable.auth.signInWithOAuth("apple", { redirect_uri: window.location.origin });
  if (r.error) toast.error(r.error.message);
}

function SocialButtons() {
  const { t } = useT();
  return (
    <>
      <div className="my-6 flex items-center gap-3 text-[11px] font-medium uppercase tracking-widest text-sage-600">
        <span className="h-px flex-1 bg-sage-200" /> {t("auth.or")} <span className="h-px flex-1 bg-sage-200" />
      </div>
      <button type="button" onClick={withGoogle} className="mb-2 w-full rounded-full bg-card py-3 text-sm font-semibold text-sage-900 ring-1 ring-black/5">
        {t("auth.google")}
      </button>
      <button type="button" onClick={withApple} className="w-full rounded-full bg-sage-950 py-3 text-sm font-semibold text-sage-50">
        {t("auth.apple")}
      </button>
    </>
  );
}

function SignIn({ onForgot, onSignup, onJoin }: { onForgot: () => void; onSignup: () => void; onJoin: () => void }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const { t } = useT();

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setBusy(false);
    if (error) toast.error(error.message);
  };

  return (
    <form className="space-y-3" onSubmit={submit}>
      <Field type="email" placeholder={t("auth.email")} value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="email" />
      <Field type="password" placeholder={t("auth.password")} value={password} onChange={(e) => setPassword(e.target.value)} required autoComplete="current-password" />
      <div className="flex justify-end">
        <button type="button" onClick={onForgot} className="text-xs font-medium text-sage-700 hover:underline">
          {t("auth.forgot")}
        </button>
      </div>
      <button disabled={busy} type="submit" className="mt-2 w-full rounded-full bg-sage-600 py-3.5 text-sm font-semibold text-primary-foreground disabled:opacity-50">
        {busy ? t("auth.signing_in") : t("auth.signin")}
      </button>
      <SocialButtons />
      <button
        type="button"
        onClick={onJoin}
        className="mt-2 w-full rounded-full bg-sage-100 py-3 text-sm font-semibold text-sage-800 ring-1 ring-sage-200"
      >
        {t("auth.join_code")}
      </button>
      <p className="mt-6 text-center text-xs text-sage-600">
        {t("auth.no_account")}{" "}
        <button type="button" onClick={onSignup} className="font-semibold text-sage-800 hover:underline">
          {t("auth.create_one")}
        </button>
      </p>
    </form>
  );
}

function SignUp({ onSignin }: { onSignin: () => void }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [username, setUsername] = useState("");
  const [birthday, setBirthday] = useState("");
  const [busy, setBusy] = useState(false);
  const { t } = useT();

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (password.length < 8) return toast.error(t("auth.password_short"));
    const uname = username.trim().toLowerCase();
    if (!/^[a-z0-9_]{3,20}$/.test(uname)) {
      return toast.error(t("auth.username_invalid"));
    }
    setBusy(true);
    try {
      const free = await isUsernameAvailable({ data: { username: uname } });
      if (!free) {
        setBusy(false);
        return toast.error(t("auth.username_taken"));
      }
    } catch {
      setBusy(false);
      return toast.error(t("auth.username_check_failed"));
    }
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/`,
        data: { display_name: displayName, username: uname, birthday: birthday || null },
      },
    });
    setBusy(false);
    if (error) return toast.error(error.message);
    toast.success(t("auth.confirm_email"));
    onSignin();
  };

  return (
    <form className="space-y-3" onSubmit={submit}>
      <Field placeholder={t("auth.display_name")} value={displayName} onChange={(e) => setDisplayName(e.target.value)} required />
      <Field
        placeholder={t("auth.username_ph")}
        value={username}
        onChange={(e) => setUsername(e.target.value.replace(/[^a-zA-Z0-9_]/g, "").toLowerCase())}
        required
        minLength={3}
        maxLength={20}
        autoComplete="username"
      />
      <Field type="email" placeholder={t("auth.email")} value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="email" />
      <Field type="password" placeholder={t("auth.password_min")} value={password} onChange={(e) => setPassword(e.target.value)} required autoComplete="new-password" minLength={8} />
      <label className="block">
        <span className="mb-1.5 ml-1 block text-[11px] font-medium uppercase tracking-wider text-sage-600">{t("auth.birthday")}</span>
        <Field type="date" value={birthday} onChange={(e) => setBirthday(e.target.value)} />
      </label>
      <button disabled={busy} type="submit" className="mt-2 w-full rounded-full bg-sage-600 py-3.5 text-sm font-semibold text-primary-foreground disabled:opacity-50">
        {busy ? t("auth.creating") : t("auth.create_btn")}
      </button>
      <SocialButtons />
    </form>
  );
}

function Forgot({ onDone }: { onDone: () => void }) {
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const { t } = useT();
  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    });
    setBusy(false);
    if (error) return toast.error(error.message);
    toast.success(t("auth.reset_sent"));
    onDone();
  };
  return (
    <form className="space-y-3" onSubmit={submit}>
      <Field type="email" placeholder={t("auth.email")} value={email} onChange={(e) => setEmail(e.target.value)} required />
      <button disabled={busy} type="submit" className="mt-2 w-full rounded-full bg-sage-600 py-3.5 text-sm font-semibold text-primary-foreground disabled:opacity-50">
        {busy ? t("auth.sending") : t("auth.send_reset")}
      </button>
    </form>
  );
}

function JoinWithCode() {
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const { t } = useT();

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    const clean = code.toUpperCase().replace(/[^A-Z0-9]/g, "");
    if (clean.length !== 8) return toast.error(t("auth.code_len_error"));
    setBusy(true);
    try {
      const creds = await redeemChildCode({ data: { code: clean } });
      const { error } = await supabase.auth.signInWithPassword(creds);
      if (error) throw error;
      toast.success(t("auth.join_ok"));
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t("auth.code_failed"));
    } finally {
      setBusy(false);
    }
  };

  return (
    <form className="space-y-3" onSubmit={submit}>
      <Field
        placeholder="A7K9-PQ42"
        value={code}
        onChange={(e) => {
          const raw = e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 8);
          setCode(raw.length > 4 ? `${raw.slice(0, 4)}-${raw.slice(4)}` : raw);
        }}
        required
        autoCapitalize="characters"
        className="text-center text-lg font-semibold tracking-[0.3em]"
      />
      <button disabled={busy} type="submit" className="mt-2 w-full rounded-full bg-sage-600 py-3.5 text-sm font-semibold text-primary-foreground disabled:opacity-50">
        {busy ? t("auth.joining") : t("auth.join_cta")}
      </button>
    </form>
  );
}

