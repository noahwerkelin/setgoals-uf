import { createFileRoute } from "@tanstack/react-router";
import { Shield, Check, X, Plus, Lock, Sparkles, Copy, Pencil, Trash2 } from "lucide-react";
import { useState } from "react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { useT } from "@/lib/i18n";
import { useSettings, genChildCode, type ChildProfile } from "@/lib/settings";
import { ProUpgradeDialog } from "@/components/Pro";
import { toast } from "sonner";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";

export const Route = createFileRoute("/parent")({
  head: () => ({
    meta: [
      { title: "Parent dashboard — SetGoals UF" },
      { name: "description", content: "Approve apps, set goals, and view your child's activity." },
    ],
  }),
  component: Page,
});

type AppState = "approved" | "blocked";
const INITIAL_APPS: { name: string; state: AppState }[] = [
  { name: "YouTube", state: "approved" },
  { name: "TikTok", state: "blocked" },
  { name: "Instagram", state: "approved" },
  { name: "Roblox", state: "approved" },
];

const AVATAR_OPTIONS = ["🌱", "🌳", "🐻", "🦊", "🐼", "🦁", "🐸", "🦄", "⭐️", "🚀"];

function Page() {
  const { t } = useT();
  const { settings, update } = useSettings();
  const [apps, setApps] = useState(INITIAL_APPS);
  const [proOpen, setProOpen] = useState(false);
  const [editing, setEditing] = useState<ChildProfile | null>(null);
  const [isNew, setIsNew] = useState(false);

  const setState = (name: string, state: AppState) => {
    setApps((a) => a.map((x) => (x.name === name ? { ...x, state } : x)));
    toast.success(`${name}: ${state === "approved" ? "✓" : "✕"}`);
  };

  const openNew = () => {
    setEditing({
      id: crypto.randomUUID(),
      name: "",
      birthday: "",
      avatar: AVATAR_OPTIONS[0],
      dailyGoal: 8000,
      code: genChildCode(),
    });
    setIsNew(true);
  };

  const openEdit = (c: ChildProfile) => {
    setEditing({ ...c });
    setIsNew(false);
  };

  const save = (c: ChildProfile) => {
    if (!c.name.trim()) {
      toast.error(t("auth.required"));
      return;
    }
    if (isNew) {
      update("children", [...settings.children, c]);
      toast.success(t("parent.child.created"));
    } else {
      update("children", settings.children.map((x) => (x.id === c.id ? c : x)));
      toast.success(t("parent.child.updated"));
    }
    setEditing(null);
  };

  const remove = (id: string) => {
    update("children", settings.children.filter((c) => c.id !== id));
    toast.success(t("parent.child.removed"));
  };

  const copyCode = async (code: string) => {
    try {
      await navigator.clipboard.writeText(code);
      toast.success(t("auth.copied"));
    } catch {}
  };

  return (
    <AppShell>
      <PageHeader
        eyebrow={t("parent.eyebrow")}
        title={t("parent.title")}
        trailing={
          <span className="grid size-10 place-items-center rounded-full bg-sage-100 text-sage-700">
            <Shield className="size-4" />
          </span>
        }
      />
      <div className="px-6 space-y-6">
        <section className="space-y-3">
          <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{t("parent.children")}</h2>

          {settings.children.length === 0 && (
            <p className="rounded-3xl bg-card p-5 text-center text-xs text-sage-600 ring-1 ring-black/5">
              {t("parent.child.empty")}
            </p>
          )}

          {settings.children.map((k, i) => {
            const steps = mockSteps(k.id);
            return (
              <article
                key={k.id}
                className="rounded-3xl bg-card p-5 ring-1 ring-black/5 animate-rise"
                style={{ animationDelay: `${i * 60}ms` }}
              >
                <div className="flex items-center gap-3">
                  <span className="grid size-11 place-items-center rounded-full bg-sage-200 text-xl">
                    {k.avatar}
                  </span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold truncate">{k.name}</p>
                    <p className="text-xs text-sage-600">{ageFromBirthday(k.birthday, t)}</p>
                  </div>
                  <button
                    onClick={() => openEdit(k)}
                    aria-label={t("parent.child.edit")}
                    className="grid size-8 place-items-center rounded-full bg-sage-100 text-sage-700"
                  >
                    <Pencil className="size-3.5" />
                  </button>
                  <button
                    onClick={() => remove(k.id)}
                    aria-label={t("parent.child.delete")}
                    className="grid size-8 place-items-center rounded-full bg-sage-100 text-sage-700"
                  >
                    <Trash2 className="size-3.5" />
                  </button>
                </div>

                <div className="mt-4 grid grid-cols-3 gap-3 text-center">
                  <Stat label={t("parent.steps")} value={steps.toLocaleString()} />
                  <Stat label={t("parent.child.daily_goal")} value={k.dailyGoal.toLocaleString()} />
                  <Stat label={t("parent.goal")} value={`${Math.round((steps / k.dailyGoal) * 100)}%`} />
                </div>

                <button
                  onClick={() => copyCode(k.code)}
                  className="mt-4 flex w-full items-center justify-between rounded-2xl bg-sage-50 px-4 py-3 ring-1 ring-sage-200"
                >
                  <div className="text-left">
                    <p className="text-[10px] font-semibold uppercase tracking-widest text-sage-600">
                      {t("parent.child.code")}
                    </p>
                    <p className="text-base font-semibold tracking-[0.3em] text-sage-900">{k.code}</p>
                  </div>
                  <span className="grid size-9 place-items-center rounded-full bg-sage-600 text-primary-foreground">
                    <Copy className="size-4" />
                  </span>
                </button>
                <p className="mt-1 px-1 text-[10px] text-sage-600">{t("parent.child.code_help")}</p>
              </article>
            );
          })}

          <button
            onClick={openNew}
            className="flex w-full items-center justify-center gap-2 rounded-3xl border border-dashed border-sage-300 p-4 text-sm font-medium text-sage-700"
          >
            <Plus className="size-4" /> {t("parent.add_child")}
          </button>
        </section>

        <section className="space-y-3">
          <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{t("parent.apps")}</h2>
          <div className="rounded-3xl bg-card ring-1 ring-black/5">
            {apps.map((a, i) => (
              <div
                key={a.name}
                className={`flex items-center justify-between p-4 ${i > 0 ? "border-t border-sage-100" : ""}`}
              >
                <span className="text-sm font-medium">{a.name}</span>
                <div className="flex gap-1">
                  <button
                    onClick={() => setState(a.name, "approved")}
                    aria-label={t("parent.approve", { n: a.name })}
                    className={`grid size-8 place-items-center rounded-full ${a.state === "approved" ? "bg-sage-600 text-white" : "bg-sage-100 text-sage-600"}`}
                  >
                    <Check className="size-4" />
                  </button>
                  <button
                    onClick={() => setState(a.name, "blocked")}
                    aria-label={t("parent.block", { n: a.name })}
                    className={`grid size-8 place-items-center rounded-full ${a.state === "blocked" ? "bg-destructive text-white" : "bg-sage-100 text-sage-600"}`}
                  >
                    <X className="size-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </section>

        <section className="rounded-3xl bg-card p-5 ring-1 ring-black/5">
          <h3 className="text-sm font-semibold">{t("parent.rules")}</h3>
          <p className="mt-1 text-xs text-sage-600">{t("parent.rules_sub")}</p>
          <button
            onClick={() => toast(t("parent.configure"))}
            className="mt-3 rounded-xl bg-sage-100 px-3 py-2 text-xs font-semibold text-sage-700"
          >
            {t("parent.configure")}
          </button>
        </section>

        <section className={`rounded-3xl p-5 ring-1 ${settings.isPro ? "bg-card ring-black/5" : "bg-sage-50 ring-sage-200"}`}>
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <span className="grid size-8 place-items-center rounded-xl bg-sage-600 text-primary-foreground">
                <Sparkles className="size-4" />
              </span>
              <div>
                <h3 className="text-sm font-semibold">{t("parent.adv_title")}</h3>
                <p className="text-[10px] font-semibold uppercase tracking-widest text-sage-600">{t("pro.badge")}</p>
              </div>
            </div>
            {!settings.isPro && (
              <button
                onClick={() => setProOpen(true)}
                className="rounded-xl bg-sage-600 px-3 py-2 text-xs font-semibold text-primary-foreground"
              >
                {t("pro.upgrade")}
              </button>
            )}
          </div>
          <p className="mt-2 text-xs text-sage-600">{t("parent.adv_sub")}</p>
          <ul className="mt-3 space-y-2">
            {["parent.adv1", "parent.adv2", "parent.adv3"].map((k) => (
              <li key={k} className="flex items-center justify-between rounded-xl bg-sage-50 px-3 py-2 text-xs">
                <span className="font-medium text-sage-900">{t(k)}</span>
                {settings.isPro ? (
                  <button
                    onClick={() => toast.success(t(k))}
                    className="text-[11px] font-semibold text-sage-700"
                  >
                    {t("settings.connect")}
                  </button>
                ) : (
                  <Lock className="size-3.5 text-sage-600" />
                )}
              </li>
            ))}
          </ul>
        </section>
      </div>
      <ProUpgradeDialog open={proOpen} onOpenChange={setProOpen} />

      <ChildEditDialog
        open={editing !== null}
        initial={editing}
        isNew={isNew}
        onOpenChange={(o) => !o && setEditing(null)}
        onSave={save}
      />
    </AppShell>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl bg-sage-50 p-3 ring-1 ring-black/5">
      <p className="text-sm font-semibold tabular-nums">{value}</p>
      <p className="text-[10px] font-medium uppercase tracking-wider text-sage-600">{label}</p>
    </div>
  );
}

function ageFromBirthday(b: string, t: (k: string, vars?: Record<string, string | number>) => string) {
  if (!b) return "—";
  const d = new Date(b);
  if (Number.isNaN(d.getTime())) return "—";
  const diff = Date.now() - d.getTime();
  const age = Math.floor(diff / (365.25 * 24 * 60 * 60 * 1000));
  return t("parent.age", { n: age });
}

function mockSteps(id: string) {
  // Stable per-child pseudo-random for today
  let h = 0;
  const seed = id + new Date().toDateString();
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) | 0;
  return 3000 + Math.abs(h % 7000);
}

function ChildEditDialog({
  open, initial, isNew, onOpenChange, onSave,
}: {
  open: boolean;
  initial: ChildProfile | null;
  isNew: boolean;
  onOpenChange: (o: boolean) => void;
  onSave: (c: ChildProfile) => void;
}) {
  const { t } = useT();
  const [draft, setDraft] = useState<ChildProfile | null>(initial);

  useEffect(() => {
    if (open && initial) setDraft(initial);
  }, [open, initial]);

  if (!draft) return null;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{isNew ? t("parent.child.new") : t("parent.child.edit")}</DialogTitle>
          <DialogDescription>{t("parent.child.code_help")}</DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-2">
          <div>
            <label className="mb-1.5 block text-[11px] font-medium uppercase tracking-wider text-sage-600">
              {t("parent.child.avatar")}
            </label>
            <div className="flex flex-wrap gap-2">
              {AVATAR_OPTIONS.map((a) => (
                <button
                  key={a}
                  type="button"
                  onClick={() => setDraft({ ...draft, avatar: a })}
                  className={`grid h-10 w-10 place-items-center rounded-xl text-xl ring-1 transition-colors ${
                    draft.avatar === a ? "bg-sage-600 ring-sage-700" : "bg-sage-50 ring-black/5"
                  }`}
                >
                  {a}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="mb-1.5 block text-[11px] font-medium uppercase tracking-wider text-sage-600">
              {t("auth.name")}
            </label>
            <input
              value={draft.name}
              onChange={(e) => setDraft({ ...draft, name: e.target.value })}
              className="w-full rounded-2xl bg-sage-50 px-4 py-3 text-sm ring-1 ring-black/5 outline-none focus:ring-sage-600"
            />
          </div>

          <div>
            <label className="mb-1.5 block text-[11px] font-medium uppercase tracking-wider text-sage-600">
              {t("auth.birthday")}
            </label>
            <input
              type="date"
              value={draft.birthday}
              onChange={(e) => setDraft({ ...draft, birthday: e.target.value })}
              className="w-full rounded-2xl bg-sage-50 px-4 py-3 text-sm ring-1 ring-black/5 outline-none focus:ring-sage-600"
            />
          </div>

          <div>
            <label className="mb-1.5 flex items-center justify-between text-[11px] font-medium uppercase tracking-wider text-sage-600">
              <span>{t("parent.child.daily_goal")}</span>
              <span className="tabular-nums text-sage-700">{draft.dailyGoal.toLocaleString()}</span>
            </label>
            <Slider
              value={[draft.dailyGoal]}
              min={2000}
              max={20000}
              step={500}
              onValueChange={(v) => setDraft({ ...draft, dailyGoal: v[0] })}
            />
          </div>

          <div className="rounded-2xl bg-sage-600 px-4 py-3 text-primary-foreground">
            <p className="text-[10px] font-semibold uppercase tracking-widest opacity-80">
              {t("parent.child.code")}
            </p>
            <p className="mt-1 text-2xl font-semibold tracking-[0.3em]">{draft.code}</p>
          </div>
        </div>

        <DialogFooter>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>{t("settings.cancel")}</Button>
          <Button onClick={() => onSave(draft)}>{t("parent.child.save")}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
