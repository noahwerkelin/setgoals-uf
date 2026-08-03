import { useMemo, useState } from "react";
import { CheckCircle2, ClipboardList, Pencil, Plus, Trash2, XCircle } from "lucide-react";
import { toast } from "sonner";
import { useT } from "@/lib/i18n";
import { localDayKey } from "@/lib/day";
import {
  createTask,
  deleteTask,
  formatReward,
  isOverdue,
  updateTask,
  useTasks,
  type RepeatSchedule,
  type Task,
  type TaskPriority,
  type TaskStatus,
} from "@/lib/tasks";
import { approveTask, rejectTask } from "@/lib/tasks.functions";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

const FILTERS: (TaskStatus | "all" | "overdue")[] = ["all", "pending", "submitted", "approved", "rejected", "overdue"];

export function StatusPill({ status, overdue }: { status: TaskStatus; overdue?: boolean }) {
  const { t } = useT();
  const cls = overdue
    ? "bg-red-100 text-red-700"
    : status === "approved"
      ? "bg-emerald-100 text-emerald-700"
      : status === "submitted"
        ? "bg-amber-100 text-amber-800"
        : status === "rejected"
          ? "bg-red-100 text-red-700"
          : status === "expired"
            ? "bg-sage-100 text-sage-600"
            : "bg-sage-100 text-sage-700";
  return (
    <span className={`rounded-full px-2.5 py-1 text-[10px] font-semibold ${cls}`}>
      {t(overdue ? "tasks.status.overdue" : `tasks.status.${status}`)}
    </span>
  );
}

/** Parent-side task manager for one child. */
export function ChildTasksSection({
  childId,
  childName,
  parentId,
  canAssign,
}: {
  childId: string;
  childName: string;
  parentId: string;
  canAssign: boolean;
}) {
  const { t } = useT();
  const { tasks } = useTasks({ childId });
  const [editing, setEditing] = useState<Task | "new" | null>(null);
  const [reviewing, setReviewing] = useState<Task | null>(null);
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>("all");

  const list = tasks ?? [];
  const visible = list.filter((x) =>
    filter === "all" ? true : filter === "overdue" ? isOverdue(x) : x.status === filter,
  );
  const weekStats = useMemo(() => {
    const since = Date.now() - 7 * 86_400_000;
    const done = list.filter((x) => x.status === "approved" && new Date(x.approved_at ?? x.updated_at).getTime() >= since);
    return { count: done.length, minutes: done.reduce((s, x) => s + x.reward_minutes, 0) };
  }, [list]);
  const awaiting = list.filter((x) => x.status === "submitted").length;

  return (
    <div className="mt-3 rounded-2xl bg-sage-50 p-4 ring-1 ring-sage-200">
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <ClipboardList className="size-4 text-sage-700" />
          <p className="text-xs font-semibold text-sage-900">{t("tasks.title")}</p>
        </div>
        {awaiting > 0 && (
          <span className="rounded-full bg-amber-100 px-2.5 py-1 text-[10px] font-semibold text-amber-800">
            {t("tasks.awaiting", { n: awaiting })}
          </span>
        )}
      </div>

      <p className="mt-1 text-[11px] text-sage-600">
        {t("tasks.week_summary", { n: weekStats.count, m: weekStats.minutes })}
      </p>

      <div className="mt-3 flex gap-1.5 overflow-x-auto pb-1">
        {FILTERS.map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`shrink-0 rounded-full px-2.5 py-1 text-[10px] font-semibold ${
              filter === f ? "bg-sage-600 text-white" : "bg-white text-sage-700 ring-1 ring-sage-200"
            }`}
          >
            {t(`tasks.filter.${f}`)}
          </button>
        ))}
      </div>

      <div className="mt-3 space-y-2">
        {visible.length === 0 && <p className="text-[11px] text-sage-600">{t("tasks.empty_parent")}</p>}
        {visible.map((task) => (
          <div key={task.id} className="rounded-2xl bg-white p-3 ring-1 ring-sage-200">
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0">
                <p className="truncate text-sm font-semibold text-sage-900">{task.title}</p>
                <p className="mt-0.5 text-[11px] text-sage-600">
                  +{formatReward(task.reward_minutes)}
                  {task.due_date ? ` · ${task.due_date}` : ""}
                  {task.repeat_schedule !== "none" ? ` · ${t(`tasks.repeat.${task.repeat_schedule}`)}` : ""}
                </p>
              </div>
              <StatusPill status={task.status} overdue={isOverdue(task)} />
            </div>

            {task.status === "submitted" ? (
              <div className="mt-2 flex gap-2">
                <button
                  onClick={() => setReviewing(task)}
                  className="flex-1 rounded-xl bg-sage-600 px-3 py-2 text-[11px] font-semibold text-white"
                >
                  {t("tasks.review")}
                </button>
              </div>
            ) : (
              <div className="mt-2 flex gap-2">
                <button
                  onClick={() => setEditing(task)}
                  className="flex flex-1 items-center justify-center gap-1 rounded-xl bg-sage-50 px-3 py-2 text-[11px] font-semibold text-sage-700 ring-1 ring-sage-200"
                >
                  <Pencil className="size-3.5" /> {t("tasks.edit")}
                </button>
                <button
                  onClick={async () => {
                    try {
                      await deleteTask(task.id);
                    } catch (e) {
                      toast.error((e as Error).message);
                    }
                  }}
                  aria-label={t("tasks.delete")}
                  className="grid size-9 place-items-center rounded-xl bg-sage-50 text-sage-700 ring-1 ring-sage-200"
                >
                  <Trash2 className="size-3.5" />
                </button>
              </div>
            )}
          </div>
        ))}
      </div>

      <button
        disabled={!canAssign}
        onClick={() => setEditing("new")}
        className="mt-3 flex w-full items-center justify-center gap-1.5 rounded-xl bg-sage-600 px-3 py-2 text-xs font-semibold text-white disabled:opacity-50"
      >
        <Plus className="size-4" /> {canAssign ? t("tasks.new") : t("tasks.needs_join")}
      </button>

      <TaskEditDialog
        open={editing !== null}
        task={editing === "new" ? null : editing}
        parentId={parentId}
        childId={childId}
        onClose={() => setEditing(null)}
      />
      <ReviewDialog task={reviewing} childName={childName} onClose={() => setReviewing(null)} />
    </div>
  );
}

