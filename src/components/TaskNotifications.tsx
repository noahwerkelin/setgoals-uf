import { Bell } from "lucide-react";
import { useT } from "@/lib/i18n";
import { useTaskNotifications, type TaskNotification } from "@/lib/tasks";

function line(n: TaskNotification, t: (k: string, v?: Record<string, string | number>) => string): string {
  switch (n.type) {
    case "task_assigned":
      return t("tasks.notif.assigned", { title: n.title });
    case "task_submitted":
      return t("tasks.notif.submitted", { name: n.body || "", title: n.title });
    case "task_approved":
      return t("tasks.notif.approved", { title: n.title, m: n.body ?? "0" });
    case "task_rejected":
      return n.body
        ? t("tasks.notif.rejected_reason", { title: n.title, reason: n.body })
        : t("tasks.notif.rejected", { title: n.title });
    default:
      return n.title;
  }
}

/** Live task notification feed, shown to both parents and children. */
export function TaskNotificationsCard() {
  const { t } = useT();
  const { items, unread, markAllRead } = useTaskNotifications();
  if (items.length === 0) return null;

  return (
    <section className="rounded-3xl bg-white p-5 shadow-sm ring-1 ring-sage-100">
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <Bell className="size-4 text-sage-700" />
          <h2 className="text-sm font-semibold">{t("tasks.notif.title")}</h2>
          {unread > 0 && (
            <span className="rounded-full bg-sage-600 px-2 py-0.5 text-[10px] font-semibold text-white">{unread}</span>
          )}
        </div>
        {unread > 0 && (
          <button onClick={() => void markAllRead()} className="text-[11px] font-semibold text-sage-700">
            {t("tasks.notif.mark_read")}
          </button>
        )}
      </div>

      <ul className="mt-3 space-y-2">
        {items.slice(0, 6).map((n) => (
          <li
            key={n.id}
            className={`rounded-2xl p-3 text-xs ring-1 ${
              n.read_at ? "bg-white text-sage-600 ring-sage-100" : "bg-sage-50 text-sage-900 ring-sage-200"
            }`}
          >
            {line(n, t)}
          </li>
        ))}
      </ul>
    </section>
  );
}
