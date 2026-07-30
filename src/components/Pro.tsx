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

import { useT } from "@/lib/i18n";
import { useSettings, isFamilyPlan, type SubPlan } from "@/lib/settings";
import { useServerFn } from "@tanstack/react-start";
import {
  cancelStripeSubscription,
  resumeStripeSubscription,
  changeStripePlan,
  createPortalSession,
} from "@/utils/payments.functions";
import { getStripeEnvironment, PLAN_PRICE_IDS } from "@/lib/stripe";
import { StripeEmbeddedCheckout } from "@/components/StripeEmbeddedCheckout";
import { PaymentTestModeBanner } from "@/components/PaymentTestModeBanner";

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

/** After returning from the hosted checkout, poll until the webhook lands. */
function useCheckoutReturn() {
  const { refresh } = useSettings();
  useEffect(() => {
    if (typeof window === "undefined") return;
    const url = new URL(window.location.href);
    if (url.searchParams.get("checkout") !== "success") return;
    url.searchParams.delete("checkout");
    url.searchParams.delete("session_id");
    window.history.replaceState({}, "", url.toString());
    let tries = 0;
    const tick = async () => {
      await refresh();
      if (++tries < 6) setTimeout(tick, 2000);
    };
    tick();
  }, [refresh]);
}

export function ProUpgradeDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const { settings } = useSettings();
  useCheckoutReturn();
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
  const [plan, setPlan] = useState<SubPlan>("monthly");
  const [checkingOut, setCheckingOut] = useState(false);

  const features = [
    "pro.feature.bonus",
    "pro.feature.coach",
    "pro.feature.parental",
    "pro.feature.stats",
    "pro.feature.theme",
    "pro.feature.premium_badge",
    ...(isFamilyPlan(plan) ? ["pro.feature.family"] : []),
  ];

  const returnUrl =
    typeof window !== "undefined"
      ? `${window.location.origin}${window.location.pathname}?checkout=success&session_id={CHECKOUT_SESSION_ID}`
      : undefined;

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!o) setCheckingOut(false);
        onOpenChange(o);
      }}
    >
      <DialogContent className={checkingOut ? "max-h-[85vh] overflow-y-auto" : undefined}>
        <DialogHeader>
          <div className="mx-auto mb-2 grid size-12 place-items-center rounded-2xl bg-sage-600 text-primary-foreground">
            <Sparkles className="size-6" />
          </div>
          <DialogTitle className="text-center">{t("pro.title")}</DialogTitle>
          <DialogDescription className="text-center">
            {checkingOut ? t(`pro.plan.${plan}`) : t("pro.subtitle")}
          </DialogDescription>
        </DialogHeader>

        {checkingOut ? (
          <div className="space-y-2">
            <PaymentTestModeBanner />
            <StripeEmbeddedCheckout priceId={PLAN_PRICE_IDS[plan]} returnUrl={returnUrl} />
            <Button variant="ghost" className="w-full" onClick={() => setCheckingOut(false)}>
              {t("common.back") ?? "Back"}
            </Button>
          </div>
        ) : (
          <>
            <ul className="space-y-2.5 py-1">
              {features.map((k) => (
                <li key={k} className="flex items-start gap-2 text-sm">
                  <Check className="mt-0.5 size-4 shrink-0 text-sage-600" />
                  <span>{t(k)}</span>
                </li>
              ))}
            </ul>

            <PlanGrid plan={plan} onSelect={setPlan} />

            <DialogFooter className="sm:justify-stretch">
              <Button className="w-full" onClick={() => setCheckingOut(true)}>
                <Sparkles className="size-4" /> {t("pro.upgrade")}
              </Button>
            </DialogFooter>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}


function ManageSubscriptionDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const { t, lang } = useT();
  const { settings, refresh } = useSettings();
  const cancelFn = useServerFn(cancelStripeSubscription);
  const resumeFn = useServerFn(resumeStripeSubscription);
  const portalFn = useServerFn(createPortalSession);
  const [confirmCancel, setConfirmCancel] = useState(false);
  const [changePlanOpen, setChangePlanOpen] = useState(false);
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
              icon={<CreditCard className="size-4" />}
              label={t("pro.payment_method")}
              value={settings.proPaymentMethod}
              action={
                <button
                  onClick={async () => {
                    const res = await portalFn({
                      data: {
                        environment: getStripeEnvironment(),
                        returnUrl: typeof window !== "undefined" ? window.location.href : undefined,
                      },
                    });
                    if ("url" in res && res.url) window.location.href = res.url;
                    else toast.error("error" in res ? res.error : t("pro.error"));
                  }}
                  className="text-xs font-medium text-sage-700 hover:underline"
                >
                  {t("pro.update")}
                </button>
              }
            />
          </div>

          <DialogFooter className="flex-col gap-2 sm:flex-col sm:space-x-0">
            <Button variant="outline" className="w-full" onClick={() => setChangePlanOpen(true)}>
              {t("pro.change_plan")}
            </Button>
            {cancelling ? (
              <Button
                className="w-full"
                disabled={busy}
                onClick={async () => {
                  setBusy(true);
                  try {
                    const res = await resumeFn({ data: { environment: getStripeEnvironment() } });
                    if ("error" in res) throw new Error(res.error);
                    await refresh();
                    toast.success(t("pro.resumed"));
                  } catch {
                    toast.error(t("pro.error"));
                  } finally {
                    setBusy(false);
                  }
                }}
              >
                <RefreshCw className="size-4" /> {t("pro.resume")}
              </Button>
            ) : (
              <Button
                variant="outline"
                className="w-full text-destructive hover:text-destructive"
                onClick={() => setConfirmCancel(true)}
              >
                <X className="size-4" /> {t("pro.cancel")}
              </Button>
            )}
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
              {isFamily && childCount > 0
                ? ` ${t("pro.cancel_confirm_family", { count: String(childCount), date: formatDate(nextDate, lang) })}`
                : ""}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t("pro.keep")}</AlertDialogCancel>
            <AlertDialogAction
              onClick={async () => {
                try {
                  const res = await cancelFn({ data: { environment: getStripeEnvironment() } });
                  if ("error" in res) throw new Error(res.error);
                  await refresh();
                  toast(
                    t("pro.cancelled_on", {
                      date: formatDate(nextDate, lang),
                    }),
                  );
                } catch {
                  toast.error(t("pro.error"));
                }
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
  const { settings, refresh } = useSettings();
  const changeFn = useServerFn(changeStripePlan);
  const [plan, setPlan] = useState<SubPlan>(settings.proPlan);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t("pro.change_plan")}</DialogTitle>
          <DialogDescription>{t("pro.change_plan_desc")}</DialogDescription>
        </DialogHeader>
        <PlanGrid plan={plan} onSelect={setPlan} />

        <DialogFooter>
          <Button
            className="w-full"
            disabled={plan === settings.proPlan}
            onClick={async () => {
              try {
                const res = await changeFn({
                  data: { priceId: PLAN_PRICE_IDS[plan], environment: getStripeEnvironment() },
                });
                if ("error" in res) throw new Error(res.error);
                await refresh();
                toast.success(t("pro.plan_changed"));
              } catch {
                toast.error(t("pro.error"));
              }
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
