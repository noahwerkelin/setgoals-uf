import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { ArrowLeft, Check, User, Users, Shield, Baby, Plus, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { useT } from "@/lib/i18n";
import { useSettings, genChildCode, type ChildProfile } from "@/lib/settings";

export const Route = createFileRoute("/auth")({
  head: () => ({
    meta: [
      { title: "Sign in — SetGoals UF" },
      { name: "description", content: "Sign in or create an account." },
    ],
  }),
  component: Page,
});

type Step =
  | "start"
  | "signin"
  | "forgot"
  | "reset"
  | "type"
  | "role"
  | "form-individual"
  | "form-parent"
  | "child-code"
  | "add-children";

const FAMILY_KEY = "sg.familyCodes";

function loadCodes(): string[] {
  try {
    return JSON.parse(localStorage.getItem(FAMILY_KEY) || "[]");
  } catch {
    return [];
  }
}
function saveCode(code: string) {
  const arr = loadCodes();
  if (!arr.includes(code)) {
    arr.push(code);
    localStorage.setItem(FAMILY_KEY, JSON.stringify(arr));
  }
}
function genCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = "";
  for (let i = 0; i < 6; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}

function Page() {
  const { t } = useT();
  const { settings, update } = useSettings();
  const navigate = useNavigate();
  const [step, setStep] = useState<Step>("start");
  const [history, setHistory] = useState<Step[]>([]);
  const [familyCode, setFamilyCode] = useState("");

  const goto = (next: Step) => {
    setHistory((h) => [...h, step]);
    setStep(next);
  };
  const back = () => {
    setHistory((h) => {
      const prev = h[h.length - 1] ?? "start";
      setStep(prev);
      return h.slice(0, -1);
    });
  };

  const enterApp = () => navigate({ to: "/" });

  return (
    <div className="min-h-dvh bg-background font-sans">
      <div className="mx-auto flex min-h-dvh w-full max-w-md flex-col px-6 pb-10 pt-10">
        {step !== "start" && (
          <button
            onClick={back}
            className="mb-4 inline-flex w-fit items-center gap-1.5 rounded-full bg-card px-3 py-1.5 text-xs font-medium text-sage-700 ring-1 ring-black/5"
          >
            <ArrowLeft className="h-3.5 w-3.5" /> {t("auth.back")}
          </button>
        )}

        <div className="space-y-2 animate-rise">
          <span className="inline-block rounded-full bg-sage-100 px-3 py-1 text-[10px] font-semibold uppercase tracking-widest text-sage-700">
            {t("onb.brand")}
          </span>
          <h1 className="text-3xl font-semibold tracking-tight">{titleFor(step, t)}</h1>
          <p className="text-sm text-sage-600">{subFor(step, t)}</p>
        </div>

        <div className="mt-8 animate-rise" style={{ animationDelay: "60ms" }}>
          {step === "start" && (
            <StartView
              onSignin={() => goto("signin")}
              onSignup={() => goto("type")}
              tSignin={t("auth.have_account")}
              tSignup={t("auth.new_account")}
              tGuest={t("auth.guest")}
              onGuest={enterApp}
            />
          )}
          {step === "signin" && (
            <SigninForm
              onDone={() => { update("role", "individual"); enterApp(); }}
              onForgot={() => goto("forgot")}
              t={t}
            />
          )}
          {step === "forgot" && (
            <ForgotForm t={t} onDone={() => goto("reset")} />
          )}
          {step === "reset" && (
            <ResetForm
              t={t}
              onDone={() => {
                toast.success(t("auth.password_updated"));
                setHistory([]);
                setStep("signin");
              }}
            />
          )}
          {step === "type" && (
            <ChoiceList
              items={[
                {
                  icon: <User className="h-5 w-5" />,
                  label: t("auth.individual"),
                  desc: t("auth.individual_desc"),
                  onClick: () => goto("form-individual"),
                },
                {
                  icon: <Users className="h-5 w-5" />,
                  label: t("auth.family"),
                  desc: t("auth.family_desc"),
                  onClick: () => goto("role"),
                },
              ]}
            />
          )}
          {step === "role" && (
            <ChoiceList
              items={[
                {
                  icon: <Shield className="h-5 w-5" />,
                  label: t("auth.parent"),
                  desc: t("auth.parent_desc"),
                  onClick: () => goto("form-parent"),
                },
                {
                  icon: <Baby className="h-5 w-5" />,
                  label: t("auth.child"),
                  desc: t("auth.child_desc"),
                  onClick: () => goto("child-code"),
                },
              ]}
            />
          )}
          {step === "form-individual" && (
            <ProfileForm
              t={t}
              onDone={(name) => {
                update("role", "individual");
                update("displayName", name);
                enterApp();
              }}
            />
          )}
          {step === "form-parent" && (
            <ProfileForm
              t={t}
              onDone={(name) => {
                update("role", "parent");
                update("displayName", name);
                goto("add-children");
              }}
            />
          )}
          {step === "child-code" && (
            <ChildCodeForm
              t={t}
              onDone={(name) => {
                update("role", "child");
                if (name) update("displayName", name);
                // children can't have Pro
                if (settings.isPro) update("isPro", false);
                enterApp();
              }}
            />
          )}
          {step === "add-children" && (
            <AddChildrenView t={t} onDone={enterApp} />
          )}
        </div>
      </div>
    </div>
  );
}

function titleFor(step: Step, t: (k: string) => string) {
  switch (step) {
    case "start": return t("auth.start_title");
    case "signin": return t("auth.welcome");
    case "forgot": return t("auth.forgot_title");
    case "reset": return t("auth.reset_title");
    case "type": return t("auth.choose_type");
    case "role": return t("auth.who_you");
    case "form-individual": return t("auth.individual");
    case "form-parent": return t("auth.parent");
    case "child-code": return t("auth.code_title");
    case "add-children": return t("auth.add_children_title");
  }
}
function subFor(step: Step, t: (k: string) => string) {
  switch (step) {
    case "start": return t("auth.start_sub");
    case "signin": return t("auth.sub_signin");
    case "forgot": return t("auth.forgot_sub");
    case "reset": return t("auth.reset_sub");
    case "type": return t("auth.choose_type_sub");
    case "role": return t("auth.who_you_sub");
    case "form-individual":
    case "form-parent": return t("auth.sub_signup");
    case "child-code": return t("auth.code_sub");
    case "family-code": return t("auth.family_code_label");
  }
}

function StartView({
  onSignin, onSignup, tSignin, tSignup, tGuest, onGuest,
}: { onSignin: () => void; onSignup: () => void; tSignin: string; tSignup: string; tGuest: string; onGuest: () => void; }) {
  return (
    <div className="space-y-3">
      <button onClick={onSignin} className="w-full rounded-2xl bg-sage-600 py-4 text-sm font-semibold text-primary-foreground">
        {tSignin}
      </button>
      <button onClick={onSignup} className="w-full rounded-2xl bg-card py-4 text-sm font-semibold text-sage-900 ring-1 ring-black/5">
        {tSignup}
      </button>
      <button onClick={onGuest} className="mt-4 w-full text-center text-[11px] font-medium text-sage-600">
        {tGuest}
      </button>
    </div>
  );
}

function ChoiceList({ items }: { items: { icon: React.ReactNode; label: string; desc: string; onClick: () => void }[] }) {
  return (
    <div className="space-y-3">
      {items.map((it) => (
        <button
          key={it.label}
          onClick={it.onClick}
          className="flex w-full items-center gap-4 rounded-2xl bg-card p-4 text-left ring-1 ring-black/5 transition-colors hover:bg-sage-50"
        >
          <span className="grid h-11 w-11 place-items-center rounded-xl bg-sage-100 text-sage-700">
            {it.icon}
          </span>
          <span className="flex-1">
            <span className="block text-sm font-semibold text-sage-900">{it.label}</span>
            <span className="block text-xs text-sage-600">{it.desc}</span>
          </span>
        </button>
      ))}
    </div>
  );
}

function SigninForm({ onDone, onForgot, t }: { onDone: () => void; onForgot: () => void; t: (k: string) => string }) {
  return (
    <form
      className="space-y-3"
      onSubmit={(e) => {
        e.preventDefault();
        onDone();
      }}
    >
      <Field type="email" placeholder={t("auth.email")} required />
      <Field type="password" placeholder={t("auth.password")} required />
      <div className="flex justify-end">
        <button type="button" onClick={onForgot} className="text-xs font-medium text-sage-700 hover:underline">
          {t("auth.forgot")}
        </button>
      </div>
      <button type="submit" className="mt-2 w-full rounded-full bg-sage-600 py-3.5 text-sm font-semibold text-primary-foreground">
        {t("auth.signin")}
      </button>
      <div className="my-6 flex items-center gap-3 text-[11px] font-medium uppercase tracking-widest text-sage-600">
        <span className="h-px flex-1 bg-sage-200" /> {t("auth.or")} <span className="h-px flex-1 bg-sage-200" />
      </div>
      <button type="button" onClick={onDone} className="w-full rounded-full bg-card py-3 text-sm font-semibold text-sage-900 ring-1 ring-black/5">
        {t("auth.google")}
      </button>
      <button type="button" onClick={onDone} className="w-full rounded-full bg-sage-950 py-3 text-sm font-semibold text-sage-50">
        {t("auth.apple")}
      </button>
    </form>
  );
}

function ForgotForm({ t, onDone }: { t: (k: string) => string; onDone: () => void }) {
  const [email, setEmail] = useState("");
  return (
    <form
      className="space-y-3"
      onSubmit={(e) => {
        e.preventDefault();
        if (!email) {
          toast.error(t("auth.required"));
          return;
        }
        toast.success(t("auth.reset_sent"));
        onDone();
      }}
    >
      <Field type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder={t("auth.email")} required />
      <button type="submit" className="mt-2 w-full rounded-full bg-sage-600 py-3.5 text-sm font-semibold text-primary-foreground">
        {t("auth.send_reset")}
      </button>
    </form>
  );
}

function ResetForm({ t, onDone }: { t: (k: string) => string; onDone: () => void }) {
  const [pw, setPw] = useState("");
  const [pw2, setPw2] = useState("");
  return (
    <form
      className="space-y-3"
      onSubmit={(e) => {
        e.preventDefault();
        if (pw.length < 8) {
          toast.error(t("auth.password_short"));
          return;
        }
        if (pw !== pw2) {
          toast.error(t("auth.password_mismatch"));
          return;
        }
        onDone();
      }}
    >
      <Field type="password" value={pw} onChange={(e) => setPw(e.target.value)} placeholder={t("auth.new_password")} required />
      <Field type="password" value={pw2} onChange={(e) => setPw2(e.target.value)} placeholder={t("auth.confirm_password")} required />
      <button type="submit" className="mt-2 w-full rounded-full bg-sage-600 py-3.5 text-sm font-semibold text-primary-foreground">
        {t("auth.save")}
      </button>
    </form>
  );
}

function ProfileForm({ t, onDone }: { t: (k: string) => string; onDone: (name: string) => void }) {
  const [tos, setTos] = useState(false);
  const [news, setNews] = useState(true);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [bday, setBday] = useState("");

  const filled = !!(name && email && password && bday);
  const canSubmit = filled && tos;

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!filled) {
      toast.error(t("auth.required"));
      return;
    }
    if (!tos) {
      toast.error(t("auth.must_accept"));
      return;
    }
    onDone(name);
  };

  return (
    <form className="space-y-3" onSubmit={submit}>
      <Field value={name} onChange={(e) => setName(e.target.value)} placeholder={t("auth.name")} required />
      <Field value={email} onChange={(e) => setEmail(e.target.value)} type="email" placeholder={t("auth.email")} required />
      <Field value={password} onChange={(e) => setPassword(e.target.value)} type="password" placeholder={t("auth.password")} required />
      <label className="block">
        <span className="mb-1.5 ml-1 block text-[11px] font-medium uppercase tracking-wider text-sage-600">
          {t("auth.birthday")}
        </span>
        <Field value={bday} onChange={(e) => setBday(e.target.value)} type="date" required />
      </label>

      <CheckRow checked={tos} onChange={setTos} label={t("auth.tos")} required />
      <CheckRow checked={news} onChange={setNews} label={t("auth.newsletter")} />

      <button
        type="submit"
        disabled={!canSubmit}
        className="mt-3 w-full rounded-full bg-sage-600 py-3.5 text-sm font-semibold text-primary-foreground transition-opacity disabled:cursor-not-allowed disabled:opacity-40"
      >
        {t("auth.continue")}
      </button>
    </form>
  );
}

