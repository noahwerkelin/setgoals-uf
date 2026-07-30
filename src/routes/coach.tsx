import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useRef, useState } from "react";
import { useServerFn } from "@tanstack/react-start";
import { Sparkles, Send } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";
import { useT } from "@/lib/i18n";
import { useSettings } from "@/lib/settings";
import { ProLockCard, ProUpgradeDialog } from "@/components/Pro";
import { coachChat } from "@/lib/coach.functions";
import { toast } from "sonner";

export const Route = createFileRoute("/coach")({
  head: () => ({
    meta: [
      { title: "AI Coach — SetGoals" },
      { name: "description", content: "Your wellness coach for goals, routes, and motivation." },
    ],
  }),
  component: Page,
});

type Msg = { role: "user" | "assistant"; content: string };

function Page() {
  const { t } = useT();
  const { settings } = useSettings();
  const sendChat = useServerFn(coachChat);
  const [msgs, setMsgs] = useState<Msg[]>([{ role: "assistant", content: t("coach.seed") }]);
  const [text, setText] = useState("");
  const [proOpen, setProOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const locRef = useRef<{ lat: number; lng: number } | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (typeof navigator === "undefined" || !navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      (p) => {
        locRef.current = { lat: p.coords.latitude, lng: p.coords.longitude };
      },
      () => {},
      { enableHighAccuracy: false, timeout: 6000, maximumAge: 1000 * 60 * 30 },
    );
  }, []);

  useEffect(() => {
    scrollRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [msgs, busy]);

  async function send(v: string) {
    const value = v.trim();
    if (!value || busy) return;
    const next: Msg[] = [...msgs, { role: "user", content: value }];
    setMsgs(next);
    setText("");
    setBusy(true);
    try {
      const res = await sendChat({
        data: {
          messages: next.map((m) => ({ role: m.role, content: m.content })),
          location: locRef.current ?? undefined,
        },
      });
      setMsgs((m) => [...m, { role: "assistant", content: res.reply }]);
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Coach is unavailable right now.";
      toast.error(msg);
      setMsgs((m) => [...m, { role: "assistant", content: "Sorry, I couldn't reach my brain just now. Try again in a moment." }]);
    } finally {
      setBusy(false);
    }
  }

  const suggestions = [t("coach.s1"), t("coach.s2"), t("coach.s3")];

  if (!settings.isPro) {
    return (
      <AppShell>
        <PageHeader
          eyebrow={t("coach.eyebrow")}
          title={t("coach.title")}
          trailing={
            <span className="grid size-10 place-items-center rounded-full bg-sage-600 text-primary-foreground">
              <Sparkles className="size-5" />
            </span>
          }
        />
        <div className="px-6">
          {settings.role === "child" ? (
            <div data-testid="coach-lock-child" className="rounded-3xl bg-card p-6 ring-1 ring-black/5 text-center space-y-3">
              <div className="mx-auto grid size-12 place-items-center rounded-2xl bg-sage-100 text-sage-700">
                <Sparkles className="size-6" />
              </div>
              <h3 className="text-base font-semibold">{t("coach.locked_title")}</h3>
              <p className="text-sm text-sage-600">{t("pro.child_desc")}</p>
            </div>
          ) : (
            <ProLockCard titleKey="coach.locked_title" descKey="coach.locked_desc" onUpgrade={() => setProOpen(true)} />
          )}
        </div>
        <ProUpgradeDialog open={proOpen} onOpenChange={setProOpen} />
      </AppShell>
    );
  }

  return (
    <AppShell>
      <PageHeader
        eyebrow={t("coach.eyebrow")}
        title={t("coach.title")}
        trailing={
          <span className="grid size-10 place-items-center rounded-full bg-sage-600 text-primary-foreground">
            <Sparkles className="size-5" />
          </span>
        }
      />
      <div className="flex flex-col gap-3 px-6 pb-40">
        {msgs.map((m, i) => (
          <div
            key={i}
            className={`max-w-[85%] whitespace-pre-wrap rounded-3xl px-4 py-3 text-sm animate-rise ${
              m.role === "assistant"
                ? "self-start bg-card text-sage-900 ring-1 ring-black/5 rounded-tl-md"
                : "self-end bg-sage-600 text-primary-foreground rounded-tr-md"
            }`}
          >
            {m.content}
          </div>
        ))}
        {busy && (
          <div className="self-start rounded-3xl rounded-tl-md bg-card px-4 py-3 text-sm text-sage-600 ring-1 ring-black/5">
            <span className="inline-flex gap-1">
              <span className="size-1.5 animate-bounce rounded-full bg-sage-500" />
              <span className="size-1.5 animate-bounce rounded-full bg-sage-500 [animation-delay:120ms]" />
              <span className="size-1.5 animate-bounce rounded-full bg-sage-500 [animation-delay:240ms]" />
            </span>
          </div>
        )}
        <div ref={scrollRef} />

        {msgs.length <= 1 && (
          <div className="mt-3 flex flex-wrap gap-2">
            {suggestions.map((s) => (
              <button
                key={s}
                onClick={() => send(s)}
                disabled={busy}
                className="rounded-full bg-card px-3 py-1.5 text-xs font-medium text-sage-700 ring-1 ring-black/5 disabled:opacity-50"
              >
                {s}
              </button>
            ))}
          </div>
        )}
      </div>

      <form
        onSubmit={(e) => { e.preventDefault(); send(text); }}
        className="fixed bottom-24 left-1/2 z-40 flex w-[calc(100%-32px)] max-w-md -translate-x-1/2 items-center gap-2 rounded-full bg-card p-1.5 pl-4 ring-1 ring-black/5 shadow-[0_10px_30px_-12px_rgb(0,0,0,0.15)]"
      >
        <label htmlFor="coach-input" className="sr-only">{t("coach.input_label")}</label>
        <input
          id="coach-input"
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder={t("coach.placeholder")}
          disabled={busy}
          className="flex-1 bg-transparent text-sm outline-none placeholder:text-sage-600 disabled:opacity-50"
        />
        <button
          type="submit"
          disabled={busy || !text.trim()}
          aria-label={t("coach.send")}
          className="grid size-10 place-items-center rounded-full bg-sage-600 text-primary-foreground disabled:opacity-50"
        >
          <Send className="size-4" />
        </button>
      </form>
    </AppShell>
  );
}
