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

/// Failures that must never be reported to the user as a granted reward.
enum ScreenTimeError: LocalizedError {
    case notAuthorized
    case monitoringFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Screen Time access is not authorized."
        case .monitoringFailed(let m): return m
        }
    }
}

@MainActor
final class ScreenTimeService: ObservableObject {
    static let shared = ScreenTimeService()

    private let store = ManagedSettingsStore(named: .init("setgoals"))
    private let center = AuthorizationCenter.shared
    private let activityName = DeviceActivityName("setgoals.daily")

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

    /// Mirrors of the shared ledger so SwiftUI redraws when they change.
    @Published private(set) var allowanceMin: Int = ScreenTimeBudget.allowanceMin
    @Published private(set) var usedMin: Int = ScreenTimeBudget.usedMin
    @Published private(set) var rewardMin: Int = ScreenTimeBudget.rewardMin

    /// Minutes left before Apple's Screen Time shields lock the managed apps.
    var remainingMin: Int { max(0, allowanceMin - usedMin) }

    private init() {
        refreshAuthorization()
        refreshFromStore()
    }

    // MARK: authorization

    func refreshAuthorization() {
        authorized = center.authorizationStatus == .approved
    }

    /// Individual account: authorize self. Parent account: authorize the child
    /// device with `.child` so the parent's restrictions cannot be removed.
    func requestAuthorization(forChild: Bool = false) async {
        do {
            try await center.requestAuthorization(for: forChild ? .child : .individual)
            authorized = center.authorizationStatus == .approved
        } catch {
            authorized = false
        }
    }

    // MARK: ledger

    /// Re-reads the shared ledger (app launch, foreground, after an extension
    /// recorded usage) and re-applies shields to match.
    func refreshFromStore() {
        ScreenTimeBudget.rollIfNeeded()
        selection = ScreenTimeRules.restricted
        allowanceMin = ScreenTimeBudget.allowanceMin
        usedMin = ScreenTimeBudget.usedMin
        rewardMin = ScreenTimeBudget.rewardMin
        applyShields()
    }

    /// Sets today's step/bonus derived allowance. Challenge rewards are kept
    /// separately so they survive step recalculation.
    func setBaseAllowance(_ minutes: Int) {
        guard ScreenTimeBudget.baseMin != minutes else {
            refreshFromStore()
            return
        }
        ScreenTimeBudget.baseMin = minutes
        refreshFromStore()
        restartMonitoring()
    }

    /// Genuinely grants extra screen time through Apple's Screen Time system:
    /// the allowance grows, the shields lift, and the DeviceActivity budget is
    /// rescheduled with the new threshold. Throws when Screen Time cannot be
    /// changed, so callers must not claim the reward.
    func grant(minutes: Int) throws {
        guard minutes > 0 else { return }
        refreshAuthorization()
        guard authorized else { throw ScreenTimeError.notAuthorized }

        ScreenTimeBudget.rewardMin += minutes
        refreshFromStore()
        do {
            try startMonitoring()
        } catch {
            // Roll back: the reward was not really put into effect.
            ScreenTimeBudget.rewardMin = max(0, ScreenTimeBudget.rewardMin - minutes)
            refreshFromStore()
            throw ScreenTimeError.monitoringFailed(error.localizedDescription)
        }
    }

    // MARK: enforcement

    /// Shields only the categories the user marked "Only with earned time"
    /// when nothing is left, and lifts the shield as soon as there are minutes
    /// to spend. Always-allowed apps (and SetGoals itself) are never shielded.
    private func applyShields() {
        ScreenTimeRules.apply(shielding: remainingMin <= 0, to: store)
    }

    // MARK: category rules

    /// Called from the settings rows: switches a category between
    /// "Always" and "Only with earned time" and re-applies the real shields.
    func setPolicy(alwaysAllow: Bool, for key: String) {
        var p = ScreenTimeRules.policies
        p[key] = alwaysAllow
        ScreenTimeRules.policies = p
        refreshFromStore()
        restartMonitoring()
    }

    /// Called when the user picks which apps belong to a category.
    func setSelection(_ sel: FamilyActivitySelection, for key: String) {
        ScreenTimeRules.setSelection(sel, for: key)
        selection = ScreenTimeRules.restricted
        refreshFromStore()
        restartMonitoring()
    }

    func selection(for key: String) -> FamilyActivitySelection {
        ScreenTimeRules.selection(for: key)
    }

    /// Kept for existing call sites: the ledger stays the source of truth, this
    /// only forces a re-evaluation of the shields.
    func apply(remainingMin: Int) {
        refreshFromStore()
    }

    // MARK: DeviceActivity

    /// Schedules a daily window plus one threshold event every 5 minutes of
    /// managed-app usage. The monitor extension records each tick into the
    /// shared ledger and shields when the budget is spent, so time actually
    /// spent is subtracted from "Remaining".
    func startMonitoring() throws {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        if !(selection.applicationTokens.isEmpty
             && selection.categoryTokens.isEmpty
             && selection.webDomainTokens.isEmpty) {
            let step = 5
            let ticks = max(1, min(48, Int(ceil(Double(allowanceMin) / Double(step)))))
            for i in 1...ticks {
                let minutes = i * step
                events[DeviceActivityEvent.Name("tick.\(minutes)")] = DeviceActivityEvent(
                    applications: selection.applicationTokens,
                    categories: selection.categoryTokens,
                    webDomains: selection.webDomainTokens,
                    threshold: DateComponents(minute: minutes)
                )
            }
        }

        let center = DeviceActivityCenter()
        center.stopMonitoring([activityName])
        try center.startMonitoring(activityName, during: schedule, events: events)
    }

    private func restartMonitoring() {
        try? startMonitoring()
    }

    /// Legacy entry point used at app launch.
    func scheduleDailyMonitoring() {
        try? startMonitoring()
    }

    func clearAllShields() {
        store.clearAllSettings()
    }
}