function TaskEditDialog({
  open,
  task,
  parentId,
  childId,
  onClose,
}: {
  open: boolean;
  task: Task | null;
  parentId: string;
  childId: string;
  onClose: () => void;
}) {
  const { t } = useT();
  const [title, setTitle] = useState("");
  const [desc, setDesc] = useState("");
  const [reward, setReward] = useState(30);
  const [due, setDue] = useState("");
  const [repeat, setRepeat] = useState<RepeatSchedule>("none");
  const [interval, setIntervalDays] = useState(2);
  const [priority, setPriority] = useState<TaskPriority>("normal");
  const [busy, setBusy] = useState(false);
  const [seed, setSeed] = useState<string | null>(null);

  // Reset the form whenever a different task (or "new") is opened.
  const key = task?.id ?? (open ? "new" : "closed");
  if (open && seed !== key) {
    setSeed(key);
    setTitle(task?.title ?? "");
    setDesc(task?.description ?? "");
    setReward(task?.reward_minutes ?? 30);
    setDue(task?.due_date ?? "");
    setRepeat(task?.repeat_schedule ?? "none");
    setIntervalDays(task?.repeat_interval_days ?? 2);
    setPriority(task?.priority ?? "normal");
  }
  if (!open && seed !== "closed") setSeed("closed");

  const save = async () => {
    if (!title.trim()) return;
    setBusy(true);
    try {
      if (task) {
        await updateTask(task.id, {
          title: title.trim(),
          description: desc.trim() || null,
          reward_minutes: reward,
          due_date: due || null,
          repeat_schedule: repeat,
          repeat_interval_days: repeat === "custom" ? interval : null,
          priority,
        });
      } else {
        await createTask({
          parentId,
          childId,
          title: title.trim(),
          description: desc.trim(),
          rewardMinutes: reward,
          dueDate: due || null,
          repeatSchedule: repeat,
          repeatIntervalDays: interval,
          priority,
        });
      }
      onClose();
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-h-[85vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{t(task ? "tasks.edit_title" : "tasks.new_title")}</DialogTitle>
          <DialogDescription>{t("tasks.new_sub")}</DialogDescription>
        </DialogHeader>

        <div className="space-y-3">
          <div>
            <Label htmlFor="task-title">{t("tasks.field.title")}</Label>
            <Input id="task-title" value={title} onChange={(e) => setTitle(e.target.value)} maxLength={80} />
          </div>
          <div>
            <Label htmlFor="task-desc">{t("tasks.field.desc")}</Label>
            <Input id="task-desc" value={desc} onChange={(e) => setDesc(e.target.value)} maxLength={200} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label htmlFor="task-reward">{t("tasks.field.reward")}</Label>
              <Input
                id="task-reward"
                type="number"
                min={0}
                max={600}
                step={5}
                value={reward}
                onChange={(e) => setReward(Math.max(0, Math.min(600, Number(e.target.value) || 0)))}
              />
            </div>
            <div>
              <Label htmlFor="task-due">{t("tasks.field.due")}</Label>
              <Input id="task-due" type="date" value={due} onChange={(e) => setDue(e.target.value)} />
            </div>
          </div>

          <div>
            <Label>{t("tasks.field.priority")}</Label>
            <div className="mt-1 grid grid-cols-3 gap-1.5">
              {(["low", "normal", "high"] as TaskPriority[]).map((p) => (
                <button
                  key={p}
                  onClick={() => setPriority(p)}
                  className={`rounded-xl px-2 py-2 text-[11px] font-semibold ${
                    priority === p ? "bg-sage-600 text-white" : "bg-sage-50 text-sage-700 ring-1 ring-sage-200"
                  }`}
                >
                  {t(`tasks.priority.${p}`)}
                </button>
              ))}
            </div>
          </div>

          <div>
            <Label>{t("tasks.field.repeat")}</Label>
            <div className="mt-1 grid grid-cols-4 gap-1.5">
              {(["none", "daily", "weekly", "custom"] as RepeatSchedule[]).map((r) => (
                <button
                  key={r}
                  onClick={() => setRepeat(r)}
                  className={`rounded-xl px-2 py-2 text-[11px] font-semibold ${
                    repeat === r ? "bg-sage-600 text-white" : "bg-sage-50 text-sage-700 ring-1 ring-sage-200"
                  }`}
                >
                  {t(`tasks.repeat.${r}`)}
                </button>
              ))}
            </div>
            {repeat === "custom" && (
              <div className="mt-2">
                <Label htmlFor="task-interval">{t("tasks.field.interval")}</Label>
                <Input
                  id="task-interval"
                  type="number"
                  min={1}
                  max={365}
                  value={interval}
                  onChange={(e) => setIntervalDays(Math.max(1, Math.min(365, Number(e.target.value) || 1)))}
                />
              </div>
            )}
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t("settings.cancel")}
          </Button>
          <Button onClick={save} disabled={busy || !title.trim()}>
            {t("tasks.save")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function ReviewDialog({ task, childName, onClose }: { task: Task | null; childName: string; onClose: () => void }) {
  const { t } = useT();
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);

  const doApprove = async () => {
    if (!task) return;
    setBusy(true);
    try {
      const res = await approveTask({ data: { taskId: task.id, day: localDayKey() } });
      toast.success(t("tasks.approved_toast", { m: res.minutes }));
      onClose();
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  const doReject = async () => {
    if (!task) return;
    setBusy(true);
    try {
      await rejectTask({ data: { taskId: task.id, reason: reason.trim() || undefined } });
      setReason("");
      onClose();
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={!!task} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-h-[85vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{t("tasks.review_title")}</DialogTitle>
          <DialogDescription>
            {t("tasks.review_sub", { name: childName || "—", title: task?.title ?? "" })}
          </DialogDescription>
        </DialogHeader>

        {task && (
          <div className="space-y-3">
            <p className="rounded-2xl bg-sage-50 p-3 text-xs text-sage-700 ring-1 ring-sage-200">
              {t("tasks.reward_label")}: <span className="font-semibold">+{formatReward(task.reward_minutes)}</span>
            </p>
            {task.proof_note && (
              <p className="rounded-2xl bg-sage-50 p-3 text-xs text-sage-700 ring-1 ring-sage-200">{task.proof_note}</p>
            )}
            {task.proof_image_url && (
              <img
                src={task.proof_image_url}
                alt={t("tasks.proof_alt")}
                className="w-full rounded-2xl object-cover ring-1 ring-sage-200"
              />
            )}
            <div>
              <Label htmlFor="reject-reason">{t("tasks.reject_reason")}</Label>
              <Input id="reject-reason" value={reason} onChange={(e) => setReason(e.target.value)} maxLength={280} />
            </div>
          </div>
        )}

        <DialogFooter>
          <Button variant="outline" onClick={doReject} disabled={busy}>
            <XCircle className="size-4" /> {t("tasks.reject")}
          </Button>
          <Button onClick={doApprove} disabled={busy}>
            <CheckCircle2 className="size-4" /> {t("tasks.approve")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
