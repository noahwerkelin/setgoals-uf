import Foundation
import FamilyControls
import ManagedSettings

/// Shared, persisted mapping between the app-category rows the user sees
/// ("Always" / "Only with earned time") and the real Apple Screen Time tokens
/// that get shielded.
///
/// Lives in the app group so the DeviceActivityMonitor extension shields the
/// exact same set of apps the app itself does — never "everything", so the
/// SetGoals app and every always-allowed category stay reachable.
enum ScreenTimeRules {
    private static var store: UserDefaults {
        UserDefaults(suiteName: ScreenTimeBudget.appGroup) ?? .standard
    }

    private enum K {
        static let policies = "rules.policies"      // [String: Bool] true == always allow
        static let selections = "rules.selections"  // [String: Data] encoded FamilyActivitySelection
    }

    /// Category keys, same order/ids as the settings rows.
    static let categoryKeys = [
        "cat.social", "cat.games", "cat.entertainment", "cat.creativity",
        "cat.productivity", "cat.education", "cat.health", "cat.shopping", "cat.utilities",
    ]

    static let defaultPolicies: [String: Bool] = [
        "cat.social": false, "cat.games": false, "cat.entertainment": false,
        "cat.creativity": true, "cat.productivity": true, "cat.education": true,
        "cat.health": true, "cat.shopping": false, "cat.utilities": true,
    ]

    /// `true` = always allowed, `false` = only usable while screen time remains.
    static var policies: [String: Bool] {
        get { (store.dictionary(forKey: K.policies) as? [String: Bool]) ?? defaultPolicies }
        set { store.set(newValue, forKey: K.policies) }
    }

    static func isAlwaysAllowed(_ key: String) -> Bool {
        policies[key] ?? defaultPolicies[key] ?? true
    }

    // MARK: selections

    private static var rawSelections: [String: Data] {
        get { (store.dictionary(forKey: K.selections) as? [String: Data]) ?? [:] }
        set { store.set(newValue, forKey: K.selections) }
    }

    static func selection(for key: String) -> FamilyActivitySelection {
        guard let data = rawSelections[key],
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return sel
    }

    static func setSelection(_ selection: FamilyActivitySelection, for key: String) {
        var raw = rawSelections
        raw[key] = (try? JSONEncoder().encode(selection)) ?? Data()
        rawSelections = raw
    }

    static func isConfigured(_ key: String) -> Bool {
        let s = selection(for: key)
        return !(s.applicationTokens.isEmpty && s.categoryTokens.isEmpty && s.webDomainTokens.isEmpty)
    }

    // MARK: resolved token sets

    private static func union(where alwaysAllowed: Bool) -> FamilyActivitySelection {
        var apps = Set<ApplicationToken>()
        var cats = Set<ActivityCategoryToken>()
        var webs = Set<WebDomainToken>()
        for key in categoryKeys where isAlwaysAllowed(key) == alwaysAllowed {
            let s = selection(for: key)
            apps.formUnion(s.applicationTokens)
            cats.formUnion(s.categoryTokens)
            webs.formUnion(s.webDomainTokens)
        }
        var out = FamilyActivitySelection()
        out.applicationTokens = apps
        out.categoryTokens = cats
        out.webDomainTokens = webs
        return out
    }

    /// Apps/categories that lock when the earned screen time runs out.
    static var restricted: FamilyActivitySelection { union(where: false) }

    /// Apps the user marked "Always" — they are used as shield exceptions so
    /// they, and SetGoals itself, never get locked.
    static var alwaysAllowed: FamilyActivitySelection { union(where: true) }

    static var hasRestrictions: Bool {
        let r = restricted
        return !(r.applicationTokens.isEmpty && r.categoryTokens.isEmpty && r.webDomainTokens.isEmpty)
    }

    /// Applies (or lifts) the shields for the restricted set only.
    /// `store` is the app-group ManagedSettingsStore shared with the extension.
    static func apply(shielding: Bool, to managed: ManagedSettingsStore) {
        guard shielding else {
            managed.shield.applications = nil
            managed.shield.applicationCategories = nil
            managed.shield.webDomains = nil
            managed.shield.webDomainCategories = nil
            return
        }

        let restricted = self.restricted
        let exceptions = alwaysAllowed.applicationTokens

        managed.shield.applications = restricted.applicationTokens.isEmpty
            ? nil
            : restricted.applicationTokens.subtracting(exceptions)

        managed.shield.applicationCategories = restricted.categoryTokens.isEmpty
            ? nil
            : .specific(restricted.categoryTokens, except: exceptions)

        managed.shield.webDomains = restricted.webDomainTokens.isEmpty
            ? nil
            : restricted.webDomainTokens

        // Never `.all()` — that would also lock SetGoals itself.
        managed.shield.webDomainCategories = nil
    }
}