function ChildCodeForm({ t, onDone }: { t: (k: string, vars?: Record<string, string | number>) => string; onDone: (name?: string) => void }) {
  const { settings } = useSettings();
  const [code, setCode] = useState("");
  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    const clean = code.trim().toUpperCase();
    // First look in parent's children list (preferred — assigns name)
    const child = settings.children.find((c) => c.code.toUpperCase() === clean);
    if (child) {
      toast.success(t("auth.code_welcome", { name: child.name }));
      onDone(child.name);
      return;
    }
    // Fallback: any saved family code or demo 6-char code
    const codes = loadCodes();
    const valid = codes.includes(clean) || /^[A-Z0-9]{6}$/.test(clean);
    if (!valid) {
      toast.error(t("auth.code_invalid"));
      return;
    }
    toast.success(t("auth.family_created"));
    onDone();
  };
  return (
    <form className="space-y-3" onSubmit={submit}>
      <Field
        value={code}
        onChange={(e) => setCode(e.target.value.toUpperCase())}
        placeholder={t("auth.code_placeholder")}
        maxLength={6}
        className="text-center text-2xl font-semibold tracking-[0.4em]"
        required
      />
      <button type="submit" className="mt-2 w-full rounded-full bg-sage-600 py-3.5 text-sm font-semibold text-primary-foreground">
        {t("auth.code_join")}
      </button>
    </form>
  );
}

