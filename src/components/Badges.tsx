import { useEffect, useMemo, useState } from "react";
import {
  Award, Footprints, Sunrise, Moon, Route as RouteIcon, Map as MapIcon,
  Compass, Mountain, Flame, Calendar, Infinity as InfinityIcon, MapPin,
  UserPlus, CheckCircle2, Trophy, Crown, Globe, Star, Medal, Bug, Lock,
  Share2, Send, Copy, MessageCircle,
  type LucideIcon,
} from "lucide-react";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { currentStreak, useSettings } from "@/lib/settings";
import { useT } from "@/lib/i18n";
import { toast } from "sonner";

export type BadgeTier = "bronze" | "silver" | "gold" | "platinum";

export type BadgeDef = {
  id: string;
  tier: BadgeTier;
  icon: LucideIcon;
  group: string;
};

export const BADGES: BadgeDef[] = [
  { id: "first_steps", tier: "bronze", icon: Footprints, group: "daily" },
  { id: "daily_walker", tier: "silver", icon: Footprints, group: "daily" },
  { id: "early_bird", tier: "bronze", icon: Sunrise, group: "daily" },
  { id: "night_owl", tier: "bronze", icon: Moon, group: "daily" },

  { id: "ten_k_club", tier: "silver", icon: RouteIcon, group: "distance" },
  { id: "explorer", tier: "bronze", icon: Compass, group: "distance" },
  { id: "adventurer", tier: "silver", icon: MapIcon, group: "distance" },
  { id: "pathfinder", tier: "gold", icon: Mountain, group: "distance" },

  { id: "consistency_king", tier: "bronze", icon: Flame, group: "streaks" },
  { id: "impressive", tier: "silver", icon: Calendar, group: "streaks" },
  { id: "unstoppable", tier: "gold", icon: InfinityIcon, group: "streaks" },

  { id: "first_adventure", tier: "silver", icon: MapPin, group: "milestones" },
  { id: "first_friend", tier: "bronze", icon: UserPlus, group: "milestones" },
  { id: "challenge_accepted", tier: "bronze", icon: CheckCircle2, group: "milestones" },

  { id: "local_elite", tier: "silver", icon: Trophy, group: "leaderboards" },
  { id: "local_legend", tier: "gold", icon: Crown, group: "leaderboards" },
  { id: "national_contender", tier: "silver", icon: Globe, group: "leaderboards" },
  { id: "national_elite", tier: "gold", icon: Star, group: "leaderboards" },
  { id: "national_champion", tier: "platinum", icon: Medal, group: "leaderboards" },

  { id: "problem_solver", tier: "bronze", icon: Bug, group: "community" },
];

const TIER_STYLE: Record<BadgeTier, { ring: string; bg: string; fg: string; chip: string; glow: string }> = {
  bronze: {
    ring: "ring-amber-700/30",
    bg: "bg-gradient-to-br from-amber-300 via-amber-500 to-amber-800",
    fg: "text-amber-50",
    chip: "bg-amber-100 text-amber-800",
    glow: "shadow-[0_8px_24px_-12px_rgba(180,83,9,0.6)]",
  },
  silver: {
    ring: "ring-slate-400/40",
    bg: "bg-gradient-to-br from-slate-200 via-slate-400 to-slate-600",
    fg: "text-slate-50",
    chip: "bg-slate-200 text-slate-700",
    glow: "shadow-[0_8px_24px_-12px_rgba(71,85,105,0.55)]",
  },
  gold: {
    ring: "ring-yellow-500/40",
    bg: "bg-gradient-to-br from-yellow-200 via-yellow-400 to-amber-600",
    fg: "text-yellow-900",
    chip: "bg-yellow-100 text-yellow-800",
    glow: "shadow-[0_8px_28px_-10px_rgba(202,138,4,0.65)]",
  },
  platinum: {
    ring: "ring-cyan-400/40",
    bg: "bg-gradient-to-br from-cyan-100 via-sky-300 to-indigo-500",
    fg: "text-white",
    chip: "bg-cyan-100 text-cyan-800",
    glow: "shadow-[0_10px_30px_-10px_rgba(56,189,248,0.7)]",
  },
};

