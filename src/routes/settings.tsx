import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { ChevronRight, Check, Smartphone, Activity, Sparkles, MessageSquare } from "lucide-react";
import { useEffect, useState, type ReactNode } from "react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { useT, type Lang } from "@/lib/i18n";
import { useSettings, type SettingsState } from "@/lib/settings";
import { Switch } from "@/components/ui/switch";
import { Slider } from "@/components/ui/slider";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { toast } from "sonner";
import { ProUpgradeDialog } from "@/components/Pro";
import { THEME_COLORS, type ThemeColor } from "@/lib/settings";
import { supabase } from "@/integrations/supabase/client";
import { Lock, Palette } from "lucide-react";
import { awardBadge } from "@/components/Badges";

export const Route = createFileRoute("/settings")({
  head: () => ({
    meta: [
      { title: "Settings — SetGoals UF" },
      { name: "description", content: "Notifications, integrations, privacy, and account." },
    ],
  }),
  component: Page,
});

function Page() {
  const { t, lang, setLang } = useT();
  const { settings, update } = useSettings();
  const navigate = useNavigate();
  const [stepsOpen, setStepsOpen] = useState(false);
  const [capOpen, setCapOpen] = useState(false);
  const [goalOpen, setGoalOpen] = useState(false);
  const [connectKind, setConnectKind] = useState<"hk" | "gf" | null>(null);
  const [proOpen, setProOpen] = useState(false);
  const [nicknameOpen, setNicknameOpen] = useState(false);
  const [usernameOpen, setUsernameOpen] = useState(false);
  const [emailOpen, setEmailOpen] = useState(false);
  const [passwordOpen, setPasswordOpen] = useState(false);
  const [themeOpen, setThemeOpen] = useState(false);

  const isChild = settings.role === "child";

  const deleteAccount = async (password: string): Promise<boolean> => {
    const { data: u } = await supabase.auth.getUser();
    if (!u.user?.email) return false;
    const { error: signInErr } = await supabase.auth.signInWithPassword({
      email: u.user.email,
      password,
    });
    if (signInErr) {
      toast.error(t("delete.wrong_password"));
      return false;
    }
    await supabase.from("account_deletion_requests").insert({ user_id: u.user.id });
    await supabase.from("profiles").delete().eq("id", u.user.id);
    await supabase.auth.signOut();
    toast.success(t("delete.submitted"));
    navigate({ to: "/auth" });
    return true;
  };
  const [reportOpen, setReportOpen] = useState(false);
  const [reportText, setReportText] = useState("");
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deletePassword, setDeletePassword] = useState("");
  const [deleting, setDeleting] = useState(false);

  return (
    <AppShell>
      <PageHeader title={t("settings.title")} />
      <div className="px-6 space-y-6">
        {/* PRO — hidden for children (no in-app purchases) */}
        {!isChild && (
          <button
            onClick={() => setProOpen(true)}
            className={`w-full text-left rounded-3xl p-5 ring-1 transition-colors ${
              settings.isPro
                ? "bg-sage-600 text-primary-foreground ring-sage-700/40"
                : "bg-card ring-black/5 hover:bg-sage-50/60"
            }`}
          >
            <div className="flex items-center gap-3">
              <span className={`grid size-10 place-items-center rounded-2xl ${settings.isPro ? "bg-white/15 text-white" : "bg-sage-100 text-sage-700"}`}>
                <Sparkles className="size-5" />
              </span>
              <div className="flex-1">
                <p className="text-sm font-semibold">{t("pro.title")}</p>
                <p className={`text-xs ${settings.isPro ? "text-white/80" : "text-sage-600"}`}>
                  {settings.isPro ? t("pro.active") : t("pro.subtitle")}
                </p>
              </div>
              <ChevronRight className="size-4" />
            </div>
          </button>
        )}

        {/* Personalization — PRO-gated color theme */}
        {!isChild && (
          <Group title={t("theme.title")}>
            <button
              onClick={() => (settings.isPro ? setThemeOpen(true) : setProOpen(true))}
              className="flex w-full items-center gap-3 rounded-2xl bg-card p-4 ring-1 ring-black/5 text-left"
            >
              <span className="grid size-10 place-items-center rounded-2xl bg-sage-100 text-sage-700">
                <Palette className="size-5" />
              </span>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold capitalize">
                  {t(`theme.${settings.isPro ? settings.themeColor : "sage"}`)}
                </p>
                <p className="text-xs text-sage-600">
                  {settings.isPro ? t("theme.desc") : t("pro.unlock")}
                </p>
              </div>
              <div className="flex items-center gap-1">
                {THEME_COLORS.slice(0, 5).map((c) => (
                  <span key={c.id} className="size-3.5 rounded-full ring-1 ring-black/10" style={{ background: c.swatch }} />
                ))}
              </div>
              {settings.isPro ? <ChevronRight className="size-4" /> : <Lock className="size-4 text-sage-600" />}
            </button>
          </Group>
        )}


        {/* Earning rules — only parents/individuals can change */}
        {!isChild && (
          <Group title={t("settings.earning")}>
            <Row
              label={t("settings.daily_goal")}
              meta={`${settings.dailyGoal.toLocaleString()} ${t("settings.steps")}`}
              onClick={() => setGoalOpen(true)}
            />
            <Row
              label={t("settings.steps_per_30")}
              meta={settings.stepsPer30.toLocaleString()}
              onClick={() => setStepsOpen(true)}
            />
            <Row
              label={t("settings.daily_cap")}
              meta={settings.dailyCapHours >= 24 ? t("parent.no_cap") : `${settings.dailyCapHours}${t("settings.hours")}`}
              onClick={() => setCapOpen(true)}
            />
          </Group>
        )}

        {/* Integrations */}
        <Group title={t("settings.integrations")}>
          <IntegrationRow
            icon={<Smartphone className="size-4" />}
            label={t("settings.healthkit")}
            connected={settings.healthkitConnected}
            onAction={() =>
              settings.healthkitConnected
                ? (update("healthkitConnected", false), toast(t("settings.disconnect") + " ✓"))
                : setConnectKind("hk")
            }
            t={t}
          />
          <IntegrationRow
            icon={<Activity className="size-4" />}
            label={t("settings.googlefit")}
            connected={settings.googlefitConnected}
            onAction={() =>
              settings.googlefitConnected
                ? (update("googlefitConnected", false), toast(t("settings.disconnect") + " ✓"))
                : setConnectKind("gf")
            }
            t={t}
          />
          <ToggleRow
            label={t("settings.push")}
            checked={settings.pushOn}
            onChange={(v) => update("pushOn", v)}
          />
        </Group>

        {/* Privacy */}
        <Group title={t("settings.privacy")}>
          <ToggleRow
            label={t("settings.anon_lb")}
            checked={settings.anonymousLeaderboard}
            onChange={(v) => update("anonymousLeaderboard", v)}
          />
          <SelectRow
            label={t("settings.share_loc")}
            value={settings.shareLocation}
            onChange={(v) => update("shareLocation", v as SettingsState["shareLocation"])}
            options={[
              { value: "off", label: t("settings.off") },
              { value: "while_using", label: t("settings.while_using") },
              { value: "always", label: t("settings.on") },
            ]}
          />
        </Group>

        {/* Account & language */}
        <Group title={t("settings.account")}>
          <SelectRow
            label={t("settings.language")}
            value={lang}
            onChange={(v) => setLang(v as Lang)}
            options={[
              { value: "en", label: "English" },
              { value: "sv", label: "Svenska" },
            ]}
          />
          <SelectRow
            label={t("units.label")}
            value={settings.units}
            onChange={(v) => update("units", v as SettingsState["units"])}
            options={[
              { value: "metric", label: t("units.metric") },
              { value: "imperial", label: t("units.imperial") },
            ]}
          />
          <Row label={t("settings.nickname")} meta={settings.displayName} onClick={() => setNicknameOpen(true)} />
          <Row label={t("settings.username")} meta={`@${settings.username}`} onClick={() => setUsernameOpen(true)} />
          <Row label={t("settings.email")} meta={settings.email} onClick={() => setEmailOpen(true)} />
          <Row label={t("settings.password")} meta="••••••••" onClick={() => setPasswordOpen(true)} />
          <Row label={t("settings.signout")} onClick={async () => { await supabase.auth.signOut(); navigate({ to: "/auth" }); }} />
        </Group>

        {/* Support */}
        <Group title={t("settings.support")}>
          <Row label={t("settings.report_problem")} onClick={() => setReportOpen(true)} />
          <Row label={t("settings.delete_account")} danger onClick={() => setDeleteOpen(true)} />
        </Group>

        <p className="pt-4 text-center text-[11px] text-sage-600">SetGoals UF · v1.0.0</p>
      </div>

      <ProUpgradeDialog open={proOpen} onOpenChange={setProOpen} />

      <Dialog open={themeOpen} onOpenChange={setThemeOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("theme.title")}</DialogTitle>
            <DialogDescription>{t("theme.desc")}</DialogDescription>
          </DialogHeader>
          <div className="grid grid-cols-3 gap-3 py-2">
            {THEME_COLORS.map((c) => {
              const active = settings.themeColor === c.id;
              return (
                <button
                  key={c.id}
                  onClick={() => {
                    update("themeColor", c.id as ThemeColor);
                    toast.success(t("theme.updated"));
                  }}
                  className={`flex flex-col items-center gap-2 rounded-2xl p-3 ring-1 transition-colors ${
                    active ? "ring-sage-700/40 bg-sage-50" : "ring-black/10 bg-card hover:bg-sage-50/60"
                  }`}
                >
                  <span
                    className="grid size-10 place-items-center rounded-full ring-2 ring-white shadow"
                    style={{ background: c.swatch }}
                  >
                    {active && <Check className="size-4 text-white" />}
                  </span>
                  <span className="text-xs font-medium">{t(`theme.${c.id}`)}</span>
                </button>
              );
            })}
          </div>
        </DialogContent>
      </Dialog>


      {/* Steps per 30 dialog */}
      <SliderDialog
        open={stepsOpen}
        onOpenChange={setStepsOpen}
        title={t("settings.steps_per_30")}
        value={settings.stepsPer30}
        min={200}
        max={3000}
        step={100}
        unit=""
        onSave={(v) => {
          update("stepsPer30", v);
          toast.success(`${t("settings.steps_per_30")}: ${v.toLocaleString()}`);
        }}
        t={t}
      />

      {/* Daily cap dialog */}
      <SliderDialog
        open={capOpen}
        onOpenChange={setCapOpen}
        title={t("settings.daily_cap")}
        value={settings.dailyCapHours}
        min={1}
        max={8}
        step={1}
        unit={t("settings.hours")}
        unlimited={{ sentinel: 24, label: t("parent.no_cap") }}
        onSave={(v) => {
          update("dailyCapHours", v);
          toast.success(`${t("settings.daily_cap")}: ${v >= 24 ? t("parent.no_cap") : `${v}${t("settings.hours")}`}`);
        }}
        t={t}
      />

      {/* Daily step goal dialog */}
      <SliderDialog
        open={goalOpen}
        onOpenChange={setGoalOpen}
        title={t("settings.daily_goal")}
        value={settings.dailyGoal}
        min={2000}
        max={25000}
        step={500}
        unit={t("settings.steps")}
        onSave={(v) => {
          update("dailyGoal", v);
          toast.success(`${t("settings.daily_goal")}: ${v.toLocaleString()}`);
        }}
        t={t}
      />

      {/* Connect dialog */}
      <Dialog open={connectKind !== null} onOpenChange={(o) => !o && setConnectKind(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{connectKind === "hk" ? t("hk.title") : t("gf.title")}</DialogTitle>
            <DialogDescription>
              {connectKind === "hk" ? t("hk.desc") : t("gf.desc")}
            </DialogDescription>
          </DialogHeader>
          <ul className="space-y-2 text-sm text-sage-700">
            <li className="flex items-center gap-2"><Check className="size-4 text-sage-600" /> {t("settings.scope.steps")}</li>
            <li className="flex items-center gap-2"><Check className="size-4 text-sage-600" /> {t("settings.scope.distance")}</li>
            <li className="flex items-center gap-2"><Check className="size-4 text-sage-600" /> {t("settings.scope.energy")}</li>
          </ul>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setConnectKind(null)}>{t("settings.cancel")}</Button>
            <Button
              onClick={() => {
                if (connectKind === "hk") update("healthkitConnected", true);
                if (connectKind === "gf") update("googlefitConnected", true);
                toast.success(t("settings.connected"));
                setConnectKind(null);
              }}
            >
              {t("hk.allow")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Report problem dialog */}
      <Dialog open={reportOpen} onOpenChange={(o) => { if (!o) setReportText(""); setReportOpen(o); }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t("report.title")}</DialogTitle>
            <DialogDescription>{t("report.desc")}</DialogDescription>
          </DialogHeader>
          <Textarea
            value={reportText}
            onChange={(e) => setReportText(e.target.value)}
            placeholder={t("report.placeholder")}
            className="min-h-[120px] mt-2"
          />
          <DialogFooter>
            <Button variant="ghost" onClick={() => { setReportText(""); setReportOpen(false); }}>{t("settings.cancel")}</Button>
            <Button
              disabled={!reportText.trim()}
              onClick={() => {
                const body = encodeURIComponent(reportText);
                window.open(`mailto:support@setgoals.app?subject=Problem%20report&body=${body}`, "_blank");
                toast.success(t("report.thanks"));
                awardBadge("problem_solver");
                setReportText("");
                setReportOpen(false);
              }}
            >
              {t("report.send")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={deleteOpen} onOpenChange={(o) => { setDeleteOpen(o); if (!o) setDeletePassword(""); }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="text-destructive">{t("delete.title")}</DialogTitle>
            <DialogDescription>{t("delete.desc")}</DialogDescription>
          </DialogHeader>
          <div className="space-y-2 py-2">
            <Label htmlFor="delete-pw">{t("delete.password")}</Label>
            <Input
              id="delete-pw"
              type="password"
              value={deletePassword}
              onChange={(e) => setDeletePassword(e.target.value)}
              autoComplete="current-password"
            />
          </div>
          <DialogFooter>
            <Button variant="ghost" onClick={() => { setDeleteOpen(false); setDeletePassword(""); }}>{t("settings.cancel")}</Button>
            <Button
              variant="destructive"
              disabled={!deletePassword || deleting}
              onClick={async () => {
                setDeleting(true);
                const ok = await deleteAccount(deletePassword);
                setDeleting(false);
                if (ok) { setDeleteOpen(false); setDeletePassword(""); }
              }}
            >
              {t("delete.confirm")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>


      <NicknameDialog
        open={nicknameOpen}
        onOpenChange={setNicknameOpen}
        current={settings.displayName}
        onSave={(v) => { update("displayName", v); toast.success(t("account.updated")); }}
        t={t}
      />
      <UsernameDialog
        open={usernameOpen}
        onOpenChange={setUsernameOpen}
        current={settings.username}
        onSave={(v) => { update("username", v); toast.success(t("account.updated")); }}
        t={t}
      />
      <EmailDialog
        open={emailOpen}
        onOpenChange={setEmailOpen}
        current={settings.email}
        onSave={async (v) => {
          const { error } = await supabase.auth.updateUser({ email: v });
          if (error) return toast.error(error.message);
          update("email", v);
          toast.success("Confirmation email sent. Check your inbox.");
        }}
        t={t}
      />
      <PasswordDialog
        open={passwordOpen}
        onOpenChange={setPasswordOpen}
        currentPassword={settings.password}
        onSave={async (v) => {
          const { error } = await supabase.auth.updateUser({ password: v });
          if (error) return toast.error(error.message);
          toast.success("Password updated");
        }}
        t={t}
      />
    </AppShell>
  );
}

function Group({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="space-y-2">
      <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{title}</h2>
      <div className="rounded-3xl bg-card ring-1 ring-black/5 divide-y divide-sage-100">{children}</div>
    </section>
  );
}

function Row({ label, meta, onClick, danger }: { label: string; meta?: string; onClick?: () => void; danger?: boolean }) {
  return (
    <button onClick={onClick} className={`flex w-full items-center justify-between p-4 text-left transition-colors ${danger ? "hover:bg-destructive/10" : "hover:bg-sage-50/60"}`}>
      <span className={`text-sm font-medium ${danger ? "text-destructive" : ""}`}>{label}</span>
      <span className={`flex items-center gap-1 text-xs font-medium ${danger ? "text-destructive" : "text-sage-600"}`}>
        {meta} <ChevronRight className="size-4" />
      </span>
    </button>
  );
}

function ToggleRow({ label, checked, onChange }: { label: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <div className="flex w-full items-center justify-between p-4">
      <span className="text-sm font-medium">{label}</span>
      <Switch checked={checked} onCheckedChange={onChange} />
    </div>
  );
}

function SelectRow({
  label, value, onChange, options,
}: { label: string; value: string; onChange: (v: string) => void; options: { value: string; label: string }[] }) {
  return (
    <div className="flex w-full items-center justify-between gap-3 p-4">
      <span className="text-sm font-medium">{label}</span>
      <Select value={value} onValueChange={onChange}>
        <SelectTrigger className="h-8 w-auto min-w-[120px] rounded-xl border-0 bg-sage-100 text-xs font-medium text-sage-700">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {options.map((o) => (
            <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}

function IntegrationRow({
  icon, label, connected, onAction, t,
}: { icon: ReactNode; label: string; connected: boolean; onAction: () => void; t: (k: string) => string }) {
  return (
    <div className="flex w-full items-center justify-between p-4">
      <div className="flex items-center gap-3">
        <span className="grid size-8 place-items-center rounded-lg bg-sage-100 text-sage-700">{icon}</span>
        <span className="text-sm font-medium">{label}</span>
      </div>
      <button
        onClick={onAction}
        className={`rounded-full px-3 py-1.5 text-xs font-semibold transition-colors ${
          connected ? "bg-sage-100 text-sage-700 hover:bg-sage-200" : "bg-sage-600 text-primary-foreground hover:bg-sage-700"
        }`}
      >
        {connected ? t("settings.connected") : t("settings.connect")}
      </button>
    </div>
  );
}

function SliderDialog({
  open, onOpenChange, title, value, min, max, step, unit, onSave, t, unlimited,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  title: string;
  value: number;
  min: number;
  max: number;
  step: number;
  unit: string;
  onSave: (v: number) => void;
  t: (k: string) => string;
  unlimited?: { sentinel: number; label: string };
}) {
  const sliderMax = unlimited ? max + step : max;
  const toSlider = (v: number) => (unlimited && v >= unlimited.sentinel ? sliderMax : v);
  const fromSlider = (v: number) => (unlimited && v >= sliderMax ? unlimited.sentinel : v);
  const [local, setLocal] = useState(value);
  useEffect(() => {
    if (open) setLocal(value);
  }, [open, value]);
  const isUnlimited = unlimited && local >= unlimited.sentinel;
  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (o) setLocal(value);
        onOpenChange(o);
      }}
    >
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
        </DialogHeader>
        <div className="py-4 space-y-6">
          <p className="text-center text-4xl font-semibold tabular-nums text-sage-700">
            {isUnlimited ? (
              <span>{unlimited!.label}</span>
            ) : (
              <>
                {local.toLocaleString()}
                <span className="text-base font-medium text-sage-600 ml-1">{unit}</span>
              </>
            )}
          </p>
          <Slider
            value={[toSlider(local)]}
            min={min}
            max={sliderMax}
            step={step}
            onValueChange={(v) => setLocal(fromSlider(v[0]))}
          />
          <div className="flex justify-between text-[11px] text-sage-600 tabular-nums">
            <span>{min.toLocaleString()}{unit}</span>
            <span>{unlimited ? unlimited.label : `${max.toLocaleString()}${unit}`}</span>
          </div>
        </div>
        <DialogFooter>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>{t("settings.cancel")}</Button>
          <Button onClick={() => { onSave(local); onOpenChange(false); }}>{t("settings.save")}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function NicknameDialog({
  open, onOpenChange, current, onSave, t,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  current: string;
  onSave: (v: string) => void;
  t: (k: string) => string;
}) {
  const [val, setVal] = useState(current);
  useEffect(() => { if (open) setVal(current); }, [open, current]);
  const valid = val.trim().length >= 1 && val.trim().length <= 40;
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t("account.nickname.title")}</DialogTitle>
          <DialogDescription>{t("account.nickname.desc")}</DialogDescription>
        </DialogHeader>
        <div className="py-2 space-y-2">
          <Label htmlFor="nickname-input">{t("settings.nickname")}</Label>
          <Input
            id="nickname-input"
            value={val}
            maxLength={40}
            onChange={(e) => setVal(e.target.value)}
            placeholder={t("account.nickname.placeholder")}
            autoFocus
          />
        </div>
        <DialogFooter>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>{t("settings.cancel")}</Button>
          <Button disabled={!valid} onClick={() => { onSave(val.trim()); onOpenChange(false); }}>
            {t("settings.save")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function EmailDialog({
  open, onOpenChange, current, onSave, t,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  current: string;
  onSave: (v: string) => void;
  t: (k: string) => string;
}) {
  const [val, setVal] = useState(current);
  const [err, setErr] = useState("");
  useEffect(() => { if (open) { setVal(current); setErr(""); } }, [open, current]);
  const isEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val.trim());
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t("account.email.title")}</DialogTitle>
          <DialogDescription>{t("account.email.desc")}</DialogDescription>
        </DialogHeader>
        <div className="py-2 space-y-2">
          <Label htmlFor="email-input">{t("settings.email")}</Label>
          <Input
            id="email-input"
            type="email"
            inputMode="email"
            autoComplete="email"
            value={val}
            maxLength={254}
            onChange={(e) => { setVal(e.target.value); setErr(""); }}
            placeholder={t("account.email.placeholder")}
            autoFocus
          />
          {err && <p className="text-xs text-destructive">{err}</p>}
        </div>
        <DialogFooter>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>{t("settings.cancel")}</Button>
          <Button
            disabled={!isEmail}
            onClick={() => {
              if (!isEmail) { setErr(t("account.email.invalid")); return; }
              onSave(val.trim());
              onOpenChange(false);
            }}
          >
            {t("settings.save")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function PasswordDialog({
  open, onOpenChange, currentPassword, onSave, t,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  currentPassword: string;
  onSave: (v: string) => void;
  t: (k: string) => string;
}) {
  const [cur, setCur] = useState("");
  const [next, setNext] = useState("");
  const [confirm, setConfirm] = useState("");
  const [err, setErr] = useState("");
  useEffect(() => {
    if (open) { setCur(""); setNext(""); setConfirm(""); setErr(""); }
  }, [open]);
  const submit = () => {
    if (currentPassword && cur !== currentPassword) { setErr(t("account.password.wrong")); return; }
    if (next.length < 8) { setErr(t("account.password.short")); return; }
    if (next !== confirm) { setErr(t("account.password.mismatch")); return; }
    onSave(next);
    onOpenChange(false);
  };
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t("account.password.title")}</DialogTitle>
          <DialogDescription>{t("account.password.desc")}</DialogDescription>
        </DialogHeader>
        <div className="py-2 space-y-3">
          <div className="space-y-1.5">
            <Label htmlFor="cur-pw">{t("account.password.current")}</Label>
            <Input id="cur-pw" type="password" autoComplete="current-password" value={cur} onChange={(e) => { setCur(e.target.value); setErr(""); }} />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="new-pw">{t("account.password.new")}</Label>
            <Input id="new-pw" type="password" autoComplete="new-password" value={next} onChange={(e) => { setNext(e.target.value); setErr(""); }} />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="confirm-pw">{t("account.password.confirm")}</Label>
            <Input id="confirm-pw" type="password" autoComplete="new-password" value={confirm} onChange={(e) => { setConfirm(e.target.value); setErr(""); }} />
          </div>
          {err && <p className="text-xs text-destructive">{err}</p>}
        </div>
        <DialogFooter>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>{t("settings.cancel")}</Button>
          <Button disabled={!cur || !next || !confirm} onClick={submit}>{t("settings.save")}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function UsernameDialog({
  open, onOpenChange, current, onSave, t,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  current: string;
  onSave: (v: string) => void;
  t: (k: string) => string;
}) {
  const [val, setVal] = useState(current);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => { if (open) { setVal(current); setErr(null); } }, [open, current]);
  const submit = () => {
    const v = val.trim().toLowerCase();
    if (!/^[a-z0-9_]{3,20}$/.test(v)) { setErr(t("account.username.invalid")); return; }
    onSave(v);
    onOpenChange(false);
  };
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t("account.username.title")}</DialogTitle>
          <DialogDescription>{t("account.username.desc")}</DialogDescription>
        </DialogHeader>
        <div className="py-2 space-y-2">
          <Label htmlFor="username-input">{t("settings.username")}</Label>
          <Input
            id="username-input"
            value={val}
            maxLength={20}
            onChange={(e) => { setVal(e.target.value.replace(/[^a-zA-Z0-9_]/g, "")); setErr(null); }}
            placeholder={t("account.username.placeholder")}
            autoFocus
          />
          {err && <p className="text-xs text-destructive">{err}</p>}
        </div>
        <DialogFooter>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>{t("settings.cancel")}</Button>
          <Button onClick={submit}>{t("settings.save")}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
