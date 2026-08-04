import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Real Screen Time enforcement, replacing the web mock in
/// `src/lib/screentime.ts`. Categories match the Apple ScreenTime
/// categories the settings screen already shows (Social, Games,
/// Entertainment, ...), and each is either "always allow" or
/// "only when the user has earned screen time to spend".
enum CategoryPolicy: String, Codable, CaseIterable {
    case alwaysAllow      // green pill in the web UI
    case earnedOnly       // amber/red pill in the web UI
}

struct ScreenTimeCategory: Identifiable, Codable {
    let id: String        // "social", "games", "entertainment", ...
    var labelKey: String
    var policy: CategoryPolicy
    /// PRO: maximum minutes for this category per day (nil = no cap).
    var dailyMaxMin: Int?
}

@MainActor
final class ScreenTimeService: ObservableObject {
    static let shared = ScreenTimeService()

    private let store = ManagedSettingsStore(named: .init("setgoals"))
    private let center = AuthorizationCenter.shared

    @Published var authorized = false
    @Published var selection = FamilyActivitySelection()
    @Published var categories: [ScreenTimeCategory] = [
        .init(id: "social", labelKey: "st.cat.social", policy: .earnedOnly, dailyMaxMin: nil),
        .init(id: "games", labelKey: "st.cat.games", policy: .earnedOnly, dailyMaxMin: nil),
        .init(id: "entertainment", labelKey: "st.cat.entertainment", policy: .earnedOnly, dailyMaxMin: nil),
        .init(id: "creativity", labelKey: "st.cat.creativity", policy: .alwaysAllow, dailyMaxMin: nil),
        .init(id: "education", labelKey: "st.cat.education", policy: .alwaysAllow, dailyMaxMin: nil),
        .init(id: "productivity", labelKey: "st.cat.productivity", policy: .alwaysAllow, dailyMaxMin: nil),
    ]

    /// Individual account: authorize self. Parent account: authorize the child
    /// device with `.child` so the parent's restrictions cannot be removed.
    func requestAuthorization(forChild: Bool) async {
        do {
            try await center.requestAuthorization(for: forChild ? .child : .individual)
            authorized = center.authorizationStatus == .approved
        } catch {
            authorized = false
        }
    }

    /// Called whenever earned/remaining minutes change. When the balance hits
    /// zero every `earnedOnly` category is shielded; when there is time left
    /// the shield lifts.
    func apply(remainingMin: Int) {
        let shouldShield = remainingMin <= 0
        if shouldShield {
            store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty
                ? nil
                : .specific(selection.categoryTokens)
            store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        } else {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomains = nil
        }
    }

    /// Schedules a daily DeviceActivity window so usage is measured and the
    /// balance resets at local midnight, matching `src/lib/day.ts`.
    func scheduleDailyMonitoring() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let center = DeviceActivityCenter()
        try? center.startMonitoring(.init("setgoals.daily"), during: schedule)
    }

    func clearAllShields() {
        store.clearAllSettings()
    }
}
