import SwiftUI

/// Port of `src/components/AppShell.tsx` + `BottomNav.tsx`.
/// max-w-md container, pb-28, floating pill nav 20px from the bottom.
struct AppShell<Content: View>: View {
    @EnvironmentObject var theme: Theme
    @Binding var tab: AppTab
    var hideNav = false
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) { content }
                    .frame(maxWidth: 448)          // max-w-md
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 112)          // pb-28
            }
            .scrollIndicators(.hidden)
            if !hideNav { BottomNav(tab: $tab) }
        }
    }
}

enum AppTab: String, CaseIterable {
    case home, map, challenges, coach, profile

    var icon: String {
        switch self {
        case .home: return "house"
        case .map: return "map"
        case .challenges: return "trophy"
        case .coach: return "sparkles"
        case .profile: return "person"
        }
    }
    var labelKey: String { "nav.\(self == .challenges ? "goals" : rawValue)" }
}

struct BottomNav: View {
    @EnvironmentObject var theme: Theme
    @Binding var tab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: tab == item ? .semibold : .regular))
                        .foregroundStyle(tab == item ? theme.p.s700 : theme.p.s950.opacity(0.4))
                        .frame(minWidth: 44, minHeight: 44)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .accessibilityLabel(L.t(item.labelKey))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
        .background(theme.card.opacity(0.85), in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                .strokeBorder(theme.ringBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 10)
        .frame(maxWidth: 360)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
}

/// `PageHeader` — eyebrow + 2xl title + optional trailing view.
struct PageHeader<Trailing: View>: View {
    @EnvironmentObject var theme: Theme
    var eyebrow: String? = nil
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow {
                    Text(eyebrow).font(F.sans(14, .medium)).foregroundStyle(theme.p.s600)
                }
                Text(title).font(F.xl2).tracking(-0.4).foregroundStyle(theme.foreground)
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 40)
    }
}
