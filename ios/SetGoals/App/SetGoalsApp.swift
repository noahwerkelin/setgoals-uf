import SwiftUI

@main
struct SetGoalsApp: App {
    @StateObject private var theme = Theme()
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var auth = AuthStore.shared
    @State private var showSplash = true
    @AppStorage("app.onboarded") private var onboarded = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !onboarded {
                    // Only marked complete once the user is signed in.
                    OnboardingView {
                        withAnimation(.easeOut(duration: 0.35)) { onboarded = true }
                        Task {
                            try? await SupabaseAPI.updateProfile(["onboarding_completed": .bool(true)])
                            await settings.load()
                            await FriendsStore.shared.preload()
                            NearbyStore.shared.start()
                            Task { await StatsCache.shared.load() }
                            Task { await BadgeStore.shared.preload() }
                            if HealthKitService.shared.isAvailable {
                                await HealthKitService.shared.requestAuthorization()
                            }
                            await StreakSync.syncFromHealthKit()
                            ScreenTimeService.shared.refreshAuthorization()
                            ScreenTimeService.shared.refreshFromStore()
                            ScreenTimeService.shared.scheduleDailyMonitoring()
                        }
                    }
                        .environmentObject(theme)
                        .transition(.opacity)
                } else {
                    RootView()
                    .environmentObject(theme)
                    .environmentObject(settings)
                    .environmentObject(auth)
                }
                if showSplash {
                    SplashView()
                        .environmentObject(theme)
                        .transition(.opacity)
                }
            }
            .task {
                await auth.bootstrap()
                if auth.signedIn { await FriendsStore.shared.preload() }
                // Keep Apple's Screen Time rules in step with the category
                // pills the user sees.
                ScreenTimeRules.policies = ProSTStore.shared.alwaysAllow
                ScreenTimeService.shared.refreshAuthorization()
                ScreenTimeService.shared.refreshFromStore()
                ScreenTimeService.shared.scheduleDailyMonitoring()
                // Nearby activities start loading at launch, not on the map page.
                if onboarded { NearbyStore.shared.start() }
                if onboarded, HealthKitService.shared.isAvailable {
                    await HealthKitService.shared.requestAuthorization()
                }
                if auth.signedIn {
                    // Pre-load statistics so the Stats page opens instantly.
                    Task { await StatsCache.shared.load() }
                    Task { await BadgeStore.shared.preload() }
                    await settings.load()
                    await StreakSync.syncFromHealthKit()
                    // A child device is authorized as `.child`, so the parent
                    // remains the moderator in Apple's own Screen Time system
                    // and the child cannot lift the restrictions.
                    if onboarded, !ScreenTimeService.shared.authorized {
                        await ScreenTimeService.shared.requestAuthorization(
                            forChild: settings.role == "child"
                        )
                        ScreenTimeService.shared.refreshFromStore()
                        ScreenTimeService.shared.scheduleDailyMonitoring()
                    }
                }
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
            case .challenges: ChallengesView(tab: $tab, initialTab: NavIntent.shared.consumeChallengesTab())
            case .screenTime: ParentView(tab: $tab)
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
