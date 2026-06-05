import { useMemo, useState } from "react";
import { UserPlus, Users, X, Search } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { useT } from "@/lib/i18n";
import { searchUsers, useFriends, type Friend } from "@/lib/friends";
import { toast } from "sonner";

export function FriendsCard() {
  const { t } = useT();
  const { friends, addFriend, removeFriend } = useFriends();
  const [open, setOpen] = useState(false);

  const visible = friends.slice(0, 5);

  return (
    <section
      className="rounded-3xl bg-card p-5 ring-1 ring-black/5 animate-rise"
      style={{ animationDelay: "150ms" }}
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="grid size-8 place-items-center rounded-xl bg-sage-100 text-sage-700">
            <Users className="size-4" />
          </span>
          <div>
            <p className="text-sm font-semibold leading-tight">{t("friends.title")}</p>
            <p className="text-[11px] text-sage-600">{t("friends.count", { n: friends.length })}</p>
          </div>
        </div>
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="inline-flex items-center gap-1 rounded-full bg-sage-600 px-3 py-1.5 text-[11px] font-semibold text-primary-foreground"
        >
          <UserPlus className="size-3.5" />
          {t("friends.add")}
        </button>
      </div>

      {friends.length === 0 ? (
        <p className="mt-4 rounded-2xl bg-sage-50 p-4 text-center text-xs text-sage-600">
          {t("friends.empty")}
        </p>
      ) : (
        <ul className="mt-4 space-y-2">
          {visible.map((f) => (
            <li
              key={f.id}
              className="flex items-center gap-3 rounded-2xl bg-sage-50/60 p-2.5 pl-3"
            >
              <span className="grid size-9 place-items-center rounded-full bg-sage-200 text-xs font-semibold uppercase text-sage-700">
                {f.name[0]}
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium">{f.name}</p>
                <p className="truncate text-[11px] text-sage-600">@{f.username}</p>
              </div>
              <button
                type="button"
                onClick={() => removeFriend(f.id)}
                aria-label={t("friends.remove")}
                className="grid size-8 place-items-center rounded-full text-sage-600 hover:bg-sage-100"
              >
                <X className="size-3.5" />
              </button>
            </li>
          ))}
        </ul>
      )}

      <AddFriendDialog
        open={open}
        onOpenChange={setOpen}
        existing={friends}
        onAdd={(u) => {
          const ok = addFriend(u);
          if (ok) toast.success(t("friends.added", { name: u.name }));
          else toast(t("friends.already"));
        }}
      />
    </section>
  );
}

function AddFriendDialog({
  open,
  onOpenChange,
  existing,
  onAdd,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  existing: Friend[];
  onAdd: (f: Friend) => void;
}) {
  const { t } = useT();
  const [q, setQ] = useState("");
  const results = useMemo(() => {
    if (q.trim().length < 2) return [];
    return searchUsers(q, existing.map((f) => f.username));
  }, [q, existing]);

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!o) setQ("");
        onOpenChange(o);
      }}
    >
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t("friends.search.title")}</DialogTitle>
          <DialogDescription>{t("friends.search.desc")}</DialogDescription>
        </DialogHeader>
        <div className="relative">
          <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-sage-600" />
          <Input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder={t("friends.search.placeholder")}
            maxLength={20}
            autoFocus
            className="pl-9"
          />
        </div>
        <div className="mt-2 max-h-72 space-y-2 overflow-y-auto">
          {q.trim().length < 2 ? (
            <p className="px-1 py-4 text-center text-xs text-sage-600">{t("friends.search.hint")}</p>
          ) : results.length === 0 ? (
            <p className="px-1 py-4 text-center text-xs text-sage-600">{t("friends.search.no_results")}</p>
          ) : (
            results.map((u) => (
              <button
                key={u.id}
                type="button"
                onClick={() => {
                  onAdd(u);
                  setQ("");
                }}
                className="flex w-full items-center gap-3 rounded-2xl bg-sage-50/60 p-2.5 pl-3 text-left hover:bg-sage-100"
              >
                <span className="grid size-9 place-items-center rounded-full bg-sage-200 text-xs font-semibold uppercase text-sage-700">
                  {u.name[0]}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">{u.name}</p>
                  <p className="truncate text-[11px] text-sage-600">@{u.username}</p>
                </div>
                <UserPlus className="size-4 text-sage-600" />
              </button>
            ))
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
