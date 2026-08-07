import SwiftUI
import MapKit
import CoreLocation

/// Port of `src/routes/map.tsx` + `src/components/ActivityMap.tsx`.
/// Live map with the user's position, today's walked route and the same
/// stat strip beneath it.
struct ActivityMapView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @ObservedObject var health = HealthKitService.shared
    @StateObject private var tracker = RouteTracker()
    @Binding var tab: AppTab

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(eyebrow: L.t("map.eyebrow"), title: L.t("map.title")) {
                Button { tracker.recenter() } label: {
                    ZStack {
                        Circle().fill(theme.p.s100)
                        Image(systemName: "location.fill").font(.system(size: 15))
                            .foregroundStyle(theme.p.s700)
                    }
                    .frame(width: 40, height: 40)
                }
            }
            VStack(spacing: 20) {
                mapCard
                statsRow
                routeCard
            }
            .padding(.horizontal, 24)
        }
        .task { tracker.start() }
        .onDisappear { tracker.stop() }
    }

    private var mapCard: some View {
        Map(position: $tracker.camera) {
            UserAnnotation()
            if tracker.route.count > 1 {
                MapPolyline(coordinates: tracker.route)
                    .stroke(theme.p.s600, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                .strokeBorder(theme.ringBorder, lineWidth: 1)
        )
        .rise()
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            StatTile(systemImage: "figure.walk", label: L.t("map.steps"),
                     value: health.steps.formatted(), unit: "")
            let d = settings.formatDistance(health.distanceKm)
            StatTile(systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                     label: L.t("map.distance"), value: d.0, unit: d.1)
        }
        .rise(delay: 0.06)
    }

    private var routeCard: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("map.today_route")).eyebrow(theme.p.s600)
                if tracker.route.isEmpty {
                    Text(L.t("map.no_route")).font(F.sm).foregroundStyle(theme.p.s600)
                } else {
                    let d = settings.formatDistance(tracker.distanceKm)
                    Text("\(d.0) \(d.1) · \(tracker.route.count) \(L.t("map.points"))")
                        .font(F.sans(14, .medium)).foregroundStyle(theme.p.s900)
                }
            }
        }
        .rise(delay: 0.12)
    }
}

@MainActor
final class RouteTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @Published var route: [CLLocationCoordinate2D] = []
    @Published var distanceKm: Double = 0

    private let manager = CLLocationManager()
    private var last: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        manager.activityType = .fitness
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() { manager.stopUpdatingLocation() }

    func recenter() { camera = .userLocation(fallback: .automatic) }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let points = locations
        Task { @MainActor in
            for loc in points {
                if let last { distanceKm += loc.distance(from: last) / 1000 }
                last = loc
                route.append(loc.coordinate)
            }
        }
    }
}
