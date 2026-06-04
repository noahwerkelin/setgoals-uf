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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { toast } from "sonner";
import { ProUpgradeDialog } from "@/components/Pro";
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
  const [connectKind, setConnectKind] = useState<"hk" | "gf" | null>(null);
  const [proOpen, setProOpen] = useState(false);

  const isChild = settings.role === "child";
  const [reportOpen, setReportOpen] = useState(false);
  const [reportText, setReportText] = useState("");

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

        {/* Earning rules — only parents/individuals can change */}
        {!isChild && (
          <Group title={t("settings.earning")}>
            <Row
              label={t("settings.steps_per_30")}
              meta={settings.stepsPer30.toLocaleString()}
              onClick={() => setStepsOpen(true)}
            />
            <Row
              label={t("settings.daily_cap")}
              meta={`${settings.dailyCapHours}${t("settings.hours")}`}
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
          <Row label={t("settings.email")} meta="lukas@example.com" onClick={() => toast("lukas@example.com")} />
          <Row label={t("settings.signout")} onClick={() => { toast.success(t("settings.signout")); navigate({ to: "/auth" }); }} />
        </Group>

        {/* Support */}
        <Group title={t("settings.support")}>
          <Row label={t("settings.report_problem")} onClick={() => setReportOpen(true)} />
        </Group>

        <p className="pt-4 text-center text-[11px] text-sage-600">SetGoals UF · v1.0.0</p>
      </div>

      <ProUpgradeDialog open={proOpen} onOpenChange={setProOpen} />


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
        onSave={(v) => {
          update("dailyCapHours", v);
          toast.success(`${t("settings.daily_cap")}: ${v}${t("settings.hours")}`);
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
                setReportText("");
                setReportOpen(false);
              }}
            >
              {t("report.send")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
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

function Row({ label, meta, onClick }: { label: string; meta?: string; onClick?: () => void }) {
  return (
    <button onClick={onClick} className="flex w-full items-center justify-between p-4 text-left hover:bg-sage-50/60 transition-colors">
      <span className="text-sm font-medium">{label}</span>
      <span className="flex items-center gap-1 text-xs font-medium text-sage-600">
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
  open, onOpenChange, title, value, min, max, step, unit, onSave, t,
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
}) {
  const [local, setLocal] = useState(value);
  useEffect(() => {
    if (open) setLocal(value);
  }, [open, value]);
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
            {local.toLocaleString()}<span className="text-base font-medium text-sage-600 ml-1">{unit}</span>
          </p>
          <Slider
            value={[local]}
            min={min}
            max={max}
            step={step}
            onValueChange={(v) => setLocal(v[0])}
          />
          <div className="flex justify-between text-[11px] text-sage-600 tabular-nums">
            <span>{min.toLocaleString()}{unit}</span>
            <span>{max.toLocaleString()}{unit}</span>
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
