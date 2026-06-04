import { useEffect, useMemo, useState } from "react";
import {
  Award, Footprints, Sunrise, Moon, Route as RouteIcon, Map as MapIcon,
  Compass, Mountain, Flame, Calendar, Infinity as InfinityIcon, MapPin,
  UserPlus, CheckCircle2, Trophy, Crown, Globe, Star, Medal, Bug, Lock,
  type LucideIcon,
} from "lucide-react";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { currentStreak, useSettings } from "@/lib/settings";

export type BadgeTier = "bronze" | "silver" | "gold" | "platinum";

export type BadgeDef = {
  id: string;
  tier: BadgeTier;
  name: string;
  desc: string;
  icon: LucideIcon;
  group: string;
};

const BADGES: BadgeDef[] = [
  { id: "first_steps", tier: "bronze", name: "First Steps", desc: "Walk 1,000 steps in a day", icon: Footprints, group: "Daily steps" },
  { id: "daily_walker", tier: "silver", name: "Daily Walker", desc: "Walk 5,000 steps in a day", icon: Footprints, group: "Daily steps" },
  { id: "early_bird", tier: "bronze", name: "Early Bird", desc: "Walk 2,000 steps before 8 AM", icon: Sunrise, group: "Daily steps" },
  { id: "night_owl", tier: "bronze", name: "Night Owl", desc: "Walk 2,000 steps after 9 PM", icon: Moon, group: "Daily steps" },

  { id: "ten_k_club", tier: "silver", name: "10K Club", desc: "Walk 10 km in a day", icon: RouteIcon, group: "Distance" },
  { id: "explorer", tier: "bronze", name: "Explorer", desc: "Walk 10 km total", icon: Compass, group: "Distance" },
  { id: "adventurer", tier: "silver", name: "Adventurer", desc: "Walk 100 km total", icon: MapIcon, group: "Distance" },
  { id: "pathfinder", tier: "gold", name: "Pathfinder", desc: "Walk 500 km total", icon: Mountain, group: "Distance" },

  { id: "consistency_king", tier: "bronze", name: "Consistency King", desc: "Hit your daily goal 7 days in a row", icon: Flame, group: "Streaks" },
  { id: "impressive", tier: "silver", name: "Impressive", desc: "Hit your daily goal 30 days in a row", icon: Calendar, group: "Streaks" },
  { id: "unstoppable", tier: "gold", name: "Unstoppable", desc: "Hit your daily goal 100 days in a row", icon: InfinityIcon, group: "Streaks" },

  { id: "first_adventure", tier: "silver", name: "First Adventure", desc: "Visit your first tracked location", icon: MapPin, group: "Milestones" },
  { id: "first_friend", tier: "bronze", name: "First Friend", desc: "Add your first friend", icon: UserPlus, group: "Milestones" },
  { id: "challenge_accepted", tier: "bronze", name: "Challenge Accepted", desc: "Complete your first challenge", icon: CheckCircle2, group: "Milestones" },

  { id: "local_elite", tier: "silver", name: "Local Elite", desc: "Reach top 10 on the local leaderboard", icon: Trophy, group: "Leaderboards" },
  { id: "local_legend", tier: "gold", name: "Local Legend", desc: "Reach #1 on the local leaderboard", icon: Crown, group: "Leaderboards" },
  { id: "national_contender", tier: "silver", name: "National Contender", desc: "Reach top 100 on the national leaderboard", icon: Globe, group: "Leaderboards" },
  { id: "national_elite", tier: "gold", name: "National Elite", desc: "Reach top 10 on the national leaderboard", icon: Star, group: "Leaderboards" },
  { id: "national_champion", tier: "platinum", name: "National Champion", desc: "Reach #1 on the national leaderboard", icon: Medal, group: "Leaderboards" },

  { id: "problem_solver", tier: "bronze", name: "Problem Solver", desc: "Report a problem", icon: Bug, group: "Community" },
];

const TIER_STYLE: Record<BadgeTier, { ring: string; bg: string; fg: string; label: string; chip: string; glow: string }> = {
  bronze: {
    ring: "ring-amber-700/30",
    bg: "bg-gradient-to-br from-amber-300 via-amber-500 to-amber-800",
    fg: "text-amber-50",
    label: "Bronze",
    chip: "bg-amber-100 text-amber-800",
    glow: "shadow-[0_8px_24px_-12px_rgba(180,83,9,0.6)]",
  },
  silver: {
    ring: "ring-slate-400/40",
    bg: "bg-gradient-to-br from-slate-200 via-slate-400 to-slate-600",
    fg: "text-slate-50",
    label: "Silver",
    chip: "bg-slate-200 text-slate-700",
    glow: "shadow-[0_8px_24px_-12px_rgba(71,85,105,0.55)]",
  },
  gold: {
    ring: "ring-yellow-500/40",
    bg: "bg-gradient-to-br from-yellow-200 via-yellow-400 to-amber-600",
    fg: "text-yellow-900",
    label: "Gold",
    chip: "bg-yellow-100 text-yellow-800",
    glow: "shadow-[0_8px_28px_-10px_rgba(202,138,4,0.65)]",
  },
  platinum: {
    ring: "ring-cyan-400/40",
    bg: "bg-gradient-to-br from-cyan-100 via-sky-300 to-indigo-500",
    fg: "text-white",
    label: "Platinum",
    chip: "bg-cyan-100 text-cyan-800",
    glow: "shadow-[0_10px_30px_-10px_rgba(56,189,248,0.7)]",
  },
};

