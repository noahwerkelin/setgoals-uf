import SwiftUI

/// 1:1 port of `src/components/Badges.tsx` — the same 22 badges, groups,
/// tier gradients, glow shadows and chips.
enum BadgeTier: String {
    case bronze, silver, gold, platinum
}

struct BadgeDef: Identifiable, Hashable {
    let id: String
    let tier: BadgeTier
    let icon: String
    let group: String

    var name: String { L.t("badges.\(id).name") }
    var desc: String { L.t("badges.\(id).desc") }
}

/// Same order as the web array — the grid groups follow it.
let BADGES: [BadgeDef] = [
    BadgeDef(id: "first_steps", tier: .bronze, icon: "shoeprints.fill", group: "daily"),
    BadgeDef(id: "daily_walker", tier: .silver, icon: "shoeprints.fill", group: "daily"),
    BadgeDef(id: "early_bird", tier: .bronze, icon: "sunrise", group: "daily"),
    BadgeDef(id: "night_owl", tier: .bronze, icon: "moon", group: "daily"),

    BadgeDef(id: "ten_k_club", tier: .silver, icon: "point.topleft.down.to.point.bottomright.curvepath", group: "distance"),
    BadgeDef(id: "explorer", tier: .bronze, icon: "safari", group: "distance"),
    BadgeDef(id: "adventurer", tier: .silver, icon: "map", group: "distance"),
    BadgeDef(id: "pathfinder", tier: .gold, icon: "mountain.2", group: "distance"),

    BadgeDef(id: "consistency_king", tier: .bronze, icon: "flame", group: "streaks"),
    BadgeDef(id: "impressive", tier: .silver, icon: "calendar", group: "streaks"),
    BadgeDef(id: "unstoppable", tier: .gold, icon: "infinity", group: "streaks"),

    BadgeDef(id: "first_adventure", tier: .silver, icon: "mappin", group: "milestones"),
    BadgeDef(id: "first_friend", tier: .bronze, icon: "person.badge.plus", group: "milestones"),
    BadgeDef(id: "challenge_accepted", tier: .bronze, icon: "checkmark.circle", group: "milestones"),

    BadgeDef(id: "local_elite", tier: .silver, icon: "trophy", group: "leaderboards"),
    BadgeDef(id: "local_legend", tier: .gold, icon: "crown", group: "leaderboards"),
    BadgeDef(id: "national_contender", tier: .silver, icon: "globe", group: "leaderboards"),
    BadgeDef(id: "national_elite", tier: .gold, icon: "star", group: "leaderboards"),
    BadgeDef(id: "national_champion", tier: .platinum, icon: "medal", group: "leaderboards"),

    BadgeDef(id: "problem_solver", tier: .bronze, icon: "ladybug", group: "community"),

    BadgeDef(id: "earned_elite", tier: .platinum, icon: "diamond", group: "premium"),
    BadgeDef(id: "unlocker", tier: .platinum, icon: "sparkles", group: "premium"),
]

/// Exact sRGB values of the Tailwind classes used by `TIER_STYLE`.
struct TierStyle {
    let gradient: [Color]
    let ring: Color
    let fg: Color
    let chipBG: Color
    let chipFG: Color
    let glow: Color

    static func of(_ tier: BadgeTier) -> TierStyle {
        switch tier {
        case .bronze:
            return TierStyle(
                gradient: [Color(hex: "#FCD34D"), Color(hex: "#F59E0B"), Color(hex: "#92400E")],
                ring: Color(hex: "#B45309").opacity(0.30),
                fg: Color(hex: "#FFFBEB"),
                chipBG: Color(hex: "#FEF3C7"), chipFG: Color(hex: "#92400E"),
                glow: Color(red: 180/255, green: 83/255, blue: 9/255).opacity(0.6))
        case .silver:
            return TierStyle(
                gradient: [Color(hex: "#E2E8F0"), Color(hex: "#94A3B8"), Color(hex: "#475569")],
                ring: Color(hex: "#94A3B8").opacity(0.40),
                fg: Color(hex: "#F8FAFC"),
                chipBG: Color(hex: "#E2E8F0"), chipFG: Color(hex: "#334155"),
                glow: Color(red: 71/255, green: 85/255, blue: 105/255).opacity(0.55))
        case .gold:
            return TierStyle(
                gradient: [Color(hex: "#FEF08A"), Color(hex: "#FACC15"), Color(hex: "#D97706")],
                ring: Color(hex: "#EAB308").opacity(0.40),
                fg: Color(hex: "#713F12"),
                chipBG: Color(hex: "#FEF9C3"), chipFG: Color(hex: "#854D0E"),
                glow: Color(red: 202/255, green: 138/255, blue: 4/255).opacity(0.65))
        case .platinum:
            return TierStyle(
                gradient: [Color(hex: "#CFFAFE"), Color(hex: "#7DD3FC"), Color(hex: "#6366F1")],
                ring: Color(hex: "#22D3EE").opacity(0.40),
                fg: .white,
                chipBG: Color(hex: "#CFFAFE"), chipFG: Color(hex: "#155E75"),
                glow: Color(red: 56/255, green: 189/255, blue: 248/255).opacity(0.7))
        }
    }
}