export function tierStyle(tier: BadgeTier) { return TIER_STYLE[tier]; }

const STORE_KEY = "sg.badges";
const TOTALS_KEY = "sg.totals";

type EarnedMap = Record<string, string>;
type Totals = { lastDate: string | null; totalSteps: number; totalKm: number };

function loadEarned(): EarnedMap {
  try { const raw = localStorage.getItem(STORE_KEY); return raw ? JSON.parse(raw) : {}; } catch { return {}; }
}
function saveEarned(m: EarnedMap) {
  try { localStorage.setItem(STORE_KEY, JSON.stringify(m)); } catch {}
}
function loadTotals(): Totals {
  try { const raw = localStorage.getItem(TOTALS_KEY); return raw ? JSON.parse(raw) : { lastDate: null, totalSteps: 0, totalKm: 0 }; }
  catch { return { lastDate: null, totalSteps: 0, totalKm: 0 }; }
}
function saveTotals(t: Totals) { try { localStorage.setItem(TOTALS_KEY, JSON.stringify(t)); } catch {} }

function notifyChange() {
  window.dispatchEvent(new CustomEvent("sg:badges-changed"));
}

function awardMany(ids: string[]): boolean {
  const m = loadEarned();
  let changed = false;
  for (const id of ids) {
    if (!m[id]) { m[id] = new Date().toISOString(); changed = true; }
  }
  if (changed) { saveEarned(m); notifyChange(); }
  return changed;
}

/** Award a single badge by id. Returns true if newly awarded. */
export function awardBadge(id: string): boolean {
  return awardMany([id]);
}

/** Record today's activity. Accumulates totals once per day and awards step/distance badges. */
export function recordDailyActivity(steps: number, km: number, hour: number) {
  const today = new Date();
  const iso = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;
  const t = loadTotals();
  if (t.lastDate !== iso) {
    t.totalSteps += steps;
    t.totalKm += km;
    t.lastDate = iso;
    saveTotals(t);
  }
  const ids: string[] = [];
  if (steps >= 1000) ids.push("first_steps");
  if (steps >= 5000) ids.push("daily_walker");
  if (steps >= 2000 && hour < 8) ids.push("early_bird");
  if (steps >= 2000 && hour >= 21) ids.push("night_owl");
  if (km >= 10) ids.push("ten_k_club");
  if (t.totalKm >= 10) ids.push("explorer");
  if (t.totalKm >= 100) ids.push("adventurer");
  if (t.totalKm >= 500) ids.push("pathfinder");
  awardMany(ids);
}

/** Record a leaderboard rank (1-based). scope: "local" | "national". */
export function recordLeaderboardRank(scope: "local" | "national", rank: number) {
  const ids: string[] = [];
  if (scope === "local") {
    if (rank <= 10) ids.push("local_elite");
    if (rank === 1) ids.push("local_legend");
  } else {
    if (rank <= 100) ids.push("national_contender");
    if (rank <= 10) ids.push("national_elite");
    if (rank === 1) ids.push("national_champion");
  }
  awardMany(ids);
}

export function useEarnedBadges() {
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
  return earned;
}

