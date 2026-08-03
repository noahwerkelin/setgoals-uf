import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const DayInput = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .optional();

function safeDay(day?: string): string {
  const now = new Date();
  const utcDay = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}-${String(now.getUTCDate()).padStart(2, "0")}`;
  if (!day) return utcDay;
  const within =
    Math.abs(new Date(`${day}T00:00:00Z`).getTime() - new Date(`${utcDay}T00:00:00Z`).getTime()) <= 86_400_000;
  return within ? day : utcDay;
}

function nextDueDate(from: string | null, schedule: string, intervalDays: number | null): string | null {
  const base = from ? new Date(`${from}T00:00:00Z`) : new Date();
  const days = schedule === "daily" ? 1 : schedule === "weekly" ? 7 : (intervalDays ?? 1);
  const next = new Date(base.getTime() + days * 86_400_000);
  return `${next.getUTCFullYear()}-${String(next.getUTCMonth() + 1).padStart(2, "0")}-${String(next.getUTCDate()).padStart(2, "0")}`;
}

const ApproveInput = z.object({
  taskId: z.string().uuid(),
  day: DayInput,
});

/**
 * Parent-only: approve a submitted task. The reward minutes are added to the
 * child's daily screen-time balance — this is the ONLY path that grants a task
 * reward, so a child can never award themselves screen time.
 * Recurring tasks are automatically regenerated for their next occurrence.
 */
export const approveTask = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => ApproveInput.parse(d))
  .handler(async ({ data, context }): Promise<{ ok: true; minutes: number }> => {
    const { supabase, userId } = context;

    const { data: task, error } = await supabase
      .from("tasks")
      .select("*")
      .eq("id", data.taskId)
      .maybeSingle();
    if (error) throw error;
    if (!task || task.parent_id !== userId) throw new Error("Not found");
    if (task.status !== "submitted") throw new Error("This task is not awaiting approval.");
    const childUserId = task.child_user_id as string | null;
    if (!childUserId) throw new Error("This child hasn't joined yet.");

    const { data: updated, error: upErr } = await supabase
      .from("tasks")
      .update({ status: "approved", approved_at: new Date().toISOString(), rejection_reason: null })
      .eq("id", task.id)
      .eq("status", "submitted")
      .select("id")
      .maybeSingle();
    if (upErr) throw upErr;
    // Prevents a double reward if two approvals race.
    if (!updated) throw new Error("This task was already reviewed.");

    const minutes = task.reward_minutes as number;
    if (minutes > 0) {
      const day = safeDay(data.day);
      const { data: existing, error: readErr } = await supabase
        .from("earned_balances")
        .select("bonus_min")
        .eq("user_id", childUserId)
        .eq("day", day)
        .maybeSingle();
      if (readErr) throw readErr;

      const bonusMin = (existing?.bonus_min ?? 0) + minutes;
      if (existing) {
        const { error: balErr } = await supabase
          .from("earned_balances")
          .update({ bonus_min: bonusMin, updated_at: new Date().toISOString() })
          .eq("user_id", childUserId)
          .eq("day", day);
        if (balErr) throw balErr;
      } else {
        const { error: insErr } = await supabase
          .from("earned_balances")
          .insert({ user_id: childUserId, day, bonus_min: bonusMin });
        if (insErr) throw insErr;
      }

      await supabase.from("screentime_grants").insert({
        parent_id: userId,
        child_user_id: childUserId,
        day,
        minutes,
        note: `Task: ${task.title}`,
      });
    }

    const schedule = task.repeat_schedule as string;
    if (schedule && schedule !== "none") {
      await supabase.from("tasks").insert({
        parent_id: userId,
        child_id: task.child_id,
        title: task.title,
        description: task.description,
        reward_minutes: minutes,
        due_date: nextDueDate(task.due_date as string | null, schedule, task.repeat_interval_days as number | null),
        repeat_schedule: schedule,
        repeat_interval_days: task.repeat_interval_days,
        priority: task.priority,
      });
    }

    return { ok: true, minutes };
  });

const RejectInput = z.object({
  taskId: z.string().uuid(),
  reason: z.string().trim().max(280).optional(),
});

/** Parent-only: reject a submitted task, optionally with a reason for the child. */
export const rejectTask = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => RejectInput.parse(d))
  .handler(async ({ data, context }): Promise<{ ok: true }> => {
    const { supabase, userId } = context;
    const { data: updated, error } = await supabase
      .from("tasks")
      .update({ status: "rejected", rejection_reason: data.reason || null, approved_at: null })
      .eq("id", data.taskId)
      .eq("parent_id", userId)
      .eq("status", "submitted")
      .select("id")
      .maybeSingle();
    if (error) throw error;
    if (!updated) throw new Error("This task is not awaiting approval.");
    return { ok: true };
  });
