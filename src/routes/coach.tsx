import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Sparkles, Send } from "lucide-react";
import { AppShell, PageHeader } from "@/components/AppShell";

export const Route = createFileRoute("/coach")({
  head: () => ({
    meta: [
      { title: "AI Coach — SetGoals UF" },
      { name: "description", content: "Your wellness coach for goals, routes, and motivation." },
    ],
  }),
  component: Page,
});

type Msg = { from: "ai" | "me"; text: string };

const SEED: Msg[] = [
  {
    from: "ai",
    text:
      "Hi Lukas — you're 88% to today's goal. Want a 15-minute loop near Slottsskogen? It would unlock another 30 minutes of screen time.",
  },
];

const SUGGESTIONS = [
  "Suggest a short route nearby",
  "Why is my screen time low today?",
  "Make a goal for this weekend",
];

function Page() {
  const [msgs, setMsgs] = useState<Msg[]>(SEED);
  const [text, setText] = useState("");

  function send(t: string) {
    const v = t.trim();
    if (!v) return;
    setMsgs((m) => [
      ...m,
      { from: "me", text: v },
      {
        from: "ai",
        text:
          "Great — based on your patterns, I'd aim for 9,500 steps today. Try a 25-min walk after lunch and a short loop before dinner.",
      },
    ]);
    setText("");
  }

  return (
    <AppShell>
      <PageHeader
        eyebrow="Personal wellness"
        title="AI Coach"
        trailing={
          <span className="grid size-10 place-items-center rounded-full bg-sage-600 text-primary-foreground">
            <Sparkles className="size-5" />
          </span>
        }
      />
      <div className="flex flex-col gap-3 px-6">
        {msgs.map((m, i) => (
          <div
            key={i}
            className={`max-w-[85%] rounded-3xl px-4 py-3 text-sm animate-rise ${
              m.from === "ai"
                ? "self-start bg-card text-sage-900 ring-1 ring-black/5 rounded-tl-md"
                : "self-end bg-sage-600 text-primary-foreground rounded-tr-md"
            }`}
          >
            {m.text}
          </div>
        ))}

        <div className="mt-3 flex flex-wrap gap-2">
          {SUGGESTIONS.map((s) => (
            <button
              key={s}
              onClick={() => send(s)}
              className="rounded-full bg-card px-3 py-1.5 text-xs font-medium text-sage-700 ring-1 ring-black/5"
            >
              {s}
            </button>
          ))}
        </div>
      </div>

      <form
        onSubmit={(e) => {
          e.preventDefault();
          send(text);
        }}
        className="fixed bottom-24 left-1/2 z-40 flex w-[calc(100%-32px)] max-w-md -translate-x-1/2 items-center gap-2 rounded-full bg-card p-1.5 pl-4 ring-1 ring-black/5 shadow-[0_10px_30px_-12px_rgb(0,0,0,0.15)]"
      >
        <label htmlFor="coach-input" className="sr-only">
          Message the coach
        </label>
        <input
          id="coach-input"
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Ask anything…"
          className="flex-1 bg-transparent text-sm outline-none placeholder:text-sage-600"
        />
        <button
          type="submit"
          aria-label="Send"
          className="grid size-10 place-items-center rounded-full bg-sage-600 text-primary-foreground"
        >
          <Send className="size-4" />
        </button>
      </form>
    </AppShell>
  );
}