function FamilyCodeView({ code, t, onDone }: { code: string; t: (k: string) => string; onDone: () => void }) {
  const [copied, setCopied] = useState(false);
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(code);
      setCopied(true);
      toast.success(t("auth.copied"));
      setTimeout(() => setCopied(false), 1500);
    } catch {}
  };
  return (
    <div className="space-y-4">
      <div className="rounded-3xl bg-sage-600 px-6 py-8 text-center text-primary-foreground shadow-lg">
        <p className="text-[11px] font-semibold uppercase tracking-widest opacity-80">
          {t("auth.family_code_label")}
        </p>
        <p className="mt-3 text-4xl font-semibold tracking-[0.3em]">{code}</p>
      </div>
      <button
        onClick={copy}
        className="flex w-full items-center justify-center gap-2 rounded-full bg-card py-3 text-sm font-semibold text-sage-900 ring-1 ring-black/5"
      >
        {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
        {copied ? t("auth.copied") : t("auth.copy")}
      </button>
      <button
        onClick={onDone}
        className="w-full rounded-full bg-sage-600 py-3.5 text-sm font-semibold text-primary-foreground"
      >
        {t("auth.enter_app")}
      </button>
    </div>
  );
}

function Field(props: React.InputHTMLAttributes<HTMLInputElement>) {
  const { className = "", ...rest } = props;
  return (
    <input
      {...rest}
      className={`w-full rounded-2xl bg-card px-4 py-3.5 text-sm ring-1 ring-black/5 outline-none placeholder:text-sage-600 focus:ring-sage-600 ${className}`}
    />
  );
}

function CheckRow({ checked, onChange, label, required }: { checked: boolean; onChange: (b: boolean) => void; label: string; required?: boolean }) {
  return (
    <button
      type="button"
      onClick={() => onChange(!checked)}
      className={`flex w-full items-center gap-3 rounded-2xl bg-card px-4 py-3 text-left ring-1 transition-colors ${
        required && !checked ? "ring-sage-300" : "ring-black/5"
      }`}
    >
      <span
        className={`grid h-5 w-5 place-items-center rounded-md ring-1 transition-colors ${
          checked ? "bg-sage-600 ring-sage-600 text-primary-foreground" : "bg-background ring-sage-200"
        }`}
      >
        {checked && <Check className="h-3.5 w-3.5" />}
      </span>
      <span className="text-sm text-sage-900">
        {label}
        {required && <span className="ml-1 text-sage-600">*</span>}
      </span>
    </button>
  );
}
