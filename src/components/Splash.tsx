import { useEffect, useState } from "react";
import { Footprints } from "lucide-react";
import { useT } from "@/lib/i18n";

const SHOWN_KEY = "sg.splash.shown";
const DURATION_MS = 2500;

export function Splash() {
  const { t } = useT();
  const [visible, setVisible] = useState(false);
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    if (typeof window === "undefined") return;
    if (sessionStorage.getItem(SHOWN_KEY)) return;
    sessionStorage.setItem(SHOWN_KEY, "1");
    setVisible(true);
    const t1 = setTimeout(() => setLeaving(true), DURATION_MS - 400);
    const t2 = setTimeout(() => setVisible(false), DURATION_MS);
    return () => {
      clearTimeout(t1);
      clearTimeout(t2);
    };
  }, []);

  if (!visible) return null;

  return (
    <div
      aria-hidden
      className="fixed inset-0 z-[100] grid place-items-center overflow-hidden"
      style={{
        background:
          "radial-gradient(120% 80% at 50% 30%, var(--sage-100) 0%, var(--sage-50) 55%, var(--sage-200) 100%)",
        opacity: leaving ? 0 : 1,
        transition: "opacity 400ms cubic-bezier(0.16, 1, 0.3, 1)",
      }}
    >
      {/* Soft orbiting rings */}
      <div className="pointer-events-none absolute inset-0 grid place-items-center">
        <div
          className="absolute rounded-full"
          style={{
            width: 460,
            height: 460,
            border: "1px solid color-mix(in oklab, var(--sage-600) 18%, transparent)",
            animation: "splash-pulse 2.4s ease-out forwards",
          }}
        />
        <div
          className="absolute rounded-full"
          style={{
            width: 320,
            height: 320,
            border: "1px solid color-mix(in oklab, var(--sage-600) 28%, transparent)",
            animation: "splash-pulse 2.4s ease-out 120ms forwards",
          }}
        />
      </div>

      <div
        className="relative flex flex-col items-center"
        style={{ animation: "splash-rise 700ms cubic-bezier(0.16, 1, 0.3, 1) both" }}
      >
        <div
          className="grid size-24 place-items-center rounded-[28px] text-primary-foreground shadow-[0_20px_60px_-20px_color-mix(in_oklab,var(--sage-700)_55%,transparent)]"
          style={{
            background:
              "linear-gradient(140deg, var(--sage-500) 0%, var(--sage-700) 100%)",
          }}
        >
          <Footprints className="size-11" strokeWidth={1.75} />
        </div>

        <h1
          className="mt-7 text-3xl font-semibold tracking-tight text-sage-950"
          style={{ animation: "splash-rise 700ms cubic-bezier(0.16, 1, 0.3, 1) 120ms both" }}
        >
          SetGoals
        </h1>
        <p
          className="mt-2 text-sm text-sage-700"
          style={{ animation: "splash-rise 700ms cubic-bezier(0.16, 1, 0.3, 1) 240ms both" }}
        >
          {t("splash.tagline")}
        </p>

        <div
          className="mt-10 h-[3px] w-24 overflow-hidden rounded-full bg-sage-200"
          style={{ animation: "splash-rise 700ms cubic-bezier(0.16, 1, 0.3, 1) 360ms both" }}
        >
          <div
            className="h-full w-full origin-left rounded-full bg-sage-600"
            style={{ animation: "splash-bar 1100ms cubic-bezier(0.65, 0, 0.35, 1) 360ms both" }}
          />
        </div>
      </div>

      <style>{`
        @keyframes splash-rise {
          from { opacity: 0; transform: translateY(10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @keyframes splash-pulse {
          0% { opacity: 0; transform: scale(0.7); }
          60% { opacity: 1; }
          100% { opacity: 0; transform: scale(1.15); }
        }
        @keyframes splash-bar {
          from { transform: scaleX(0); }
          to { transform: scaleX(1); }
        }
      `}</style>
    </div>
  );
}
