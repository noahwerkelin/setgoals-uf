import { createFileRoute } from "@tanstack/react-router";
import { Shield, Plus, Lock, Sparkles, Copy, Pencil, Trash2, Clock, Smartphone, Infinity as InfinityIcon, Zap, Link2, Share2, RefreshCw } from "lucide-react";
import { useEffect, useState } from "react";
import { Switch } from "@/components/ui/switch";
import { AppShell, PageHeader } from "@/components/AppShell";
import { useT } from "@/lib/i18n";
import { useSettings, emptyChild, type ChildProfile } from "@/lib/settings";
import { issueChildCode, deleteChild } from "@/lib/children.functions";
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
import { supabase } from "@/integrations/supabase/client";

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
const INITIAL_APPS: { key: string; state: AppState }[] = [
  { key: "cat.social", state: "blocked" },
  { key: "cat.games", state: "blocked" },
  { key: "cat.entertainment", state: "blocked" },
  { key: "cat.creativity", state: "approved" },
  { key: "cat.productivity", state: "approved" },
  { key: "cat.education", state: "approved" },
  { key: "cat.health", state: "approved" },
  { key: "cat.shopping", state: "blocked" },
  { key: "cat.utilities", state: "approved" },
];

const AVATAR_OPTIONS = ["🌱", "🌳", "🐻", "🦊", "🐼", "🦁", "🐸", "🦄", "⭐️", "🚀"];

type ScreenTimeEdit = { stepsPer30: number; dailyCapHours: number };

