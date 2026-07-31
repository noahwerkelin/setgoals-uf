import { Link } from "@tanstack/react-router";
import { Award, Lock } from "lucide-react";
import { BADGES, tierStyle } from "@/components/Badges";
import { useEarnedBadges } from "@/lib/badges";
import { useT } from "@/lib/i18n";

export function ProfileBadgeStrip() {
  const { t } = useT();
  const { data: earnedRows } = useEarnedBadges();
  const earned = new Set((earnedRows ?? []).map((b) => b.badge_id));
  const earnedList = BADGES.filter((b) => earned.has(b.id));
  const total = BADGES.length;

  return (
    <Link
      to="/challenges"
      search={{ tab: "badges" }}
      className="block rounded-3xl bg-card p-5 ring-1 ring-black/5 animate-rise"
      style={{ animationDelay: "100ms" }}
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <span className="grid size-10 place-items-center rounded-2xl bg-sage-100 text-sage-700">
            <Award className="size-5" />
          </span>
          <div>
            <p className="text-sm font-semibold">{t("badges.title")}</p>
            <p className="text-xs text-sage-600">
              {t("badges.earned_of", { n: String(earnedList.length), total: String(total) })}
            </p>
          </div>
        </div>
        <span className="text-[11px] font-semibold text-sage-700">{t("badges.view_all")}</span>
      </div>

      {earnedList.length > 0 ? (
        <div className="mt-4 flex gap-2 overflow-x-auto pb-1 -mx-1 px-1">
          {earnedList.slice(0, 8).map((b) => {
            const s = tierStyle(b.tier);
            const Icon = b.icon;
            return (
              <span
                key={b.id}
                title={t(`badges.${b.id}.name`)}
                className={`shrink-0 grid size-11 place-items-center rounded-full ring-2 ${s.ring} ${s.bg} ${s.glow}`}
              >
                <Icon className={`size-5 ${s.fg}`} />
              </span>
            );
          })}
          {earnedList.length > 8 && (
            <span className="shrink-0 grid size-11 place-items-center rounded-full bg-sage-100 text-[10px] font-semibold text-sage-700">
              +{earnedList.length - 8}
            </span>
          )}
        </div>
      ) : (
        <div className="mt-4 flex items-center gap-2 rounded-2xl bg-sage-50 p-3 text-xs text-sage-600">
          <Lock className="size-3.5" /> {t("badges.empty")}
        </div>
      )}
    </Link>
  );
}
