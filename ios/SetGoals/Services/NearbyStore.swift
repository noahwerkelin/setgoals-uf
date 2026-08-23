import Foundation
import Combine
import CoreLocation

/// Shared nearby-activity state. Loading starts as soon as the app opens so
/// the map page already has its pins and list ready when the user gets there.
@MainActor
final class NearbyStore: ObservableObject {
    static let shared = NearbyStore()

    @Published var activities: [NearbyActivity] = []
    @Published var loading = false

    let locator = Locator.shared

    private var bag = Set<AnyCancellable>()
    private var lastKey = ""
    private var started = false

    private init() {
        locator.$centerKey
            .receive(on: RunLoop.main)
            .sink { [weak self] key in
                guard let self, !key.isEmpty, key != self.lastKey else { return }
                self.lastKey = key
                Task { await self.load() }
            }
            .store(in: &bag)
    }

    /// Called once at app launch — asks for the location and preloads.
    func start() {
        guard !started else { return }
        started = true
        locator.request()
    }

    /// The "my location" button: re-reads the position and reloads activities.
    func refresh() {
        locator.request()
        Task { await load(force: true) }
    }

    func load(force: Bool = false) async {
        guard let c = locator.center else { return }
        if loading && !force { return }
        loading = true
        defer { loading = false }
        let found = (try? await ActivitiesService.nearby(lat: c.latitude, lng: c.longitude)) ?? []
        activities = found.sorted { $0.distanceM < $1.distanceM }
    }
}
