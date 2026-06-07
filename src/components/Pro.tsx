import { Sparkles, Check, X, Calendar, CreditCard, RefreshCw, Crown } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { useT } from "@/lib/i18n";
import { useSettings, type SubPlan } from "@/lib/settings";
import { toast } from "sonner";
import { useState } from "react";

function addMonths(iso: string, months: number): Date {
  const d = new Date(iso);
  d.setMonth(d.getMonth() + months);
  return d;
}

function formatDate(d: Date, lang: string): string {
  return d.toLocaleDateString(lang === "sv" ? "sv-SE" : "en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export function ProUpgradeDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const { settings } = useSettings();
  if (settings.isPro) {
    return <ManageSubscriptionDialog open={open} onOpenChange={onOpenChange} />;
  }
  return <UpgradeDialog open={open} onOpenChange={onOpenChange} />;
}

function UpgradeDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const { t } = useT();
  const { update } = useSettings();
  const [plan, setPlan] = useState<SubPlan>("monthly");

  const features = [
    "pro.feature.bonus",
    "pro.feature.coach",
    "pro.feature.avatars",
    "pro.feature.parental",
    "pro.feature.challenges",
    "pro.feature.stats",
  ];

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <div className="mx-auto mb-2 grid size-12 place-items-center rounded-2xl bg-sage-600 text-primary-foreground">
            <Sparkles className="size-6" />
          </div>
          <DialogTitle className="text-center">{t("pro.title")}</DialogTitle>
          <DialogDescription className="text-center">{t("pro.subtitle")}</DialogDescription>
        </DialogHeader>

        <ul className="space-y-2.5 py-1">
          {features.map((k) => (
            <li key={k} className="flex items-start gap-2 text-sm">
              <Check className="mt-0.5 size-4 shrink-0 text-sage-600" />
              <span>{t(k)}</span>
            </li>
          ))}
        </ul>

        <div className="grid grid-cols-2 gap-2">
          {(["monthly", "yearly"] as SubPlan[]).map((p) => (
            <button
              key={p}
              onClick={() => setPlan(p)}
              className={`rounded-2xl p-3 text-left ring-1 transition-colors ${
                plan === p ? "bg-sage-600 text-primary-foreground ring-sage-700/40" : "bg-card ring-black/10"
              }`}
            >
              <p className="text-xs uppercase tracking-wide opacity-80">{t(`pro.plan.${p}`)}</p>
              <p className="text-sm font-semibold">{t(`pro.price.${p}`)}</p>
              {p === "yearly" && (
                <p className={`text-[11px] ${plan === p ? "text-white/80" : "text-sage-600"}`}>
                  {t("pro.save_badge")}
                </p>
              )}
            </button>
          ))}
        </div>

        <DialogFooter className="sm:justify-stretch">
          <Button
            className="w-full"
            onClick={() => {
              update("isPro", true);
              update("proPlan", plan);
              update("proSince", new Date().toISOString());
              update("proAutoRenew", true);
              toast.success(t("pro.welcome"));
              onOpenChange(false);
            }}
          >
            <Sparkles className="size-4" /> {t("pro.upgrade")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function ManageSubscriptionDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const { t, lang } = useT();
  const { settings, update } = useSettings();
  const [confirmCancel, setConfirmCancel] = useState(false);
  const [changePlanOpen, setChangePlanOpen] = useState(false);

  const since = settings.proSince ?? new Date().toISOString();
  const nextDate = addMonths(since, settings.proPlan === "yearly" ? 12 : 1);
  const sinceDate = new Date(since);
  const price = settings.proPlan === "yearly" ? t("pro.price.yearly") : t("pro.price.monthly");

  return (
    <>
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent>
          <DialogHeader>
            <div className="mx-auto mb-2 grid size-12 place-items-center rounded-2xl bg-sage-600 text-primary-foreground">
              <Crown className="size-6" />
            </div>
            <DialogTitle className="text-center">{t("pro.manage_title")}</DialogTitle>
            <DialogDescription className="text-center">
              {settings.proAutoRenew ? t("pro.status.active") : t("pro.status.cancelling")}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-2">
            <InfoRow
              icon={<Sparkles className="size-4" />}
              label={t("pro.plan")}
              value={`${t(`pro.plan.${settings.proPlan}`)} · ${price}`}
            />
            <InfoRow
              icon={<Calendar className="size-4" />}
              label={settings.proAutoRenew ? t("pro.next_billing") : t("pro.ends_on")}
              value={formatDate(nextDate, lang)}
            />
            <InfoRow
              icon={<RefreshCw className="size-4" />}
              label={t("pro.member_since")}
              value={formatDate(sinceDate, lang)}
            />
            <InfoRow
              icon={<CreditCard className="size-4" />}
              label={t("pro.payment_method")}
              value={settings.proPaymentMethod}
              action={
                <button
                  onClick={() => {
                    const next = settings.proPaymentMethod.includes("Visa")
                      ? "Mastercard •• 5454"
                      : "Visa •• 4242";
                    update("proPaymentMethod", next);
                    toast.success(t("pro.payment_updated"));
                  }}
                  className="text-xs font-medium text-sage-700 hover:underline"
                >
                  {t("pro.update")}
                </button>
              }
            />
            <div className="flex items-center justify-between rounded-2xl bg-card p-3 ring-1 ring-black/5">
              <div className="flex items-center gap-2">
                <RefreshCw className="size-4 text-sage-700" />
                <span className="text-sm">{t("pro.auto_renew")}</span>
              </div>
              <Switch
                checked={settings.proAutoRenew}
                onCheckedChange={(v) => {
                  update("proAutoRenew", v);
                  toast(v ? t("pro.resumed") : t("pro.will_end", { date: formatDate(nextDate, lang) }));
                }}
              />
            </div>
          </div>

          <DialogFooter className="flex-col gap-2 sm:flex-col sm:space-x-0">
            <Button variant="outline" className="w-full" onClick={() => setChangePlanOpen(true)}>
              {t("pro.change_plan")}
            </Button>
            <Button
              variant="outline"
              className="w-full text-destructive hover:text-destructive"
              onClick={() => setConfirmCancel(true)}
            >
              <X className="size-4" /> {t("pro.cancel")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ChangePlanDialog open={changePlanOpen} onOpenChange={setChangePlanOpen} />

      <AlertDialog open={confirmCancel} onOpenChange={setConfirmCancel}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t("pro.cancel_confirm_title")}</AlertDialogTitle>
            <AlertDialogDescription>
              {t("pro.cancel_confirm_desc", { date: formatDate(nextDate, lang) })}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t("pro.keep")}</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => {
                update("isPro", false);
                update("proAutoRenew", false);
                update("proSince", null);
                toast(t("pro.cancelled"));
                setConfirmCancel(false);
                onOpenChange(false);
              }}
            >
              {t("pro.confirm_cancel")}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}

function ChangePlanDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const { t } = useT();
  const { settings, update } = useSettings();
  const [plan, setPlan] = useState<SubPlan>(settings.proPlan);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t("pro.change_plan")}</DialogTitle>
          <DialogDescription>{t("pro.change_plan_desc")}</DialogDescription>
        </DialogHeader>
        <div className="grid grid-cols-2 gap-2">
          {(["monthly", "yearly"] as SubPlan[]).map((p) => (
            <button
              key={p}
              onClick={() => setPlan(p)}
              className={`rounded-2xl p-3 text-left ring-1 transition-colors ${
                plan === p ? "bg-sage-600 text-primary-foreground ring-sage-700/40" : "bg-card ring-black/10"
              }`}
            >
              <p className="text-xs uppercase tracking-wide opacity-80">{t(`pro.plan.${p}`)}</p>
              <p className="text-sm font-semibold">{t(`pro.price.${p}`)}</p>
            </button>
          ))}
        </div>
        <DialogFooter>
          <Button
            className="w-full"
            disabled={plan === settings.proPlan}
            onClick={() => {
              update("proPlan", plan);
              update("proSince", new Date().toISOString());
              toast.success(t("pro.plan_changed"));
              onOpenChange(false);
            }}
          >
            {t("pro.confirm_change")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function InfoRow({
  icon,
  label,
  value,
  action,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex items-center justify-between rounded-2xl bg-card p-3 ring-1 ring-black/5">
      <div className="flex items-center gap-2 min-w-0">
        <span className="text-sage-700">{icon}</span>
        <div className="min-w-0">
          <p className="text-xs text-sage-600">{label}</p>
          <p className="text-sm font-medium truncate">{value}</p>
        </div>
      </div>
      {action}
    </div>
  );
}

export function ProLockCard({
  titleKey,
  descKey,
  onUpgrade,
}: { titleKey: string; descKey: string; onUpgrade: () => void }) {
  const { t } = useT();
  return (
    <div className="rounded-3xl bg-card p-6 ring-1 ring-black/5 text-center space-y-3">
      <div className="mx-auto grid size-12 place-items-center rounded-2xl bg-sage-100 text-sage-700">
        <Sparkles className="size-6" />
      </div>
      <div className="space-y-1">
        <p className="text-xs font-semibold uppercase tracking-widest text-sage-600">{t("pro.badge")}</p>
        <h3 className="text-base font-semibold">{t(titleKey)}</h3>
        <p className="text-sm text-sage-600">{t(descKey)}</p>
      </div>
      <Button onClick={onUpgrade} className="w-full">
        <Sparkles className="size-4" /> {t("pro.upgrade")}
      </Button>
    </div>
  );
}
