import Foundation
import SwiftUI

/// Port of `src/lib/settings.tsx` + `src/lib/screentime.ts` math.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var displayName: String = ""
    @Published var username: String = ""
    @Published var email: String = ""
    @Published var avatar: String? = nil          // emoji, or a data/https URL
    @Published var role: String = "individual"    // individual | child
    @Published var linkedChild: Bool = false      // picture is parent-managed
    @Published var dailyGoal: Int = 8000
    @Published var stepsPer30: Int = 1000
    @Published var dailyCapHours: Int = 3         // 24 == no cap
    @Published var units: String = "metric"
    @Published var isPro: Bool = false
    @Published var proPlan: String = "monthly"
    @Published var proExpiresAt: String? = nil
    @Published var themeColor: ThemeColor = .sage
    @Published var bonusMin: Int = 0
    @Published var anonymousLeaderboard: Bool = false
    @Published var shareLocation: String = "while_using"   // off | while_using | always
    @Published var pushOn: Bool = true
    @Published var healthkitConnected: Bool = false
    @Published var googlefitConnected: Bool = false
    @Published var streakCount: Int = 0
    @Published var streakBest: Int = 0
    @Published var lastGoalMetDate: String? = nil


    var hasCap: Bool { dailyCapHours > 0 }
    var capMin: Int { hasCap ? dailyCapHours * 60 : Int.max / 4 }

    /// `earnedMinFromSteps` — identical rounding to the web helper.
    func earnedMin(from steps: Int) -> Int {
        guard stepsPer30 > 0 else { return 0 }
        let raw = Int((Double(steps) / Double(stepsPer30) * 30).rounded(.down))
        return min(raw, capMin)
    }

    static func formatScreenMin(_ m: Int) -> String {
        if m < 60 { return "\(m) min" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h) h" : "\(h) h \(r) min"
    }

    func formatDistance(_ km: Double) -> (String, String) {
        if units == "imperial" {
            return (String(format: "%.1f", km * 0.621371), "mi")
        }
        return (String(format: "%.1f", km), "km")
    }

    func load() async {
        guard let p = try? await SupabaseAPI.profile(), let p else { return }
        displayName = p.display_name
        username = p.username
        avatar = p.avatar_url
        role = p.role
        if let s = try? await SupabaseAPI.settings(), let s {
            dailyGoal = s.daily_goal
            stepsPer30 = s.steps_per_30
            dailyCapHours = s.daily_cap_hours
            units = s.units
            isPro = s.is_pro
            proPlan = s.pro_plan
            themeColor = ThemeColor(rawValue: s.theme_color) ?? .sage
        }
        if let b = try? await SupabaseAPI.todayBalance(), let b {
            bonusMin = b.bonus_min
        }
    }
}

@MainActor
final class AuthStore: ObservableObject {
    static let shared = AuthStore()
    @Published var signedIn = false
    @Published var loading = true

    func bootstrap() async {
        let session = try? await supabase.auth.session
        signedIn = session != nil
        loading = false
        Task {
            for await change in supabase.auth.authStateChanges {
                await MainActor.run { self.signedIn = change.session != nil }
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String, displayName: String, username: String, birthday: String?) async throws {
        try await supabase.auth.signUp(
            email: email,
            password: password,
            data: [
                "display_name": .string(displayName),
                "username": .string(username),
                "birthday": birthday.map { AnyJSON.string($0) } ?? .null,
            ]
        )
    }

    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }

    func signOut() async { try? await supabase.auth.signOut() }
}
