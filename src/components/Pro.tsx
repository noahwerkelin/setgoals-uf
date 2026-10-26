import { Sparkles, Check, Calendar, RefreshCw, Crown, Apple, SlidersHorizontal, Bot, ChartNoAxesCombined, Palette, ShieldCheck, Users } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";

import { useT } from "@/lib/i18n";
import { useSettings, isFamilyPlan, type SubPlan } from "@/lib/settings";
import { useServerFn } from "@tanstack/react-start";
import { syncStoreKitPurchase, syncSubscriptionStatus } from "@/utils/payments.functions";
import {
  purchasePlan,
  restorePurchases,
  openManageSubscriptions,
  isStoreKitSupportedOnPlatform,
} from "@/lib/storekit";

const ALL_PLANS: SubPlan[] = ["monthly", "yearly", "family_monthly", "family_yearly"];

function PlanGrid({ plan, onSelect }: { plan: SubPlan; onSelect: (p: SubPlan) => void }) {
  const { t } = useT();
  return (
    <div className="grid grid-cols-2 gap-2">
      {ALL_PLANS.map((p) => {
        const active = plan === p;
        return (
          <Button
            key={p}
             variant="outline"
             aria-pressed={active}
            onClick={() => onSelect(p)}
             className={`relative h-auto min-h-24 flex-col items-start justify-center gap-1 whitespace-normal rounded-2xl p-4 text-left border transition-colors ${
               active ? "bg-secondary text-foreground border-primary hover:bg-secondary" : "bg-card border-border hover:bg-muted"
            }`}
          >
             <span className="text-xs text-muted-foreground">{t(`pro.plan.${p}`)}</span>
             <span className="text-base font-semibold">{t(`pro.price.${p}`)}</span>
             {active && <Check className="absolute right-3 top-3 size-3.5 text-primary" />}
            {p.endsWith("yearly") && (
               <span className="text-[11px] font-medium text-primary">{t("pro.save_badge")}</span>
            )}
           </Button>
        );
      })}
    </div>
  );
}
import { toast } from "sonner";
import { useEffect, useState } from "react";

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
  // Children can never purchase a plan — they inherit PRO from a parent's Family plan.
  if (settings.role === "child") {
    return <ChildProDialog open={open} onOpenChange={onOpenChange} />;
  }
  if (settings.isPro) {
    return <ManageSubscriptionDialog open={open} onOpenChange={onOpenChange} />;
  }
  return <UpgradeDialog open={open} onOpenChange={onOpenChange} />;
}


function ChildProDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const { t, lang } = useT();
  const { settings } = useSettings();
  const fam = settings.parentFamily;
  const endsAt = fam?.endsAt ? formatDate(new Date(fam.endsAt), lang) : null;
  const desc = fam?.cancelling && endsAt
    ? t("pro.child_ending", { date: endsAt })
    : fam?.active
      ? t("pro.child_active")
      : t("pro.child_desc");
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <div className="mx-auto mb-2 grid size-12 place-items-center rounded-2xl bg-sage-100 text-sage-700">
            <Sparkles className="size-6" />
          </div>
          <DialogTitle className="text-center">
            {fam?.active ? t("pro.child_active_title") : t("pro.child_title")}
          </DialogTitle>
          <DialogDescription className="text-center">{desc}</DialogDescription>
        </DialogHeader>
        <DialogFooter className="sm:justify-stretch">
          <Button variant="outline" className="w-full" onClick={() => onOpenChange(false)}>
            {t("common.close")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function UpgradeDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const { t } = useT();
  const { refresh } = useSettings();
  const syncPurchaseFn = useServerFn(syncStoreKitPurchase);
  const [plan, setPlan] = useState<SubPlan>("monthly");
  const [busy, setBusy] = useState<"buy" | "restore" | null>(null);
  const [note, setNote] = useState<string | null>(null);

  const features = [
    "pro.feature.earning",
    "pro.feature.bonus",
    "pro.feature.parental",
    "pro.feature.stats",
    "pro.feature.theme",
    "pro.feature.premium_badge",
    ...(isFamilyPlan(plan) ? ["pro.feature.family"] : []),
  ];
  const featureIcons = [SlidersHorizontal, RefreshCw, Bot, ShieldCheck, ChartNoAxesCombined, Palette, Crown, Users];

  /** Hand a StoreKit result to the server, which is the only entitlement judge. */
  const grant = async (transactions: string[]) => {
    const res = await syncPurchaseFn({ data: { transactions } });
    if ("error" in res) throw new Error(res.error);
    await refresh();
    if (res.isPro) {
      toast.success(t("pro.welcome"));
      onOpenChange(false);
    } else {
      setNote(t("pro.store.nothing_to_restore"));
    }
  };

  const handleStoreResult = async (
    res: Awaited<ReturnType<typeof purchasePlan>>,
    kind: "buy" | "restore",
  ) => {
    switch (res.status) {
      case "purchased":
      case "restored":
        await grant(res.transactions);
        break;
      case "cancelled":
        break;
      case "pending":
        setNote(t("pro.store.pending"));
        break;
      case "nothing-to-restore":
        setNote(t("pro.store.nothing_to_restore"));
        break;
      case "unavailable":
        setNote(
          res.reason === "wrong-platform"
            ? t("pro.store.ios_only")
            : t("pro.store.need_app"),
        );
        break;
      default:
        setNote(kind === "buy" ? t("pro.store.failed") : t("pro.store.restore_failed"));
    }
  };

  const run = async (kind: "buy" | "restore") => {
    setBusy(kind);
    setNote(null);
    try {
      const res = kind === "buy" ? await purchasePlan(plan) : await restorePurchases();
      await handleStoreResult(res, kind);
    } catch {
      setNote(t("pro.store.failed"));
    } finally {
      setBusy(null);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90dvh] overflow-y-auto gap-5 sm:max-w-lg">
        <DialogHeader className="border-b border-border pb-5">
          <div className="mx-auto mb-3 grid size-16 place-items-center rounded-2xl bg-primary text-primary-foreground">
            <Crown className="size-8" strokeWidth={1.5} />
          </div>
          <DialogTitle className="text-center text-2xl">{t("pro.title")}</DialogTitle>
          <DialogDescription className="text-center">{t("pro.upgrade_subtitle")}</DialogDescription>
        </DialogHeader>

        <div className="space-y-3">
          <p className="text-xs font-semibold text-muted-foreground">{t("pro.included")}</p>
          <ul className="grid gap-x-4 gap-y-3 sm:grid-cols-2">
            {features.map((k, i) => {
              const Icon = featureIcons[i] ?? Check;
              return <li key={k} className="flex items-start gap-2.5 text-sm leading-snug">
                <span className="grid size-8 shrink-0 place-items-center rounded-lg bg-muted text-primary"><Icon className="size-4" /></span>
                <span className="self-center">{t(k)}</span>
              </li>;
            })}
          </ul>
        </div>

        <div className="space-y-3 border-t border-border pt-4">
          <p className="text-xs font-semibold text-muted-foreground">{t("pro.choose_plan")}</p>
          <PlanGrid plan={plan} onSelect={setPlan} />
        </div>

        <p className="text-center text-[11px] leading-snug text-sage-600">
          {t("pro.store.billed_by_apple")}
        </p>

        {note && (
          <p className="rounded-2xl bg-sage-50 p-3 text-center text-xs text-sage-700 ring-1 ring-sage-200">
            {note}
          </p>
        )}

        <DialogFooter className="flex-col gap-2 sm:flex-col sm:space-x-0">
          <Button className="w-full" disabled={busy !== null} onClick={() => run("buy")}>
            <Apple className="size-4" />{" "}
            {busy === "buy" ? t("pro.store.opening") : t("pro.store.buy_with_apple")}
          </Button>
          <Button
            variant="ghost"
            className="w-full"
            disabled={busy !== null}
            onClick={() => run("restore")}
          >
            {busy === "restore" ? t("pro.store.restoring") : t("pro.store.restore")}
          </Button>
          {!isStoreKitSupportedOnPlatform() && (
            <p className="text-center text-[11px] text-sage-600">{t("pro.store.ios_only")}</p>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}


function ManageSubscriptionDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const { t, lang } = useT();
  const { settings, refresh } = useSettings();
  const syncFn = useServerFn(syncSubscriptionStatus);
  const syncPurchaseFn = useServerFn(syncStoreKitPurchase);
  const [busy, setBusy] = useState(false);

  const since = settings.proSince ?? new Date().toISOString();
  const cancelling = !settings.proAutoRenew && !!settings.proExpiresAt;
  const nextDate = settings.proExpiresAt
    ? new Date(settings.proExpiresAt)
    : addMonths(since, settings.proPlan.endsWith("yearly") ? 12 : 1);
  const sinceDate = new Date(since);
  const isFamily = isFamilyPlan(settings.proPlan);
  const childCount = settings.children.length;
  const price = t(`pro.price.${settings.proPlan}`);

  // Re-check the App Store entitlement every time the dashboard opens so the
  // shown plan and renewal date can never drift from the real subscription.
  useEffect(() => {
    if (!open) return;
    let cancelled = false;
    (async () => {
      try {
        await syncFn({ data: {} });
      } catch {
        /* keep showing the cached state */
      }
      if (!cancelled) await refresh();
    })();
    return () => {
      cancelled = true;
    };
  }, [open, syncFn, refresh]);

  const restore = async () => {
    setBusy(true);
    try {
      const res = await restorePurchases();
      if (res.status === "restored" || res.status === "purchased") {
        const sync = await syncPurchaseFn({ data: { transactions: res.transactions } });
        if ("error" in sync) throw new Error(sync.error);
        await refresh();
        toast.success(t("pro.store.restored"));
      } else if (res.status === "unavailable") {
        toast(res.reason === "wrong-platform" ? t("pro.store.ios_only") : t("pro.store.need_app"));
      } else if (res.status === "nothing-to-restore") {
        toast(t("pro.store.nothing_to_restore"));
      }
    } catch {
      toast.error(t("pro.store.restore_failed"));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <div className="mx-auto mb-2 grid size-12 place-items-center rounded-2xl bg-sage-600 text-primary-foreground">
            <Crown className="size-6" />
          </div>
          <DialogTitle className="text-center">{t("pro.manage_title")}</DialogTitle>
          <DialogDescription className="text-center">
            {cancelling ? t("pro.status.cancelling") : t("pro.status.active")}
          </DialogDescription>
        </DialogHeader>

        {isFamily && (
          <p
            className={`rounded-2xl p-3 text-xs ring-1 ${
              cancelling
                ? "bg-destructive/10 text-destructive ring-destructive/20"
                : "bg-sage-50 text-sage-700 ring-sage-200"
            }`}
          >
            {cancelling
              ? t("pro.family.children_lose", {
                  count: String(childCount),
                  date: formatDate(nextDate, lang),
                })
              : t("pro.family.children_active", { count: String(childCount) })}
          </p>
        )}

        <div className="space-y-2">
          <InfoRow
            icon={<Sparkles className="size-4" />}
            label={t("pro.plan")}
            value={`${t(`pro.plan.${settings.proPlan}`)} · ${price}`}
          />
          <InfoRow
            icon={<Calendar className="size-4" />}
            label={cancelling ? t("pro.ends_on") : t("pro.next_billing")}
            value={formatDate(nextDate, lang)}
          />
          <InfoRow
            icon={<RefreshCw className="size-4" />}
            label={t("pro.member_since")}
            value={formatDate(sinceDate, lang)}
          />
          <InfoRow
            icon={<Apple className="size-4" />}
            label={t("pro.payment_method")}
            value={settings.proPaymentMethod || t("pro.store.apple_id")}
          />
        </div>

        <p className="text-center text-[11px] leading-snug text-sage-600">
          {t("pro.store.manage_note")}
        </p>

        <DialogFooter className="flex-col gap-2 sm:flex-col sm:space-x-0">
          <Button className="w-full" onClick={() => openManageSubscriptions()}>
            <Apple className="size-4" /> {t("pro.store.manage_in_appstore")}
          </Button>
          <Button variant="ghost" className="w-full" disabled={busy} onClick={restore}>
            {busy ? t("pro.store.restoring") : t("pro.store.restore")}
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
  const { settings } = useSettings();
  const isChild = settings.role === "child";
  return (
    <div className="rounded-3xl bg-card p-6 ring-1 ring-black/5 text-center space-y-3">
      <div className="mx-auto grid size-12 place-items-center rounded-2xl bg-sage-100 text-sage-700">
        <Sparkles className="size-6" />
      </div>
      <div className="space-y-1">
        <p className="text-xs font-semibold uppercase tracking-widest text-sage-600">{t("pro.badge")}</p>
        <h3 className="text-base font-semibold">{t(titleKey)}</h3>
        <p className="text-sm text-sage-600">{isChild ? t("pro.child_desc") : t(descKey)}</p>
      </div>
      {!isChild && (
        <Button onClick={onUpgrade} className="w-full">
          <Sparkles className="size-4" /> {t("pro.upgrade")}
        </Button>
      )}
    </div>
  );
}
