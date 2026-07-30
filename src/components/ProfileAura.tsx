type Props = {
  /** 0..1 — steps vs daily goal */
  activity: number;
  /** 0..1 — earned screen time vs daily cap */
  screen: number;
};

/**
 * Living gradient "thumbnail" behind the profile hero.
 * Uses only the active theme scale (--sage-*), so it follows whatever
 * color the user picked in settings. Blobs shift with time of day,
 * activity and screen-time usage.
 */
export function ProfileAura({ activity, screen }: Props) {
  const now = new Date();
  const dayProgress = (now.getHours() * 60 + now.getMinutes()) / 1440; // 0..1

  const a = Math.max(0, Math.min(1, activity));
  const s = Math.max(0, Math.min(1, screen));

  // Deeper + more saturated as the day fills up with activity.
  const deep = 0.35 + a * 0.45;
  const soft = 0.3 + s * 0.35;
  const light = 0.45 + (1 - dayProgress) * 0.3;

  // Blobs slide across the tile as the day advances.
  const x = dayProgress * 100;

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden>
      <div
        className="absolute inset-0"
        style={{ background: `linear-gradient(140deg, var(--sage-100), var(--sage-200))` }}
      />
      <div
        className="aura-blob aura-a"
        style={{
          width: `${55 + a * 35}%`,
          height: "150%",
          left: `${-15 + x * 0.4}%`,
          top: "-35%",
          background: `radial-gradient(circle at 50% 50%, color-mix(in oklab, var(--sage-500) ${Math.round(deep * 100)}%, transparent), transparent 70%)`,
        }}
      />
      <div
        className="aura-blob aura-b"
        style={{
          width: `${50 + s * 35}%`,
          height: "140%",
          right: `${-20 + (1 - dayProgress) * 25}%`,
          bottom: "-40%",
          background: `radial-gradient(circle at 50% 50%, color-mix(in oklab, var(--sage-700) ${Math.round(soft * 100)}%, transparent), transparent 70%)`,
        }}
      />
      <div
        className="aura-blob aura-c"
        style={{
          width: `${45 + a * 25}%`,
          height: "120%",
          left: `${25 + Math.sin(dayProgress * Math.PI) * 20}%`,
          top: "-25%",
          background: `radial-gradient(circle at 50% 50%, color-mix(in oklab, var(--sage-300) ${Math.round(light * 100)}%, transparent), transparent 70%)`,
        }}
      />
      {/* soften toward the card so content stays readable */}
      <div
        className="absolute inset-0"
        style={{
          background:
            "linear-gradient(to bottom, color-mix(in oklab, var(--card) 10%, transparent), color-mix(in oklab, var(--card) 55%, transparent))",
        }}
      />
    </div>
  );
}