const STORE_KEY = "sg.badges";

type EarnedMap = Record<string, string>; // id -> ISO date

function loadEarned(): EarnedMap {
  try {
    const raw = localStorage.getItem(STORE_KEY);
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

function saveEarned(m: EarnedMap) {
  try { localStorage.setItem(STORE_KEY, JSON.stringify(m)); } catch {}
}

/** Award a badge by id, once. Returns true if newly awarded. */
export function awardBadge(id: string): boolean {
  const m = loadEarned();
  if (m[id]) return false;
  m[id] = new Date().toISOString();
  saveEarned(m);
  window.dispatchEvent(new CustomEvent("sg:badges-changed"));
  return true;
}

export function Badges() {
  const { settings } = useSettings();
  const [earned, setEarned] = useState<EarnedMap>({});

  useEffect(() => {
    setEarned(loadEarned());
    const onChange = () => setEarned(loadEarned());
    window.addEventListener("sg:badges-changed", onChange);
    window.addEventListener("storage", onChange);
    return () => {
      window.removeEventListener("sg:badges-changed", onChange);
      window.removeEventListener("storage", onChange);
    };
  }, []);

  // Auto-award streak badges based on current streak/best
  useEffect(() => {
    const best = Math.max(settings.streak.best, currentStreak(settings.streak));
    const toCheck: Array<[string, number]> = [
      ["consistency_king", 7],
      ["impressive", 30],
      ["unstoppable", 100],
    ];
    let changed = false;
    const m = loadEarned();
    for (const [id, n] of toCheck) {
      if (best >= n && !m[id]) { m[id] = new Date().toISOString(); changed = true; }
    }
    if (changed) { saveEarned(m); setEarned(m); }
  }, [settings.streak]);

  const groups = useMemo(() => {
    const map = new Map<string, BadgeDef[]>();
    for (const b of BADGES) {
      if (!map.has(b.group)) map.set(b.group, []);
      map.get(b.group)!.push(b);
    }
    return Array.from(map.entries());
  }, []);

  const [open, setOpen] = useState<BadgeDef | null>(null);
  const earnedCount = Object.keys(earned).filter((id) => BADGES.some((b) => b.id === id)).length;

  return (
    <div className="space-y-5">
      <div className="rounded-3xl bg-card p-5 ring-1 ring-black/5 flex items-center gap-4 animate-rise">
        <span className="grid size-12 place-items-center rounded-full bg-sage-100 text-sage-700">
          <Award className="size-6" />
        </span>
        <div className="flex-1">
          <p className="text-sm font-semibold">Achievements</p>
          <p className="text-xs text-sage-600">{earnedCount} of {BADGES.length} earned</p>
        </div>
        <span className="text-sm font-semibold tabular-nums text-sage-700">
          {Math.round((earnedCount / BADGES.length) * 100)}%
        </span>
      </div>

      {groups.map(([group, items]) => (
        <section key={group} className="space-y-3">
          <h3 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">{group}</h3>
          <div className="grid grid-cols-3 gap-3">
            {items.map((b, i) => {
              const isEarned = !!earned[b.id];
              const style = TIER_STYLE[b.tier];
              const Icon = b.icon;
              return (
                <button
                  key={b.id}
                  onClick={() => setOpen(b)}
                  className="group flex flex-col items-center gap-2 rounded-2xl bg-card p-3 ring-1 ring-black/5 animate-rise"
                  style={{ animationDelay: `${i * 40}ms` }}
                >
                  <span
                    className={`relative grid size-16 place-items-center rounded-full ring-2 ${style.ring} ${
                      isEarned ? `${style.bg} ${style.glow}` : "bg-sage-100/60"
                    }`}
                  >
                    {isEarned ? (
                      <Icon className={`size-7 ${style.fg}`} />
                    ) : (
                      <Lock className="size-6 text-sage-500/70" />
                    )}
                  </span>
                  <span className="text-center text-[11px] font-semibold leading-tight line-clamp-2">{b.name}</span>
                  <span className={`rounded-full px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider ${style.chip}`}>
                    {style.label}
                  </span>
                </button>
              );
            })}
          </div>
        </section>
      ))}

      <Dialog open={!!open} onOpenChange={(v) => !v && setOpen(null)}>
        <DialogContent className="max-w-sm">
          {open && (() => {
            const style = TIER_STYLE[open.tier];
            const Icon = open.icon;
            const isEarned = !!earned[open.id];
            return (
              <>
                <div className="flex flex-col items-center gap-3 pt-2">
                  <span
                    className={`grid size-24 place-items-center rounded-full ring-4 ${style.ring} ${
                      isEarned ? `${style.bg} ${style.glow}` : "bg-sage-100"
                    }`}
                  >
                    {isEarned ? <Icon className={`size-12 ${style.fg}`} /> : <Lock className="size-10 text-sage-500/70" />}
                  </span>
                  <span className={`rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider ${style.chip}`}>
                    {style.label}
                  </span>
                </div>
                <DialogHeader>
                  <DialogTitle className="text-center">{open.name}</DialogTitle>
                  <DialogDescription className="text-center">{open.desc}</DialogDescription>
                </DialogHeader>
                <p className="text-center text-xs text-sage-600">
                  {isEarned
                    ? `Earned ${new Date(earned[open.id]).toLocaleDateString()}`
                    : "Keep going — this badge is still locked."}
                </p>
              </>
            );
          })()}
        </DialogContent>
      </Dialog>
    </div>
  );
}
