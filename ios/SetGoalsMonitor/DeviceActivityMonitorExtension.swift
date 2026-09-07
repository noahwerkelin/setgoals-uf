import DeviceActivity
import ManagedSettings
import Foundation

/// Apple-side half of the screen-time budget. Apple measures usage of the
/// managed apps and calls this extension at each 5-minute threshold; the
/// extension writes the measured usage into the shared ledger and shields the
/// apps as soon as the earned budget is spent.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore(named: .init("setgoals"))

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // New day window: roll the ledger and lift yesterday's shields.
        ScreenTimeBudget.rollIfNeeded()
        clearShields()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                         activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        // Event names are "tick.<minutes of measured usage>".
        let parts = event.rawValue.split(separator: ".")
        guard let minutes = parts.last.flatMap({ Int($0) }) else { return }

        ScreenTimeBudget.usedMin = max(ScreenTimeBudget.usedMin, minutes)

        if ScreenTimeBudget.remainingMin <= 0 {
            applyShields()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        clearShields()
    }

    private func applyShields() {
        store.shield.applicationCategories = .all()
        store.shield.webDomainCategories = .all()
    }

    private func clearShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }
}
