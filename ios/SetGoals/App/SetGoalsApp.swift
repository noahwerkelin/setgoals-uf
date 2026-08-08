import SwiftUI

@main
struct SetGoalsApp: App {
    @StateObject private var theme = Theme()
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var auth = AuthStore.shared
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(theme)
                    .environmentObject(settings)
                    .environmentObject(auth)
                if showSplash {
                    SplashView()
                        .environmentObject(theme)
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(.light)
            .task {
                await auth.bootstrap()
                ScreenTimeService.shared.scheduleDailyMonitoring()
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
            }
            .onChange(of: settings.themeColor) { _, new in theme.color = new }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var tab: AppTab = .home

    var body: some View {
        if auth.loading {
            SplashView()
        } else if !auth.signedIn {
            AuthView()
        } else {
            switch tab {
            case .home: HomeView(tab: $tab)
            case .profile: ProfileView(tab: $tab)
            case .map: ActivityMapView(tab: $tab)
            case .challenges: ChallengesView(tab: $tab, initialTab: NavIntent.shared.challengesTab)
            case .coach: CoachView(tab: $tab)
            }

        }
    }
}

/// Screens not yet ported keep the exact shell, header and spacing so the
/// remaining ports drop straight in.
struct PlaceholderView: View {
    @EnvironmentObject var theme: Theme
    @Binding var tab: AppTab
    let title: String

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(title: title) { EmptyView() }
            CardSurface {
                Text("Not ported yet.").font(F.sm).foregroundStyle(theme.p.s600)
            }
            .padding(.horizontal, 24)
        }
    }
}
