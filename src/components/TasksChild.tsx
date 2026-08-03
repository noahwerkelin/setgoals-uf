import { useRef, useState } from "react";
import { ClipboardList, Camera } from "lucide-react";
import { toast } from "sonner";
import { useT } from "@/lib/i18n";
import { fileToSquareDataUrl } from "@/lib/avatar";
import { formatReward, isOverdue, submitTask, useTasks, type Task } from "@/lib/tasks";
import { StatusPill } from "@/components/TasksParent";
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

/** Child-side task list: view assigned tasks and submit them for parent approval. */
export function MyTasksCard() {
  const { t } = useT();
  const { tasks } = useTasks({ mine: true });
  const [submitting, setSubmitting] = useState<Task | null>(null);

  const list = tasks ?? [];
  if (list.length === 0) return null;

  const open = list.filter((x) => x.status !== "approved" && x.status !== "expired");
  const done = list.filter((x) => x.status === "approved");
  const earned = done.reduce((s, x) => s + x.reward_minutes, 0);

  return (
    <section className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-sage-100">
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <ClipboardList className="size-4 text-sage-700" />
          <h2 className="text-sm font-semibold">{t("tasks.child.title")}</h2>
        </div>
        {earned > 0 && (
          <span className="rounded-full bg-emerald-100 px-2.5 py-1 text-[10px] font-semibold text-emerald-700">
            {t("tasks.child.earned", { m: earned })}
          </span>
        )}
      </div>

      <div className="mt-3 space-y-2">
        {(open.length ? open : done).map((task) => (
          <div key={task.id} className="rounded-2xl bg-sage-50 p-3 ring-1 ring-sage-200">
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0">
                <p className="truncate text-sm font-semibold text-sage-900">{task.title}</p>
                {task.description && <p className="mt-0.5 text-[11px] text-sage-600">{task.description}</p>}
                <p className="mt-0.5 text-[11px] font-medium text-sage-700">
                  +{formatReward(task.reward_minutes)}
                  {task.due_date ? ` · ${task.due_date}` : ""}
                </p>
                {task.status === "rejected" && task.rejection_reason && (
                  <p className="mt-1 text-[11px] text-red-600">{task.rejection_reason}</p>
                )}
              </div>
              <StatusPill status={task.status} overdue={isOverdue(task)} />
            </div>

            {(task.status === "pending" || task.status === "rejected") && (
              <button
                onClick={() => setSubmitting(task)}
                className="mt-2 w-full rounded-xl bg-sage-600 px-3 py-2 text-[11px] font-semibold text-white"
              >
                {t("tasks.child.complete")}
              </button>
            )}
            {task.status === "submitted" && (
              <p className="mt-2 text-[11px] text-sage-600">{t("tasks.child.waiting")}</p>
            )}
          </div>
        ))}
      </div>

      <SubmitDialog task={submitting} onClose={() => setSubmitting(null)} />
    </section>
  );
}

function SubmitDialog({ task, onClose }: { task: Task | null; onClose: () => void }) {
  const { t } = useT();
  const [note, setNote] = useState("");
  const [photo, setPhoto] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  const pick = async (file: File | undefined) => {
    if (!file) return;
    try {
      setPhoto(await fileToSquareDataUrl(file, 480));
    } catch {
      toast.error(t("tasks.child.photo_error"));
    }
  };

  const send = async () => {
    if (!task) return;
    setBusy(true);
    try {
      await submitTask(task.id, { note: note.trim(), imageUrl: photo ?? undefined });
      setNote("");
      setPhoto(null);
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
          <DialogTitle>{t("tasks.child.submit_title")}</DialogTitle>
          <DialogDescription>{t("tasks.child.submit_sub", { title: task?.title ?? "" })}</DialogDescription>
        </DialogHeader>

        <div className="space-y-3">
          <div>
            <Label htmlFor="proof-note">{t("tasks.child.note")}</Label>
            <Input id="proof-note" value={note} onChange={(e) => setNote(e.target.value)} maxLength={200} />
          </div>
          {photo && <img src={photo} alt={t("tasks.proof_alt")} className="w-full rounded-2xl object-cover" />}
          <input
            ref={fileRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={(e) => void pick(e.target.files?.[0])}
          />
          <button
            onClick={() => fileRef.current?.click()}
            className="flex w-full items-center justify-center gap-1.5 rounded-xl bg-sage-50 px-3 py-2 text-xs font-semibold text-sage-700 ring-1 ring-sage-200"
          >
            <Camera className="size-4" /> {t("tasks.child.photo")}
          </button>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            {t("common.cancel")}
          </Button>
          <Button onClick={send} disabled={busy}>
            {t("tasks.child.send")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
