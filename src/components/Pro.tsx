import { Sparkles, Check, X } from "lucide-react";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { useT } from "@/lib/i18n";
import { useSettings } from "@/lib/settings";
import { toast } from "sonner";

export function ProUpgradeDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const { t } = useT();
  const { settings, update } = useSettings();

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
        <ul className="space-y-2.5 py-2">
          {features.map((k) => (
            <li key={k} className="flex items-start gap-2 text-sm">
              <Check className="mt-0.5 size-4 shrink-0 text-sage-600" />
              <span>{t(k)}</span>
            </li>
          ))}
        </ul>
        <p className="text-center text-lg font-semibold text-sage-700">{t("pro.price")}</p>
        <DialogFooter className="sm:justify-stretch">
          {settings.isPro ? (
            <Button
              variant="outline"
              className="w-full"
              onClick={() => {
                update("isPro", false);
                toast(t("pro.cancelled"));
                onOpenChange(false);
              }}
            >
              <X className="size-4" /> {t("pro.cancel")}
            </Button>
          ) : (
            <Button
              className="w-full"
              onClick={() => {
                update("isPro", true);
                toast.success(t("pro.welcome"));
                onOpenChange(false);
              }}
            >
              <Sparkles className="size-4" /> {t("pro.upgrade")}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
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