/// `grid size-N place-items-center rounded-full ring-2 …` medal.
struct BadgeMedal: View {
    @EnvironmentObject var theme: Theme
    let badge: BadgeDef
    var earned: Bool
    var size: CGFloat = 64
    var ringWidth: CGFloat = 2

    var body: some View {
        let s = TierStyle.of(badge.tier)
        return ZStack {
            if earned {
                Circle().fill(
                    LinearGradient(colors: s.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            } else {
                Circle().fill(theme.p.s100.opacity(0.6))
            }
            Circle().strokeBorder(s.ring, lineWidth: ringWidth)
            Image(systemName: earned ? badge.icon : "lock.fill")
                .font(.system(size: size * (earned ? 0.44 : 0.38), weight: .medium))
                .foregroundStyle(earned ? s.fg : theme.p.s500.opacity(0.7))
        }
        .frame(width: size, height: size)
        .shadow(color: earned ? s.glow : .clear, radius: 12, y: 8)
    }
}

private struct TierChip: View {
    let tier: BadgeTier
    var size: CGFloat = 9
    var body: some View {
        let s = TierStyle.of(tier)
        return Text(L.t("badges.tier.\(tier.rawValue)"))
            .font(F.sans(size, .bold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(s.chipFG)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(s.chipBG, in: Capsule())
    }
}

/// The "Badges" tab of the challenges page.
struct BadgesGrid: View {
    @EnvironmentObject var theme: Theme
    let earned: Set<String>
    @State private var selected: BadgeDef?

    private let cols = [GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)]

    private var groups: [(String, [BadgeDef])] {
        var order: [String] = []
        var map: [String: [BadgeDef]] = [:]
        for b in BADGES {
            if map[b.group] == nil { order.append(b.group); map[b.group] = [] }
            map[b.group]?.append(b)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    private var earnedCount: Int { BADGES.filter { earned.contains($0.id) }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            ForEach(groups, id: \.0) { group, items in
                VStack(alignment: .leading, spacing: 12) {
                    Text(L.t("badges.group.\(group)"))
                        .font(F.sans(11, .semibold))
                        .textCase(.uppercase).tracking(1.2)
                        .foregroundStyle(theme.p.s600)
                        .padding(.horizontal, 4)
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, b in
                            Button { selected = b } label: { cell(b) }
                                .buttonStyle(.plain)
                                .rise(delay: Double(i) * 0.04)
                        }
                    }

                }
            }
        }
        .sheet(item: $selected) { b in
            BadgeDetailSheet(badge: b, earned: earned.contains(b.id))
                .environmentObject(theme)
        }
    }

    private var header: some View {
        CardSurface {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(theme.p.s100)
                    Image(systemName: "rosette").font(.system(size: 24))
                        .foregroundStyle(theme.p.s700)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("badges.title")).font(F.sans(14, .semibold))
                        .foregroundStyle(theme.foreground)
                    Text(L.t("badges.earned_of", ["n": "\(earnedCount)", "total": "\(BADGES.count)"]))
                        .font(F.xs).foregroundStyle(theme.p.s600)
                }
                Spacer()
                Text("\(Int((Double(earnedCount) / Double(BADGES.count) * 100).rounded()))%")
                    .font(F.sans(14, .semibold)).tabularNums()
                    .foregroundStyle(theme.p.s700)
            }
        }
        .rise()
    }

    private func cell(_ b: BadgeDef) -> some View {
        VStack(spacing: 8) {
            BadgeMedal(badge: b, earned: earned.contains(b.id), size: 64)
            Text(b.name)
                .font(F.sans(11, .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(theme.foreground)
            TierChip(tier: b.tier)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                .strokeBorder(theme.ringBorder, lineWidth: 1)
        )
    }
}

struct BadgeDetailSheet: View {
    @EnvironmentObject var theme: Theme
    let badge: BadgeDef
    let earned: Bool

    var body: some View {
        VStack(spacing: 12) {
            BadgeMedal(badge: badge, earned: earned, size: 96, ringWidth: 4)
                .padding(.top, 8)
            TierChip(tier: badge.tier, size: 10)
            Text(badge.name).font(F.sans(18, .semibold)).foregroundStyle(theme.foreground)
            Text(badge.desc).font(F.sm).foregroundStyle(theme.p.s600)
                .multilineTextAlignment(.center)
            Text(earned ? L.t("badges.earned_on", ["date": Self.today]) : L.t("badges.locked_hint"))
                .font(F.xs).foregroundStyle(theme.p.s600)
                .multilineTextAlignment(.center)
            if earned {
                let shareText = L.t("badges.share_text", [
                    "tier": L.t("badges.tier.\(badge.tier.rawValue)"), "name": badge.name,
                ]) + " https://setgoals.app"
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 11, weight: .semibold))
                        Text(L.t("badges.share")).font(F.sans(10, .bold))
                            .textCase(.uppercase).tracking(1.2)
                        Spacer()
                    }
                    .foregroundStyle(theme.p.s600)

                    ShareLink(item: shareText) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 13))
                            Text(L.t("badges.share")).font(F.sans(12, .semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .foregroundStyle(theme.primaryForeground)
                        .background(theme.p.s600, in: RoundedRectangle(cornerRadius: R.xl, style: .continuous))
                    }

                    Button {
                        UIPasteboard.general.string = shareText
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.doc").font(.system(size: 12))
                            Text(L.t("badges.share_copy")).font(F.sans(12, .semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(theme.p.s700)
                        .background(theme.p.s100, in: RoundedRectangle(cornerRadius: R.xl, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(theme.background)
        .presentationDetents([.height(earned ? 440 : 380)])
        .presentationCornerRadius(28)
    }

    private static var today: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: L.lang == "sv" ? "sv_SE" : "en_US")
        f.dateStyle = .short
        return f.string(from: Date())
    }
}

/// Port of `src/components/ProfileBadgeStrip.tsx`.
struct ProfileBadgeStrip: View {
    @EnvironmentObject var theme: Theme
    let earned: Set<String>
    var onSeeAll: () -> Void

    private var list: [BadgeDef] { BADGES.filter { earned.contains($0.id) } }

    var body: some View {
        Button(action: onSeeAll) {
            CardSurface {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: R.xl2, style: .continuous).fill(theme.p.s100)
                            Image(systemName: "rosette").font(.system(size: 20))
                                .foregroundStyle(theme.p.s700)
                        }
                        .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.t("badges.title")).font(F.sans(14, .semibold))
                                .foregroundStyle(theme.foreground)
                            Text(L.t("badges.earned_of", ["n": "\(list.count)", "total": "\(BADGES.count)"]))
                                .font(F.xs).foregroundStyle(theme.p.s600)
                        }
                        Spacer()
                        Text(L.t("badges.view_all"))
                            .font(F.sans(11, .semibold)).foregroundStyle(theme.p.s700)
                    }

                    if list.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill").font(.system(size: 11))
                            Text(L.t("badges.empty")).font(F.xs)
                        }
                        .foregroundStyle(theme.p.s600)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(list.prefix(8)) { BadgeMedal(badge: $0, earned: true, size: 44) }
                                if list.count > 8 {
                                    Text("+\(list.count - 8)")
                                        .font(F.sans(10, .semibold))
                                        .foregroundStyle(theme.p.s700)
                                        .frame(width: 44, height: 44)
                                        .background(theme.p.s100, in: Circle())
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
