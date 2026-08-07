import SwiftUI

/// Port of `src/components/Badges.tsx` — tiered badges with the same
/// bronze / silver / gold / platinum colour scheme.
struct BadgeDef: Identifiable, Hashable {
    enum Tier: String { case bronze, silver, gold, platinum }
    let id: String
    let en: String
    let sv: String
    let icon: String
    let tier: Tier
    /// Requirement evaluated against real activity data.
    let requirement: String

    var title: String { L.lang == "sv" ? sv : en }

    var colors: [Color] {
        switch tier {
        case .bronze:   return [Color(hex: "#D8A15A"), Color(hex: "#9C6B2F")]
        case .silver:   return [Color(hex: "#DCE1E6"), Color(hex: "#9AA5AF")]
        case .gold:     return [Color(hex: "#F1D27A"), Color(hex: "#C79A2B")]
        case .platinum: return [Color(hex: "#E8EEF5"), Color(hex: "#A9BACB")]
        }
    }
}

enum BadgeCatalog {
    static let all: [BadgeDef] = [
        BadgeDef(id: "first_steps", en: "First Steps", sv: "Första stegen", icon: "figure.walk", tier: .bronze, requirement: "steps>=1000"),
        BadgeDef(id: "step_10k", en: "Ten Thousand", sv: "Tiotusen", icon: "shoeprints.fill", tier: .silver, requirement: "steps>=10000"),
        BadgeDef(id: "step_20k", en: "Marathoner", sv: "Maratonare", icon: "flag.checkered", tier: .gold, requirement: "steps>=20000"),
        BadgeDef(id: "dist_5", en: "Five Kilometres", sv: "Fem kilometer", icon: "map", tier: .bronze, requirement: "distance>=5"),
        BadgeDef(id: "dist_10", en: "Ten Kilometres", sv: "Tio kilometer", icon: "mountain.2", tier: .silver, requirement: "distance>=10"),
        BadgeDef(id: "dist_42", en: "Full Distance", sv: "Hela sträckan", icon: "medal", tier: .gold, requirement: "distance>=42"),
        BadgeDef(id: "streak_3", en: "Three in a Row", sv: "Tre i rad", icon: "flame", tier: .bronze, requirement: "streak>=3"),
        BadgeDef(id: "streak_7", en: "Week Warrior", sv: "Veckokämpe", icon: "flame.fill", tier: .silver, requirement: "streak>=7"),
        BadgeDef(id: "streak_30", en: "Unbroken", sv: "Obruten", icon: "bolt.heart", tier: .gold, requirement: "streak>=30"),
        BadgeDef(id: "early_bird", en: "Early Bird", sv: "Morgonpigg", icon: "sunrise", tier: .silver, requirement: "steps 00:00–08:00 >= 5000"),
        BadgeDef(id: "night_owl", en: "Night Owl", sv: "Nattuggla", icon: "moon.stars", tier: .silver, requirement: "steps 21:00–23:59 >= 3000"),
        BadgeDef(id: "lb_local_top10", en: "Local Top 10", sv: "Topp 10 lokalt", icon: "mappin.and.ellipse", tier: .silver, requirement: "local rank <= 10"),
        BadgeDef(id: "lb_local_1", en: "Local Champion", sv: "Lokal mästare", icon: "crown", tier: .gold, requirement: "local rank == 1"),
        BadgeDef(id: "lb_nat_top10", en: "National Top 10", sv: "Topp 10 nationellt", icon: "globe.europe.africa", tier: .gold, requirement: "national rank <= 10"),
        BadgeDef(id: "lb_nat_1", en: "National Champion", sv: "Nationell mästare", icon: "star.circle", tier: .platinum, requirement: "national rank == 1"),
        BadgeDef(id: "friend_5", en: "Social Walker", sv: "Social vandrare", icon: "person.2", tier: .bronze, requirement: "friends>=5"),
        BadgeDef(id: "reporter", en: "Reporter", sv: "Rapportör", icon: "exclamationmark.bubble", tier: .bronze, requirement: "reported a problem"),
        BadgeDef(id: "earned_elite", en: "Earned Elite", sv: "Förtjänad elit", icon: "sparkles", tier: .platinum, requirement: "SetGoals PRO"),
        BadgeDef(id: "unlocker", en: "Unlocker", sv: "Upplåsaren", icon: "lock.open", tier: .platinum, requirement: "all other badges"),
    ]
}

struct BadgeMedal: View {
    @EnvironmentObject var theme: Theme
    let badge: BadgeDef
    var earned: Bool
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: earned ? badge.colors : [theme.p.s100, theme.p.s200],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(.white.opacity(earned ? 0.55 : 0.2), lineWidth: 2)
            Image(systemName: earned ? badge.icon : "lock.fill")
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(earned ? .white : theme.p.s600)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(earned ? 0.12 : 0.04), radius: 6, y: 3)
        .opacity(earned ? 1 : 0.85)
    }
}

/// Grid of every badge — the "Badges" tab of the challenges page.
struct BadgesGrid: View {
    @EnvironmentObject var theme: Theme
    let earned: Set<String>
    @State private var selected: BadgeDef?

    private let cols = [GridItem(.adaptive(minimum: 92), spacing: 16)]

    var body: some View {
        LazyVGrid(columns: cols, spacing: 20) {
            ForEach(BadgeCatalog.all) { b in
                Button { selected = b } label: {
                    VStack(spacing: 8) {
                        BadgeMedal(badge: b, earned: earned.contains(b.id))
                        Text(b.title)
                            .font(F.sans(11, .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(earned.contains(b.id) ? theme.p.s900 : theme.p.s600)
                    }
                }
            }
        }
        .sheet(item: $selected) { b in
            BadgeDetailSheet(badge: b, earned: earned.contains(b.id))
                .environmentObject(theme)
        }
    }
}

struct BadgeDetailSheet: View {
    @EnvironmentObject var theme: Theme
    let badge: BadgeDef
    let earned: Bool

    var body: some View {
        VStack(spacing: 16) {
            BadgeMedal(badge: badge, earned: earned, size: 108)
            Text(badge.title).font(F.sans(20, .semibold)).foregroundStyle(theme.p.s950)
            Text(badge.tier.rawValue.capitalized).eyebrow(theme.p.s600)
            Text(badge.requirement).font(F.sm).foregroundStyle(theme.p.s700)
                .multilineTextAlignment(.center)
            if earned {
                ShareLink(item: "\(L.t("badges.share_text", ["b": badge.title]))") {
                    Text(L.t("badges.share"))
                        .font(F.sans(14, .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .foregroundStyle(theme.primaryForeground)
                        .background(theme.primary, in: Capsule())
                }
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(theme.background)
        .presentationDetents([.height(400)])
        .presentationCornerRadius(28)
    }
}

/// Miniature strip shown on the profile page.
struct ProfileBadgeStrip: View {
    @EnvironmentObject var theme: Theme
    let earned: Set<String>
    var onSeeAll: () -> Void

    var body: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L.t("profile.badges")).eyebrow(theme.p.s600)
                    Spacer()
                    Button(L.t("profile.view_all"), action: onSeeAll)
                        .font(F.xs).foregroundStyle(theme.p.s700)
                }
                let list = BadgeCatalog.all.filter { earned.contains($0.id) }
                if list.isEmpty {
                    Text(L.t("badges.empty")).font(F.sm).foregroundStyle(theme.p.s600)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(list) { BadgeMedal(badge: $0, earned: true, size: 44) }
                        }
                    }
                }
            }
        }
    }
}
