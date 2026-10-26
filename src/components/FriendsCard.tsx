import { useState } from "react";
import { UserPlus, Users, X, Search, Check, Clock } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useT } from "@/lib/i18n";
import { useFriends, type Friend } from "@/lib/friends";
import { searchUsersByUsername } from "@/lib/friends.functions";
import type { PublicUser } from "@/lib/friends.functions";
import { useQuery } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { toast } from "sonner";

export function FriendsCard() {
  const { t } = useT();
  const { friends, requests, addFriend, removeFriend, respondRequest, busy } = useFriends();
  const [open, setOpen] = useState(false);

  const visible = friends;

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
        <Button
          type="button"
          onClick={() => setOpen(true)}
          className="inline-flex items-center gap-1 rounded-full bg-sage-600 px-3 py-1.5 text-[11px] font-semibold text-primary-foreground"
        >
          <UserPlus className="size-3.5" />
          {t("friends.add")}
        </Button>
      </div>

      {requests.length > 0 && (
        <div className="mt-4 space-y-2">
          <p className="text-xs font-semibold text-muted-foreground">{t("friends.requests")}</p>
          {requests.map((r) => (
            <div key={r.id} className="flex items-center gap-2 rounded-xl bg-muted/60 p-2.5">
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium">{r.name}</p>
                <p className="truncate text-[11px] text-muted-foreground">@{r.username}</p>
                {r.direction === "outgoing" && <p className="flex items-center gap-1 text-[11px] text-muted-foreground"><Clock className="size-3" />{t("friends.pending")}</p>}
              </div>
              {r.direction === "incoming" && <Button variant="ghost" size="icon" disabled={busy}
                aria-label={`${t("friends.accept")} @${r.username}`} title={t("friends.accept")}
                onClick={() => respondRequest(r.id, true).catch(() => toast.error(t("friends.error")))}><Check className="size-4" /></Button>}
              <Button variant="ghost" size="icon" disabled={busy}
                aria-label={`${t(r.direction === "incoming" ? "friends.decline" : "friends.cancel")} @${r.username}`}
                title={t(r.direction === "incoming" ? "friends.decline" : "friends.cancel")}
                onClick={() => respondRequest(r.id, false).catch(() => toast.error(t("friends.error")))}><X className="size-4" /></Button>
            </div>
          ))}
        </div>
      )}

      {friends.length === 0 ? (
        <p className="mt-4 rounded-2xl bg-sage-50 p-4 text-center text-xs text-sage-600">
          {t("friends.empty")}
        </p>
      ) : (
        <ul className="mt-4 space-y-2">
          {visible.map((f) => (
            <li
              key={f.friend_id}
              className="flex items-center gap-3 rounded-2xl bg-sage-50/60 p-2.5 pl-3"
            >
              <span className="grid size-9 place-items-center rounded-full bg-sage-200 text-xs font-semibold uppercase text-sage-700">
                {f.name[0]}
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium">{f.name}</p>
                <p className="truncate text-[11px] text-sage-600">@{f.username}</p>
              </div>
              <Button
                type="button"
                disabled={busy}
                title={t("friends.remove")}
                onClick={() => removeFriend(f.friend_id).catch(() => toast.error(t("friends.error")))}
                aria-label={`${t("friends.remove")} @${f.username}`}
                className="grid size-8 place-items-center rounded-full text-sage-600 hover:bg-sage-100"
              >
                <X className="size-3.5" />
              </Button>
            </li>
          ))}
        </ul>
      )}

      <AddFriendDialog
        open={open}
        onOpenChange={setOpen}
        existing={friends}
        pending={requests.map((r) => r.username)}
        onAdd={async (u) => {
          const ok = await addFriend(u);
          if (ok) toast.success(t("friends.sent", { name: u.name }));
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
  pending,
  onAdd,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  existing: Friend[];
  pending: string[];
  onAdd: (f: PublicUser) => Promise<void>;
}) {
  const { t } = useT();
  const [q, setQ] = useState("");
  const [adding, setAdding] = useState(false);
  const search = useServerFn(searchUsersByUsername);
  const query = q.trim();
  const { data: found = [], isFetching, isError } = useQuery({
    queryKey: ["user-search", query.toLowerCase()],
    enabled: open && query.length >= 2,
    queryFn: () => search({ data: { query } }),
  });
  const taken = new Set([...existing.map((f) => f.username.toLowerCase()), ...pending.map((u) => u.toLowerCase())]);
  const results: PublicUser[] = found.filter((u) => !taken.has(u.username.toLowerCase()));

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
          ) : isFetching ? (
            <div className="flex justify-center py-4"><Search className="size-4 animate-pulse text-muted-foreground" /></div>
          ) : isError ? (
            <p className="px-1 py-4 text-center text-xs text-muted-foreground">{t("pro.error")}</p>
          ) : results.length === 0 ? (
            <p className="px-1 py-4 text-center text-xs text-sage-600">{t("friends.search.no_results")}</p>
          ) : (
            results.map((u) => (
              <Button
                variant="ghost"
                key={u.id}
                type="button"
                disabled={adding}
                onClick={async () => {
                  setAdding(true);
                  try {
                    await onAdd(u);
                    setQ("");
                  } catch { toast.error(t("pro.error")); }
                  finally { setAdding(false); }
                }}
                aria-label={`${t("friends.send")} @${u.username}`}
                title={t("friends.send")}
                className="flex h-auto w-full items-center gap-3 rounded-2xl bg-sage-50/60 p-2.5 pl-3 text-left hover:bg-sage-100"
              >
                <span className="grid size-9 place-items-center rounded-full bg-sage-200 text-xs font-semibold uppercase text-sage-700">
                  {u.name[0]}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">{u.name}</p>
                  <p className="truncate text-[11px] text-sage-600">@{u.username}</p>
                </div>
                <UserPlus className="size-4 text-sage-600" />
              </Button>
            ))
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