function Page() {
  const { t } = useT();
  const { settings, update, refresh } = useSettings();
  const [apps, setApps] = useState(INITIAL_APPS);
  const [proOpen, setProOpen] = useState(false);
  const [editing, setEditing] = useState<ChildProfile | null>(null);
  const [isNew, setIsNew] = useState(false);
  const [editingChildST, setEditingChildST] = useState<ChildProfile | null>(null);
  const [editingMyST, setEditingMyST] = useState(false);
  const [tab, setTab] = useState<"personal" | "children">("personal");
  const [childStats, setChildStats] = useState<Record<string, { steps: number; usedMin: number }>>({});
  const [childWeek, setChildWeek] = useState<Record<string, Record<string, { steps: number; usedMin: number }>>>({});

  const isIndividual = settings.role === "individual";
  const isChild = settings.role === "child";
  const canManageChildren = !isChild;

  useEffect(() => {
    if (typeof window === "undefined") return;
    const applyHash = () => {
      if (window.location.hash === "#children" && canManageChildren) setTab("children");
    };
    applyHash();
    window.addEventListener("hashchange", applyHash);
    return () => window.removeEventListener("hashchange", applyHash);
  }, [canManageChildren]);

  // Live child activity for today (RLS lets a parent read their linked child's rows).
  const linkedIds = settings.children.map((c) => c.authUserId).filter((v): v is string => !!v);
  const linkedKey = linkedIds.join(",");
  useEffect(() => {
    if (!linkedIds.length) {
      setChildStats({});
      setChildWeek({});
      return;
    }
    let cancelled = false;
    const today = new Date();
    const fmt = (d: Date) =>
      `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    const day = fmt(today);
    const weekStartDate = new Date(today);
    weekStartDate.setDate(weekStartDate.getDate() - 6);
    const weekStart = fmt(weekStartDate);
    const load = async () => {
      const [act, bal] = await Promise.all([
        supabase.from("activity_steps").select("user_id, day, steps").gte("day", weekStart).lte("day", day).in("user_id", linkedIds),
        supabase.from("earned_balances").select("user_id, day, consumed_min").gte("day", weekStart).lte("day", day).in("user_id", linkedIds),
      ]);
      if (cancelled) return;
      const map: Record<string, { steps: number; usedMin: number }> = {};
      const week: Record<string, Record<string, { steps: number; usedMin: number }>> = {};
      for (const id of linkedIds) {
        map[id] = { steps: 0, usedMin: 0 };
        week[id] = {};
      }
      for (const r of act.data ?? []) {
        const w = (week[r.user_id] ??= {});
        const cell = (w[r.day] ??= { steps: 0, usedMin: 0 });
        cell.steps += r.steps ?? 0;
        if (r.day === day) map[r.user_id] = { ...map[r.user_id], steps: (map[r.user_id]?.steps ?? 0) + (r.steps ?? 0) };
      }
      for (const r of bal.data ?? []) {
        const w = (week[r.user_id] ??= {});
        const cell = (w[r.day] ??= { steps: 0, usedMin: 0 });
        cell.usedMin = r.consumed_min ?? 0;
        if (r.day === day) map[r.user_id] = { ...map[r.user_id], usedMin: r.consumed_min ?? 0 };
      }
      setChildStats(map);
      setChildWeek(week);
    };
    void load();
    const channel = supabase
      .channel("parent-child-activity")
      .on("postgres_changes", { event: "*", schema: "public", table: "activity_steps" }, () => void load())
      .on("postgres_changes", { event: "*", schema: "public", table: "earned_balances" }, () => void load())
      .subscribe();
    return () => {
      cancelled = true;
      void supabase.removeChannel(channel);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [linkedKey]);

  const setState = (key: string, state: AppState) => {
    setApps((a) => a.map((x) => (x.key === key ? { ...x, state } : x)));
    toast.success(`${t(key)}: ${state === "approved" ? "✓" : "✕"}`);
  };

  const openNew = () => {
    setEditing({ ...emptyChild(), avatar: AVATAR_OPTIONS[0] });
    setIsNew(true);
  };

  const openEdit = (c: ChildProfile) => {
    setEditing({ ...c });
    setIsNew(false);
  };

  const save = async (c: ChildProfile) => {
    if (!c.name.trim() || c.username.trim().length < 3) {
      toast.error(t("parent.child.username_required"));
      return;
    }
    if (settings.children.some((x) => x.id !== c.id && x.username.toLowerCase() === c.username.toLowerCase())) {
      toast.error(t("parent.child.username_taken"));
      return;
    }
    if (isNew) {
      await update("children", [...settings.children, c]);
      try {
        await issueChildCode({ data: { childId: c.id } });
      } catch {
        /* code stays as generated locally */
      }
      await refresh();
      toast.success(t("parent.child.created"));
    } else {
      await update("children", settings.children.map((x) => (x.id === c.id ? c : x)));
      toast.success(t("parent.child.updated"));
    }
    setEditing(null);
  };

  const regenerate = async (c: ChildProfile) => {
    try {
      const r = await issueChildCode({ data: { childId: c.id } });
      await refresh();
      toast.success(t("parent.child.code_new", { c: r.code }));
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Error");
    }
  };

  const shareCode = async (c: ChildProfile) => {
    const text = t("parent.child.share_text", { n: c.name || "", c: c.code });
    if (typeof navigator !== "undefined" && navigator.share) {
      try {
        await navigator.share({ text });
        return;
      } catch {
        /* cancelled */
      }
    }
    copyCode(c.code);
  };

  const remove = async (child: ChildProfile, password: string): Promise<boolean> => {
    try {
      await deleteChild({ data: { childId: child.id, password } });
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Error";
      toast.error(/password/i.test(msg) ? t("delete.wrong_password") : msg);
      return false;
    }
    await update("children", settings.children.filter((c) => c.id !== child.id));
    await refresh();
    toast.success(t("parent.child.removed"));
    return true;
  };


  const saveChildST = (id: string, v: ScreenTimeEdit) => {
    update(
      "children",
      settings.children.map((c) => (c.id === id ? { ...c, ...v } : c)),
    );
    toast.success(t("parent.child.updated"));
  };

  const saveMyST = (v: ScreenTimeEdit) => {
    update("stepsPer30", v.stepsPer30);
    update("dailyCapHours", v.dailyCapHours);
    toast.success(t("account.updated"));
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
        eyebrow={isIndividual ? t("screentime.eyebrow") : t("parent.eyebrow")}
        title={isIndividual ? t("screentime.title") : t("parent.title")}
        trailing={
          <span className="grid size-10 place-items-center rounded-full bg-sage-100 text-sage-700">
            {isIndividual ? <Clock className="size-4" /> : <Shield className="size-4" />}
          </span>
        }
      />
      <div className="px-6 space-y-6">
        {canManageChildren && (
          <div
            role="tablist"
            aria-label={t("parent.title")}
            className="grid grid-cols-2 gap-1 rounded-2xl bg-sage-100 p-1"
          >
            {(["personal", "children"] as const).map((k) => {
              const active = tab === k;
              return (
                <button
                  key={k}
                  role="tab"
                  aria-selected={active}
                  onClick={() => {
                    setTab(k);
                    if (typeof window !== "undefined") {
                      const nextHash = k === "children" ? "#children" : "";
                      history.replaceState(null, "", window.location.pathname + nextHash);
                    }
                  }}
                  className={`rounded-xl px-3 py-2 text-xs font-semibold transition-colors ${
                    active ? "bg-card text-sage-900 shadow-sm" : "text-sage-700 hover:text-sage-900"
                  }`}
                >
                  {t(k === "personal" ? "parent.tab.personal" : "parent.tab.children")}
                </button>
              );
            })}
          </div>
        )}

        {(!canManageChildren || tab === "personal") && (
          <>
            {/* My screen time */}
            <section className="rounded-3xl bg-card p-5 ring-1 ring-black/5">
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-3">
                  <span className="grid size-9 place-items-center rounded-xl bg-sage-100 text-sage-700">
                    <Clock className="size-4" />
                  </span>
                  <div>
                    <h3 className="text-sm font-semibold">{t("parent.my_screentime")}</h3>
                    <p className="text-xs text-sage-600">{t("parent.my_screentime_sub")}</p>
                  </div>
                </div>
              </div>
              <div className="mt-4 grid grid-cols-2 gap-3">
                <Stat label={t("parent.steps_per_30")} value={settings.stepsPer30.toLocaleString()} />
                <Stat label={t("parent.daily_cap")} value={settings.dailyCapHours >= 24 ? t("parent.no_cap") : `${settings.dailyCapHours}${t("settings.hours")}`} />
              </div>
              {isChild ? (
                <p className="mt-4 rounded-xl bg-sage-50 px-3 py-2 text-[11px] text-sage-600 ring-1 ring-sage-200">
                  {t("parent.child_locked")}
                </p>
              ) : (
                <button
                  onClick={() => setEditingMyST(true)}
                  className="mt-4 w-full rounded-xl bg-sage-100 px-3 py-2 text-xs font-semibold text-sage-700"
                >
                  {t("parent.edit_screentime")}
                </button>
              )}
            </section>

            <section className="space-y-3">
              <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">
                <span className="inline-flex items-center gap-1.5">
                  <Smartphone className="size-3.5" /> {t("parent.apps")}
                </span>
              </h2>
              <p className="px-1 text-[11px] text-sage-600">{t("stmode.hint")}</p>
              <div className="rounded-3xl bg-card ring-1 ring-black/5 overflow-hidden">
                {apps.map((a, i) => (
                  <div
                    key={a.key}
                    className={`flex items-center justify-between gap-3 p-4 ${i > 0 ? "border-t border-sage-100" : ""}`}
                  >
                    <span className="text-sm font-medium truncate">{t(a.key)}</span>
                    <CategoryToggle
                      value={a.state}
                      onChange={(next) => !isChild && setState(a.key, next)}
                      labelAlways={t("stmode.always_short")}
                      labelEarned={t("stmode.earned_short")}
                      ariaAlways={t("stmode.always") + " — " + t(a.key)}
                      ariaEarned={t("stmode.earned") + " — " + t(a.key)}
                    />
                  </div>
                ))}
              </div>
            </section>

            {!isChild && <ProScreenTimeSection isPro={settings.isPro} onUpgrade={() => setProOpen(true)} categoryKeys={apps.map((a) => a.key)} />}
          </>
        )}

        {canManageChildren && tab === "children" && (
          <section className="space-y-3">
            <h2 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{t("parent.children")}</h2>

            {settings.children.length === 0 && (
              <p className="rounded-3xl bg-card p-5 text-center text-xs text-sage-600 ring-1 ring-black/5">
                {t("parent.child.empty")}
              </p>
            )}

            {settings.children.map((k, i) => {
              const stats = (k.authUserId && childStats[k.authUserId]) || { steps: 0, usedMin: 0 };
              const usedH = Math.floor(stats.usedMin / 60);
              const usedM = stats.usedMin % 60;
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
                      onClick={() => setDeleting(k)}
                      aria-label={t("parent.child.delete")}
                      className="grid size-8 place-items-center rounded-full bg-sage-100 text-sage-700"
                    >
                      <Trash2 className="size-3.5" />
                    </button>
                  </div>

                  <div className="mt-4 grid grid-cols-3 gap-3 text-center">
                    <Stat label={t("parent.steps")} value={stats.steps.toLocaleString()} />
                    <Stat label={t("parent.child.daily_goal")} value={k.dailyGoal.toLocaleString()} />
                    <Stat
                      label={t("parent.used_screentime")}
                      value={usedH > 0 ? `${usedH}${t("settings.hours")} ${usedM}m` : `${usedM}m`}
                    />
                  </div>

                  <WeeklySummary week={(k.authUserId && childWeek[k.authUserId]) || {}} />

                  <div className="mt-4 rounded-2xl bg-sage-50 p-4 ring-1 ring-sage-200">
                    <div className="flex items-center gap-2">
                      <Clock className="size-4 text-sage-700" />
                      <p className="text-xs font-semibold text-sage-900">
                        {t("parent.child_screentime", { n: k.name || "—" })}
                      </p>
                    </div>
                    <div className="mt-3 grid grid-cols-2 gap-3">
                      <Stat label={t("parent.steps_per_30")} value={k.stepsPer30.toLocaleString()} />
                      <Stat label={t("parent.daily_cap")} value={k.dailyCapHours >= 24 ? t("parent.no_cap") : `${k.dailyCapHours}${t("settings.hours")}`} />
                    </div>
                    <button
                      onClick={() => setEditingChildST(k)}
                      className="mt-3 w-full rounded-xl bg-white px-3 py-2 text-xs font-semibold text-sage-700 ring-1 ring-sage-200"
                    >
                      {t("parent.edit_screentime")}
                    </button>
                  </div>

                  {k.invitationStatus === "connected" ? (
                    <div className="mt-4 flex items-center gap-2 rounded-2xl bg-sage-50 px-4 py-3 ring-1 ring-sage-200">
                      <Link2 className="size-4 text-sage-700" />
                      <p className="text-xs font-semibold text-sage-900">{t("parent.child.status_connected")}</p>
                    </div>
                  ) : (
                    <>
                      <div className="mt-4 rounded-2xl bg-sage-50 px-4 py-3 ring-1 ring-sage-200">
                        <div className="flex items-center justify-between gap-3">
                          <div className="text-left min-w-0">
                            <p className="text-[10px] font-semibold uppercase tracking-widest text-sage-600">
                              {t("parent.child.code")}
                            </p>
                            <p className="text-base font-semibold tracking-[0.2em] text-sage-900">{k.code}</p>
                          </div>
                          <span
                            className={`rounded-full px-2.5 py-1 text-[10px] font-semibold ${
                              k.invitationStatus === "expired"
                                ? "bg-red-100 text-red-700"
                                : "bg-amber-100 text-amber-800"
                            }`}
                          >
                            {t(
                              k.invitationStatus === "expired"
                                ? "parent.child.status_expired"
                                : "parent.child.status_pending",
                            )}
                          </span>
                        </div>
                        <div className="mt-3 grid grid-cols-3 gap-2">
                          <button
                            onClick={() => copyCode(k.code)}
                            className="flex items-center justify-center gap-1 rounded-xl bg-white px-2 py-2 text-[11px] font-semibold text-sage-700 ring-1 ring-sage-200"
                          >
                            <Copy className="size-3.5" /> {t("parent.child.copy")}
                          </button>
                          <button
                            onClick={() => shareCode(k)}
                            className="flex items-center justify-center gap-1 rounded-xl bg-white px-2 py-2 text-[11px] font-semibold text-sage-700 ring-1 ring-sage-200"
                          >
                            <Share2 className="size-3.5" /> {t("parent.child.share")}
                          </button>
                          <button
                            onClick={() => regenerate(k)}
                            className="flex items-center justify-center gap-1 rounded-xl bg-sage-600 px-2 py-2 text-[11px] font-semibold text-primary-foreground"
                          >
                            <RefreshCw className="size-3.5" /> {t("parent.child.regenerate")}
                          </button>
                        </div>
                      </div>
                      <p className="mt-1 px-1 text-[10px] text-sage-600">{t("parent.child.code_help")}</p>
                    </>
                  )}

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
        )}

      </div>
      <ProUpgradeDialog open={proOpen} onOpenChange={setProOpen} />

      <ChildEditDialog
        open={editing !== null}
        initial={editing}
        isNew={isNew}
        onOpenChange={(o) => !o && setEditing(null)}
        onSave={save}
      />

      <ScreenTimeDialog
        open={editingMyST}
        onOpenChange={setEditingMyST}
        title={t("parent.my_screentime")}
        initial={{ stepsPer30: settings.stepsPer30, dailyCapHours: settings.dailyCapHours }}
        onSave={saveMyST}
      />

      <ScreenTimeDialog
        open={editingChildST !== null}
        onOpenChange={(o) => !o && setEditingChildST(null)}
        title={
          editingChildST
            ? t("parent.child_screentime", { n: editingChildST.name || "—" })
            : t("parent.edit_screentime")
        }
        initial={
          editingChildST
            ? { stepsPer30: editingChildST.stepsPer30, dailyCapHours: editingChildST.dailyCapHours }
            : { stepsPer30: 1000, dailyCapHours: 3 }
        }
        onSave={(v) => editingChildST && saveChildST(editingChildST.id, v)}
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

function WeeklySummary({ week }: { week: Record<string, { steps: number; usedMin: number }> }) {
  const { t, lang } = useT();
  const today = new Date();
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(today);
    d.setDate(d.getDate() - (6 - i));
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    return { d, key, ...(week[key] ?? { steps: 0, usedMin: 0 }) };
  });
  const maxSteps = Math.max(1, ...days.map((x) => x.steps));
  const totalSteps = days.reduce((s, x) => s + x.steps, 0);
  const totalMin = days.reduce((s, x) => s + x.usedMin, 0);
  const fmtMin = (m: number) => (m >= 60 ? `${Math.floor(m / 60)}${t("settings.hours")} ${m % 60}m` : `${m}m`);

  return (
    <div className="mt-4 rounded-2xl bg-sage-50 p-4 ring-1 ring-sage-200">
      <div className="flex items-baseline justify-between gap-2">
        <p className="text-xs font-semibold text-sage-900">{t("parent.week_summary")}</p>
        <p className="text-[10px] font-medium text-sage-600">
          {totalSteps.toLocaleString()} {t("parent.steps").toLowerCase()} · {fmtMin(totalMin)}
        </p>
      </div>
      <div className="mt-3 grid grid-cols-7 gap-1.5">
        {days.map((x) => (
          <div key={x.key} className="flex flex-col items-center gap-1">
            <div className="flex h-16 w-full items-end justify-center rounded-lg bg-white/70 ring-1 ring-sage-200">
              <div
                className="w-2.5 rounded-full bg-sage-500"
                style={{ height: `${Math.max(4, Math.round((x.steps / maxSteps) * 56))}px` }}
              />
            </div>
            <p className="text-[9px] font-semibold uppercase text-sage-700">
              {x.d.toLocaleDateString(lang === "sv" ? "sv-SE" : "en-US", { weekday: "narrow" })}
            </p>
            <p className="text-[9px] tabular-nums text-sage-600">{x.steps ? x.steps.toLocaleString() : "—"}</p>
            <p className="text-[9px] tabular-nums text-sage-500">{x.usedMin ? fmtMin(x.usedMin) : "—"}</p>
          </div>
        ))}
      </div>
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


function ScreenTimeDialog({
  open, onOpenChange, title, initial, onSave,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  title: string;
  initial: ScreenTimeEdit;
  onSave: (v: ScreenTimeEdit) => void;
}) {
  const { t } = useT();
  const [steps, setSteps] = useState(initial.stepsPer30);
  const [cap, setCap] = useState(initial.dailyCapHours);
  const [rolloverOn, setRolloverOn] = useState(false);

  useEffect(() => {
    if (open) {
      setSteps(initial.stepsPer30);
      setCap(initial.dailyCapHours);
      const pst = loadProST();
      setRolloverOn(pst.rollover);
    }
  }, [open, initial.stepsPer30, initial.dailyCapHours]);


  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>{t("parent.rules_sub", { steps: steps.toLocaleString(), cap: cap >= 24 ? "∞" : cap, carry: t(rolloverOn ? "parent.rules_carry_on" : "parent.rules_carry_off") })}</DialogDescription>
        </DialogHeader>
        <div className="space-y-6 py-2">
          <div>
            <label className="mb-1.5 flex items-center justify-between text-[11px] font-medium uppercase tracking-wider text-sage-600">
              <span>{t("parent.steps_per_30")}</span>
              <span className="tabular-nums text-sage-700">{steps.toLocaleString()}</span>
            </label>
            <Slider
              value={[steps]}
              min={200}
              max={3000}
              step={100}
              onValueChange={(v) => setSteps(v[0])}
            />
          </div>
          <div>
            <label className="mb-1.5 flex items-center justify-between text-[11px] font-medium uppercase tracking-wider text-sage-600">
              <span>{t("parent.daily_cap")}</span>
              <span className="tabular-nums text-sage-700">{cap >= 24 ? t("parent.no_cap") : `${cap}${t("settings.hours")}`}</span>
            </label>
            <Slider
              value={[cap >= 24 ? 9 : cap]}
              min={1}
              max={9}
              step={1}
              onValueChange={(v) => setCap(v[0] >= 9 ? 24 : v[0])}
            />
          </div>
          {rolloverOn && (
            <div className="flex items-start gap-2 rounded-2xl bg-sage-50 p-3 ring-1 ring-sage-200">
              <Sparkles className="mt-0.5 size-4 shrink-0 text-sage-700" />
              <p className="text-xs text-sage-700">{t("parent.rollover_on")}</p>
            </div>
          )}
        </div>

        <DialogFooter>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>{t("settings.cancel")}</Button>
          <Button onClick={() => { onSave({ stepsPer30: steps, dailyCapHours: cap }); onOpenChange(false); }}>
            {t("settings.save")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
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
              {t("settings.username")}
            </label>
            <div className="flex items-center gap-2 rounded-2xl bg-sage-50 px-4 ring-1 ring-black/5 focus-within:ring-sage-600">
              <span className="text-sm text-sage-600">@</span>
              <input
                value={draft.username}
                onChange={(e) =>
                  setDraft({
                    ...draft,
                    username: e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, "").slice(0, 20),
                  })
                }
                placeholder="lukas_08"
                autoCapitalize="none"
                autoCorrect="off"
                className="w-full bg-transparent py-3 text-sm outline-none"
              />
            </div>
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

          <div>
            <label className="mb-1.5 flex items-center justify-between text-[11px] font-medium uppercase tracking-wider text-sage-600">
              <span>{t("parent.steps_per_30")}</span>
              <span className="tabular-nums text-sage-700">{draft.stepsPer30.toLocaleString()}</span>
            </label>
            <Slider
              value={[draft.stepsPer30]}
              min={200}
              max={3000}
              step={100}
              onValueChange={(v) => setDraft({ ...draft, stepsPer30: v[0] })}
            />
          </div>

          <div>
            <label className="mb-1.5 flex items-center justify-between text-[11px] font-medium uppercase tracking-wider text-sage-600">
              <span>{t("parent.daily_cap")}</span>
              <span className="tabular-nums text-sage-700">{draft.dailyCapHours}{t("settings.hours")}</span>
            </label>
            <Slider
              value={[draft.dailyCapHours]}
              min={1}
              max={8}
              step={1}
              onValueChange={(v) => setDraft({ ...draft, dailyCapHours: v[0] })}
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


function CategoryToggle({
  value,
  onChange,
  labelAlways,
  labelEarned,
  ariaAlways,
  ariaEarned,
}: {
  value: AppState;
  onChange: (next: AppState) => void;
  labelAlways: string;
  labelEarned: string;
  ariaAlways: string;
  ariaEarned: string;
}) {
  const isAlways = value === "approved";
  return (
    <div
      role="radiogroup"
      className="relative inline-flex shrink-0 items-center rounded-full bg-sage-50 p-1 ring-1 ring-black/5"
    >
      <span
        aria-hidden
        className={`absolute top-1 bottom-1 w-[calc(50%-4px)] rounded-full shadow-sm transition-all duration-300 ease-out ${
          isAlways ? "left-1 bg-sage-600" : "left-1/2 bg-amber-500"
        }`}
      />
      <button
        type="button"
        role="radio"
        aria-checked={isAlways}
        aria-label={ariaAlways}
        onClick={() => onChange("approved")}
        className={`relative z-10 flex items-center gap-1 rounded-full px-3 py-1.5 text-[11px] font-semibold transition-colors ${
          isAlways ? "text-white" : "text-sage-700"
        }`}
      >
        <InfinityIcon className="size-3.5" />
        <span>{labelAlways}</span>
      </button>
      <button
        type="button"
        role="radio"
        aria-checked={!isAlways}
        aria-label={ariaEarned}
        onClick={() => onChange("blocked")}
        className={`relative z-10 flex items-center gap-1 rounded-full px-3 py-1.5 text-[11px] font-semibold transition-colors ${
          !isAlways ? "text-white" : "text-sage-700"
        }`}
      >
        <Zap className="size-3.5" />
        <span>{labelEarned}</span>
      </button>
    </div>
  );
}

import { loadProST, saveProST, DEFAULT_PRO_ST, type ProST } from "@/lib/screentime";


function ProScreenTimeSection({
  isPro,
  onUpgrade,
  categoryKeys,
}: {
  isPro: boolean;
  onUpgrade: () => void;
  categoryKeys: string[];
}) {
  const { t } = useT();
  const [state, setState] = useState<ProST>(DEFAULT_PRO_ST);

  useEffect(() => {
    setState(loadProST());
  }, []);

  const save = (next: ProST) => {
    setState(next);
    saveProST(next);
  };


  const disabled = !isPro;

  return (
    <section className={`rounded-3xl p-5 ring-1 ${isPro ? "bg-card ring-black/5" : "bg-sage-50 ring-sage-200"} space-y-4`}>
      <div className="flex items-start justify-between gap-3">
        <div className="flex items-center gap-2 min-w-0">
          <span className="grid size-8 shrink-0 place-items-center rounded-xl bg-sage-600 text-primary-foreground">
            <Sparkles className="size-4" />
          </span>
          <div className="min-w-0">
            <h3 className="text-sm font-semibold truncate">{t("pro.st.title")}</h3>
            <p className="text-[10px] font-semibold uppercase tracking-widest text-sage-600">{t("pro.badge")}</p>
          </div>
        </div>
        {!isPro && (
          <button
            onClick={onUpgrade}
            className="shrink-0 rounded-xl bg-sage-600 px-3 py-2 text-xs font-semibold text-primary-foreground"
          >
            {t("pro.upgrade")}
          </button>
        )}
      </div>
      <p className="text-xs text-sage-600">{t("pro.st.sub")}</p>

      <div className={`space-y-2 ${disabled ? "pointer-events-none opacity-60" : ""}`} aria-disabled={disabled}>
        <ToggleRow
          label={t("pro.st.rollover")}
          sub={t("pro.st.rollover_sub")}
          checked={state.rollover}
          onCheckedChange={(v) => save({ ...state, rollover: v })}
          locked={disabled}
        />
        <ToggleRow
          label={t("pro.st.weekend2x")}
          sub={t("pro.st.weekend2x_sub")}
          checked={state.weekend2x}
          onCheckedChange={(v) => save({ ...state, weekend2x: v })}
          locked={disabled}
        />
        <ToggleRow
          label={t("pro.st.split_caps")}
          sub={t("pro.st.split_caps_sub")}
          checked={state.splitCaps}
          onCheckedChange={(v) => save({ ...state, splitCaps: v })}
          locked={disabled}
        />

        {state.splitCaps && (
          <div className="space-y-3 rounded-2xl bg-sage-50 p-4 ring-1 ring-sage-200">
            <CapSlider
              label={t("pro.st.weekday_cap")}
              value={state.weekdayCap}
              onChange={(v) => save({ ...state, weekdayCap: v })}
              suffix={t("settings.hours")}
            />
            <CapSlider
              label={t("pro.st.weekend_cap")}
              value={state.weekendCap}
              onChange={(v) => save({ ...state, weekendCap: v })}
              suffix={t("settings.hours")}
            />
          </div>
        )}

        <div className="rounded-2xl bg-sage-50 p-4 ring-1 ring-sage-200">
          <div className="flex items-center gap-2">
            <Clock className="size-3.5 text-sage-700" />
            <p className="text-xs font-semibold text-sage-900">{t("pro.st.cat_limits")}</p>
          </div>
          <p className="mt-1 text-[11px] text-sage-600">{t("pro.st.cat_limits_sub")}</p>
          <div className="mt-3 space-y-3">
            {categoryKeys.map((k) => {
              const v = state.catLimits[k] ?? 0;
              return (
                <div key={k}>
                  <div className="mb-1.5 flex items-center justify-between text-[11px] font-medium text-sage-700">
                    <span>{t(k)}</span>
                    <span className="tabular-nums">
                      {v === 0 ? t("pro.st.no_limit") : `${v} min`}
                    </span>
                  </div>
                  <Slider
                    value={[v]}
                    min={0}
                    max={240}
                    step={15}
                    onValueChange={(val) =>
                      save({ ...state, catLimits: { ...state.catLimits, [k]: val[0] } })
                    }
                  />
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {!isPro && (
        <div className="flex items-center justify-center gap-1.5 rounded-2xl bg-white/60 px-3 py-2 text-[11px] font-medium text-sage-700 ring-1 ring-sage-200">
          <Lock className="size-3.5" /> {t("pro.st.unlock")}
        </div>
      )}
    </section>
  );
}

function ToggleRow({
  label,
  sub,
  checked,
  onCheckedChange,
  locked,
}: {
  label: string;
  sub: string;
  checked: boolean;
  onCheckedChange: (v: boolean) => void;
  locked: boolean;
}) {
  return (
    <div className="flex items-center justify-between gap-3 rounded-2xl bg-sage-50 px-4 py-3 ring-1 ring-sage-200">
      <div className="min-w-0 flex-1">
        <p className="text-xs font-semibold text-sage-900">{label}</p>
        <p className="text-[11px] text-sage-600">{sub}</p>
      </div>
      {locked ? (
        <Lock className="size-4 text-sage-500" />
      ) : (
        <Switch checked={checked} onCheckedChange={onCheckedChange} />
      )}
    </div>
  );
}

function CapSlider({
  label,
  value,
  onChange,
  suffix,
}: {
  label: string;
  value: number;
  onChange: (v: number) => void;
  suffix: string;
}) {
  return (
    <div>
      <label className="mb-1.5 flex items-center justify-between text-[11px] font-medium uppercase tracking-wider text-sage-600">
        <span>{label}</span>
        <span className="tabular-nums text-sage-700">
          {value}
          {suffix}
        </span>
      </label>
      <Slider value={[value]} min={1} max={8} step={1} onValueChange={(v) => onChange(v[0])} />
    </div>
  );
}
