type Props = {
  progress: number; // 0..1
  size?: number;
  stroke?: number;
  className?: string;
  trackClassName?: string;
  ringClassName?: string;
  children?: React.ReactNode;
};

export function ProgressRing({
  progress,
  size = 224,
  stroke = 14,
  className,
  trackClassName = "text-sage-100",
  ringClassName = "text-sage-600",
  children,
}: Props) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const offset = c * (1 - Math.max(0, Math.min(1, progress)));
  return (
    <div className={`relative ${className ?? ""}`} style={{ width: size, height: size }}>
      <svg width={size} height={size} className="-rotate-90">
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          strokeWidth={stroke}
          className={trackClassName}
          stroke="currentColor"
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          strokeWidth={stroke}
          strokeLinecap="round"
          className={`${ringClassName} animate-ring-draw`}
          stroke="currentColor"
          strokeDasharray={c}
          style={{ ["--from" as never]: c, ["--to" as never]: offset, strokeDashoffset: offset }}
        />
      </svg>
      <div className="absolute inset-0 flex items-center justify-center">{children}</div>
    </div>
  );
}
