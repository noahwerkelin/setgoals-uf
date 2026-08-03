import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";

export type TaskStatus = "pending" | "submitted" | "approved" | "rejected" | "expired";
export type TaskPriority = "low" | "normal" | "high";
export type RepeatSchedule = "none" | "daily" | "weekly" | "custom";

export type Task = {
  id: string;
  parent_id: string;
  child_id: string;
  child_user_id: string | null;
  title: string;
  description: string | null;
  reward_minutes: number;
  status: TaskStatus;
  due_date: string | null;
  repeat_schedule: RepeatSchedule;
  repeat_interval_days: number | null;
  priority: TaskPriority;
  proof_image_url: string | null;
  proof_note: string | null;
  rejection_reason: string | null;
  submitted_at: string | null;
  approved_at: string | null;
  created_at: string;
  updated_at: string;
};

export type TaskNotification = {
  id: string;
  user_id: string;
  task_id: string | null;
  type: string;
  title: string;
  body: string | null;
  read_at: string | null;
  created_at: string;
};

export function isOverdue(t: Task): boolean {
  if (!t.due_date) return false;
  if (t.status === "approved" || t.status === "expired") return false;
  const end = new Date(`${t.due_date}T23:59:59`);
  return end.getTime() < Date.now();
}

export function formatReward(min: number): string {
  if (min < 60) return `${min} min`;
  const h = Math.floor(min / 60);
  const m = min % 60;
  return m ? `${h}h ${m}m` : `${h}h`;
}

/** Live list of tasks visible to the signed-in user (parent's own, or a child's assigned). */
export function useTasks(opts: { childId?: string; mine?: boolean } = {}) {
  const { childId, mine } = opts;
  const [tasks, setTasks] = useState<Task[] | null>(null);

  const load = useCallback(async () => {
    const { data: auth } = await supabase.auth.getUser();
    const uid = auth.user?.id;
    if (!uid) {
      setTasks([]);
      return;
    }
    let q = supabase.from("tasks").select("*").order("created_at", { ascending: false });
    if (mine) q = q.eq("child_user_id", uid);
    else if (childId) q = q.eq("child_id", childId);
    else q = q.eq("parent_id", uid);
    const { data } = await q;
    setTasks((data as Task[] | null) ?? []);
  }, [childId, mine]);

  useEffect(() => {
    void load();
    const channel = supabase
      .channel(`tasks-${mine ? "mine" : (childId ?? "all")}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "tasks" }, () => void load())
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [load, childId, mine]);

  return { tasks, reload: load };
}

/** Live notification feed for the signed-in user (parent or child). */
export function useTaskNotifications() {
  const [items, setItems] = useState<TaskNotification[]>([]);

  const load = useCallback(async () => {
    const { data: auth } = await supabase.auth.getUser();
    const uid = auth.user?.id;
    if (!uid) return;
    const { data } = await supabase
      .from("task_notifications")
      .select("*")
      .eq("user_id", uid)
      .order("created_at", { ascending: false })
      .limit(30);
    setItems((data as TaskNotification[] | null) ?? []);
  }, []);

  useEffect(() => {
    void load();
    const channel = supabase
      .channel("task-notifications")
      .on("postgres_changes", { event: "*", schema: "public", table: "task_notifications" }, () => void load())
      .subscribe();
    return () => {
      void supabase.removeChannel(channel);
    };
  }, [load]);

  const markAllRead = useCallback(async () => {
    const now = new Date().toISOString();
    const unread = items.filter((n) => !n.read_at).map((n) => n.id);
    if (!unread.length) return;
    await supabase.from("task_notifications").update({ read_at: now }).in("id", unread);
    void load();
  }, [items, load]);

  return { items, unread: items.filter((n) => !n.read_at).length, markAllRead, reload: load };
}

export async function createTask(input: {
  parentId: string;
  childId: string;
  title: string;
  description?: string;
  rewardMinutes: number;
  dueDate?: string | null;
  repeatSchedule: RepeatSchedule;
  repeatIntervalDays?: number | null;
  priority: TaskPriority;
}) {
  const { error } = await supabase.from("tasks").insert({
    parent_id: input.parentId,
    child_id: input.childId,
    title: input.title,
    description: input.description || null,
    reward_minutes: input.rewardMinutes,
    due_date: input.dueDate || null,
    repeat_schedule: input.repeatSchedule,
    repeat_interval_days: input.repeatSchedule === "custom" ? (input.repeatIntervalDays ?? 1) : null,
    priority: input.priority,
  });
  if (error) throw new Error(error.message);
}

export async function updateTask(
  id: string,
  patch: Partial<{
    title: string;
    description: string | null;
    reward_minutes: number;
    due_date: string | null;
    repeat_schedule: RepeatSchedule;
    repeat_interval_days: number | null;
    priority: TaskPriority;
    status: TaskStatus;
  }>,
) {
  const { error } = await supabase.from("tasks").update(patch).eq("id", id);
  if (error) throw new Error(error.message);
}

export async function deleteTask(id: string) {
  const { error } = await supabase.from("tasks").delete().eq("id", id);
  if (error) throw new Error(error.message);
}

/** Child-only: submit a task for parent approval. No screen time is granted here. */
export async function submitTask(id: string, proof: { note?: string; imageUrl?: string }) {
  const { error } = await supabase
    .from("tasks")
    .update({
      status: "submitted",
      proof_note: proof.note || null,
      proof_image_url: proof.imageUrl || null,
    })
    .eq("id", id);
  if (error) throw new Error(error.message);
}
