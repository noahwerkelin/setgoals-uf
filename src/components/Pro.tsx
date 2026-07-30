import { Sparkles, Check, Calendar, RefreshCw, Crown, Apple } from "lucide-react";
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
          <button
            key={p}
            onClick={() => onSelect(p)}
            className={`rounded-2xl p-3 text-left ring-1 transition-colors ${
              active ? "bg-sage-600 text-primary-foreground ring-sage-700/40" : "bg-card ring-black/10"
            }`}
          >
            <p className="text-xs uppercase tracking-wide opacity-80">{t(`pro.plan.${p}`)}</p>
            <p className="text-sm font-semibold">{t(`pro.price.${p}`)}</p>
            {p.endsWith("yearly") && (
              <p className={`text-[11px] ${active ? "text-white/80" : "text-sage-600"}`}>{t("pro.save_badge")}</p>
            )}
          </button>
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
    "pro.feature.bonus",
    "pro.feature.coach",
    "pro.feature.parental",
    "pro.feature.stats",
    "pro.feature.theme",
    "pro.feature.premium_badge",
    ...(isFamilyPlan(plan) ? ["pro.feature.family"] : []),
  ];

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

        <PlanGrid plan={plan} onSelect={setPlan} />

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
