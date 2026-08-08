import Foundation
import Combine

/// Port of `src/lib/screentime.ts` (`ProST`) — PRO screen-time rules kept in
/// `UserDefaults`, mirroring the web `sg.st.pro.v1` localStorage payload.
final class ProSTStore: ObservableObject {
    static let shared = ProSTStore()

    @Published var rollover: Bool { didSet { d.set(rollover, forKey: "st.rollover") } }
    @Published var weekend2x: Bool { didSet { d.set(weekend2x, forKey: "st.weekend2x") } }
    @Published var splitCaps: Bool { didSet { d.set(splitCaps, forKey: "st.splitCaps") } }
    @Published var weekdayCap: Int { didSet { d.set(weekdayCap, forKey: "st.weekdayCap") } }
    @Published var weekendCap: Int { didSet { d.set(weekendCap, forKey: "st.weekendCap") } }
    @Published var catLimits: [String: Int] { didSet { d.set(catLimits, forKey: "st.catLimits") } }
    /// Category permissions: `true` = always allow, `false` = only with earned time.
    @Published var alwaysAllow: [String: Bool] { didSet { d.set(alwaysAllow, forKey: "st.alwaysAllow") } }

    private let d = UserDefaults.standard

    private init() {
        rollover = d.bool(forKey: "st.rollover")
        weekend2x = d.bool(forKey: "st.weekend2x")
        splitCaps = d.bool(forKey: "st.splitCaps")
        weekdayCap = d.object(forKey: "st.weekdayCap") as? Int ?? 3
        weekendCap = d.object(forKey: "st.weekendCap") as? Int ?? 5
        catLimits = d.dictionary(forKey: "st.catLimits") as? [String: Int] ?? [:]
        alwaysAllow = d.dictionary(forKey: "st.alwaysAllow") as? [String: Bool]
            ?? ScreenTimeCategories.defaults
    }
}

enum ScreenTimeCategories {
    /// Same order and default states as `INITIAL_APPS` in `src/routes/parent.tsx`.
    static let keys = [
        "cat.social", "cat.games", "cat.entertainment", "cat.creativity",
        "cat.productivity", "cat.education", "cat.health", "cat.shopping", "cat.utilities",
    ]
    static let defaults: [String: Bool] = [
        "cat.social": false, "cat.games": false, "cat.entertainment": false,
        "cat.creativity": true, "cat.productivity": true, "cat.education": true,
        "cat.health": true, "cat.shopping": false, "cat.utilities": true,
    ]
}