export function Badges() {
  const { t } = useT();
  const { settings } = useSettings();
  const earned = useEarnedBadges();

  // Auto-award streak badges
  useEffect(() => {
    const best = Math.max(settings.streak.best, currentStreak(settings.streak));
    const ids: string[] = [];
    if (best >= 7) ids.push("consistency_king");
    if (best >= 30) ids.push("impressive");
    if (best >= 100) ids.push("unstoppable");
    if (ids.length) awardMany(ids);
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
          <p className="text-sm font-semibold">{t("badges.title")}</p>
          <p className="text-xs text-sage-600">{t("badges.earned_of", { n: String(earnedCount), total: String(BADGES.length) })}</p>
        </div>
        <span className="text-sm font-semibold tabular-nums text-sage-700">
          {Math.round((earnedCount / BADGES.length) * 100)}%
        </span>
      </div>

      {groups.map(([group, items]) => (
        <section key={group} className="space-y-3">
          <h3 className="px-1 text-[11px] font-semibold uppercase tracking-widest text-sage-600">
            {t(`badges.group.${group}`)}
          </h3>
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
                  <span className="text-center text-[11px] font-semibold leading-tight line-clamp-2">
                    {t(`badges.${b.id}.name`)}
                  </span>
                  <span className={`rounded-full px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider ${style.chip}`}>
                    {t(`badges.tier.${b.tier}`)}
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
                    {t(`badges.tier.${open.tier}`)}
                  </span>
                </div>
                <DialogHeader>
                  <DialogTitle className="text-center">{t(`badges.${open.id}.name`)}</DialogTitle>
                  <DialogDescription className="text-center">{t(`badges.${open.id}.desc`)}</DialogDescription>
                </DialogHeader>
                <p className="text-center text-xs text-sage-600">
                  {isEarned
                    ? t("badges.earned_on", { date: new Date(earned[open.id]).toLocaleDateString() })
                    : t("badges.locked_hint")}
                </p>
                {isEarned && <ShareBadge badge={open} />}
              </>
            );
          })()}
        </DialogContent>
      </Dialog>
    </div>
  );
}

function ShareBadge({ badge }: { badge: BadgeDef }) {
  const { t } = useT();
  const name = t(`badges.${badge.id}.name`);
  const tier = t(`badges.tier.${badge.tier}`);
  const url = typeof window !== "undefined" ? window.location.origin : "";
  const text = t("badges.share_text", { tier, name });
  const shareUrl = url || "https://setgoals.app";

  const nativeShare = async () => {
    const nav = typeof navigator !== "undefined" ? navigator : undefined;
    if (nav && typeof nav.share === "function") {
      try {
        await nav.share({ title: name, text, url: shareUrl });
        return;
      } catch {
        // user cancelled or share failed — fall through to copy
      }
    }
    await copyLink();
  };

  const copyLink = async () => {
    try {
      await navigator.clipboard.writeText(`${text} ${shareUrl}`);
      toast.success(t("badges.share_copied"));
    } catch {
      toast.error(t("badges.share_failed"));
    }
  };

  const openIntent = (href: string) => {
    window.open(href, "_blank", "noopener,noreferrer");
  };

  const encoded = encodeURIComponent(`${text} ${shareUrl}`);
  const encodedUrl = encodeURIComponent(shareUrl);
  const encodedText = encodeURIComponent(text);

  return (
    <div className="mt-2 space-y-3">
      <div className="flex items-center gap-2 text-[10px] font-semibold uppercase tracking-widest text-sage-600">
        <Share2 className="size-3.5" /> {t("badges.share")}
      </div>
      <div className="grid grid-cols-4 gap-2">
        <ShareBtn label={t("badges.share_native")} icon={<Share2 className="size-4" />} onClick={nativeShare} />
        <ShareBtn
          label="X"
          icon={<Send className="size-4" />}
          onClick={() => openIntent(`https://twitter.com/intent/tweet?text=${encodedText}&url=${encodedUrl}`)}
        />
        <ShareBtn
          label="Facebook"
          icon={<MessageCircle className="size-4" />}
          onClick={() => openIntent(`https://www.facebook.com/sharer/sharer.php?u=${encodedUrl}&quote=${encodedText}`)}
        />
        <ShareBtn
          label="WhatsApp"
          icon={<MessageCircle className="size-4" />}
          onClick={() => openIntent(`https://wa.me/?text=${encoded}`)}
        />
      </div>
      <button
        onClick={copyLink}
        className="flex w-full items-center justify-center gap-2 rounded-xl bg-sage-100 px-3 py-2 text-xs font-semibold text-sage-700 hover:bg-sage-200"
      >
        <Copy className="size-3.5" /> {t("badges.share_copy")}
      </button>
    </div>
  );
}

function ShareBtn({ label, icon, onClick }: { label: string; icon: React.ReactNode; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className="flex flex-col items-center gap-1 rounded-xl bg-card p-2 ring-1 ring-black/5 hover:bg-sage-50"
    >
      <span className="grid size-8 place-items-center rounded-full bg-sage-100 text-sage-700">{icon}</span>
      <span className="text-[10px] font-medium text-sage-700">{label}</span>
    </button>
  );
}
