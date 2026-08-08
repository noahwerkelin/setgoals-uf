import SwiftUI
import MapKit
import CoreLocation

// MARK: - Model (port of `src/lib/activities.server.ts`)

enum ActivityKind: String, Codable, CaseIterable, Hashable {
    case Hiking, Running, Cycling, Swim, Family, Gym, Nature
}

struct NearbyActivity: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let kind: ActivityKind
    let lat: Double
    let lng: Double
    let distanceM: Double
    let source: String
    let sourceId: String
    var rating: Double?
    var userRatingsTotal: Int?
    var photoUrl: String?
    var openNow: Bool?
    var address: String?

    var coord: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
}

/// Calls the same backend as the web app (`findNearbyActivities`), exposed to
/// the native client at `/api/public/nearby-activities` behind a bearer token.
enum ActivitiesService {
    static let endpoint = URL(string: "https://step-wise-life.lovable.app/api/public/nearby-activities")!

    private struct Payload: Codable { let activities: [NearbyActivity] }

    static func nearby(lat: Double, lng: Double, radiusM: Int = 8000) async throws -> [NearbyActivity] {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = try? await supabase.auth.session.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "lat": lat, "lng": lng, "radiusM": radiusM,
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return (try JSONDecoder().decode(Payload.self, from: data)).activities
    }
}

// MARK: - Page (port of `src/routes/map.tsx`)

struct ActivityMapView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @Binding var tab: AppTab

    @StateObject private var locator = Locator()
    @State private var activities: [NearbyActivity] = []
    @State private var filter: Filter = .all
    @State private var loading = false
    @State private var pageSize = 5
    @State private var expandedID: String?
    @State private var camera: MapCameraPosition = .automatic

    enum Filter: Hashable {
        case all
        case kind(ActivityKind)

        var key: String {
            switch self {
            case .all: return "All"
            case .kind(let k): return k.rawValue
            }
        }
    }

    private static let filters: [Filter] = [
        .all, .kind(.Hiking), .kind(.Running), .kind(.Cycling),
        .kind(.Swim), .kind(.Gym), .kind(.Nature), .kind(.Family),
    ]

    private var visible: [NearbyActivity] {
        switch filter {
        case .all: return activities
        case .kind(let k): return activities.filter { $0.kind == k }
        }
    }

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(eyebrow: L.t("map.eyebrow"), title: L.t("map.title")) {
                HStack(spacing: 8) {
                    circleButton("arrow.clockwise", spinning: loading,
                                 label: L.t("map.refresh")) { Task { await load(force: true) } }
                    circleButton("location.fill", pulsing: locator.locating,
                                 label: L.t("map.use_location")) { locator.request() }
                }
            }

            VStack(spacing: 20) {
                mapCard
                filterRow

                if loading && locator.center != nil {
                    hint(L.t("map.loading"))
                } else if !loading && locator.center != nil && visible.isEmpty {
                    hint(L.t("map.none"))
                }

                list
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .task { locator.request() }
        .onChange(of: locator.centerKey) { _, _ in Task { await load() } }
        .onChange(of: filter) { _, _ in pageSize = 5; expandedID = nil }
    }

    // MARK: Map — `aspect-[4/3] rounded-[28px] ring-1 ring-black/5`

    private var mapCard: some View {
        ZStack(alignment: .bottomLeading) {
            if let c = locator.center {
                Map(position: $camera) {
                    Annotation(L.t("map.you_here"), coordinate: c) { youDot }
                    ForEach(visible) { a in
                        Annotation(a.name, coordinate: a.coord) {
                            SagePin(kind: a.kind, size: 40)
                                .onTapGesture { expandedID = a.id }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))

                Text("\(String(format: "%.3f", c.latitude)), \(String(format: "%.3f", c.longitude))")
                    .font(F.xs)
                    .foregroundStyle(theme.p.s900)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                        .strokeBorder(theme.ringBorder, lineWidth: 1))
                    .padding(16)
                    .allowsHitTesting(false)
            } else {
                theme.p.s100
                Text(locator.denied ? L.t("map.location_denied") : L.t("map.locating"))
                    .font(F.sm).foregroundStyle(theme.p.s700)
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
            .strokeBorder(theme.ringBorder, lineWidth: 1))
        .rise()
    }

    private var youDot: some View {
        Circle().fill(theme.p.s600)
            .frame(width: 16, height: 16)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .background(Circle().fill(theme.p.s600.opacity(0.2)).frame(width: 32, height: 32))
            .shadow(color: .black.opacity(0.2), radius: 5, y: 4)
    }

    // MARK: Filters

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.filters, id: \.self) { f in
                    let on = f == filter
                    Button { filter = f } label: {
                        Text(L.t("map.kind.\(f.key)"))
                            .font(F.sans(12, .medium))
                            .foregroundStyle(on ? theme.primaryForeground : theme.p.s700)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(on ? theme.p.s600 : theme.card, in: Capsule())
                            .overlay(Capsule().strokeBorder(theme.ringBorder, lineWidth: 1))
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: List

    private var list: some View {
        VStack(spacing: 12) {
            ForEach(Array(visible.prefix(pageSize).enumerated()), id: \.element.id) { i, a in
                card(a).rise(delay: Double(min(i, 8)) * 0.04)
            }

            if visible.count > pageSize {
                Button { pageSize += 5 } label: {
                    Text("\(L.t("map.show_more")) (\(visible.count - pageSize))")
                        .font(F.sans(12, .semibold)).foregroundStyle(theme.p.s700)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                            .strokeBorder(theme.ringBorder, lineWidth: 1))
                }
            }
            if visible.count > 5 && pageSize > 5 {
                Button { pageSize = 5 } label: {
                    Text(L.t("map.show_less"))
                        .font(F.sans(12, .medium)).foregroundStyle(theme.p.s600)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
            }
        }
    }

    private func card(_ a: NearbyActivity) -> some View {
        let open = expandedID == a.id
        let d = settings.formatDistance(a.distanceM / 1000)
        return VStack(spacing: 0) {
            Button { expandedID = open ? nil : a.id } label: {
                HStack(spacing: 16) {
                    SagePin(kind: a.kind, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.name).font(F.sans(14, .semibold)).lineLimit(1)
                            .foregroundStyle(theme.foreground)
                        HStack(spacing: 4) {
                            Text("\(L.t("map.kind.\(a.kind.rawValue)")) · \(d.0) \(d.1)")
                            if let r = a.rating {
                                Text("·")
                                Image(systemName: "star.fill").font(.system(size: 9))
                                Text(String(format: "%.1f", r))
                            }
                        }
                        .font(F.xs).foregroundStyle(theme.p.s600).lineLimit(1)
                        Text(subtitle(a)).eyebrow(theme.p.s500).lineLimit(1).padding(.top, 1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 13))
                        .foregroundStyle(theme.p.s600)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(alignment: .leading, spacing: 12) {
                    if let photo = a.photoUrl, let url = URL(string: photo) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            theme.p.s100
                        }
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                            .strokeBorder(theme.ringBorder, lineWidth: 1))
                    }

                    VStack(spacing: 8) {
                        detailRow(L.t("map.distance"), "\(d.0) \(d.1)")
                        if let r = a.rating {
                            detailRow(L.t("map.rating"),
                                      String(format: "%.1f", r) + (a.userRatingsTotal.map { " (\($0))" } ?? ""))
                        }
                        if let addr = a.address { detailRow(L.t("map.address"), addr) }
                    }

                    Button { openDirections(a) } label: {
                        Text(L.t("map.start"))
                            .font(F.sans(12, .semibold))
                            .foregroundStyle(theme.primaryForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(theme.p.s600, in: RoundedRectangle(cornerRadius: R.sm, style: .continuous))
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 16).padding(.top, 12)
                .overlay(alignment: .top) { Rectangle().fill(theme.p.s100).frame(height: 1) }
            }
        }
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
            .strokeBorder(theme.ringBorder, lineWidth: 1))
    }

    private func subtitle(_ a: NearbyActivity) -> String {
        var s = L.t("map.source.\(a.source)")
        if a.openNow == true { s += " · " + L.t("map.open_now") }
        if a.openNow == false { s += " · " + L.t("map.closed") }
        return s
    }

    private func detailRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(F.xs).foregroundStyle(theme.p.s500)
            Spacer(minLength: 12)
            Text(v).font(F.sans(12, .medium)).foregroundStyle(theme.p.s900)
                .multilineTextAlignment(.trailing).lineLimit(2)
        }
    }

    private func hint(_ s: String) -> some View {
        Text(s).font(F.sm).foregroundStyle(theme.p.s600)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity).padding(.vertical, 24)
    }

    private func circleButton(_ icon: String, spinning: Bool = false, pulsing: Bool = false,
                              label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(theme.card)
                Circle().strokeBorder(theme.ringBorder, lineWidth: 1)
                Image(systemName: icon).font(.system(size: 15))
                    .foregroundStyle(theme.p.s700)
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                    .animation(spinning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                               value: spinning)
                    .opacity(pulsing ? 0.5 : 1)
                    .animation(pulsing ? .easeInOut(duration: 0.9).repeatForever() : .default, value: pulsing)
            }
            .frame(width: 40, height: 40)
        }
        .accessibilityLabel(label)
    }

    // MARK: Data

    private func load(force: Bool = false) async {
        guard let c = locator.center else { return }
        if loading && !force { return }
        loading = true
        defer { loading = false }
        camera = .region(MKCoordinateRegion(center: c, latitudinalMeters: 6000, longitudinalMeters: 6000))
        activities = (try? await ActivitiesService.nearby(lat: c.latitude, lng: c.longitude)) ?? []
            .sorted { $0.distanceM < $1.distanceM }
    }

    private func openDirections(_ a: NearbyActivity) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: a.coord))
        item.name = a.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

// MARK: - Sage pin (port of the SVG marker in `ActivityMap.tsx`)

struct SagePin: View {
    @EnvironmentObject var theme: Theme
    let kind: ActivityKind
    var size: CGFloat = 44

    private var symbol: String {
        switch kind {
        case .Hiking, .Nature: return "mountain.2.fill"
        case .Running: return "figure.run"
        case .Cycling: return "bicycle"
        case .Swim: return "figure.pool.swim"
        case .Family: return "house.fill"
        case .Gym: return "dumbbell.fill"
        }
    }

    var body: some View {
        ZStack {
            PinShape()
                .fill(theme.p.s600)
                .overlay(PinShape().strokeBorder(Color.white, lineWidth: 2.5))
                .frame(width: size, height: size * 1.2)
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .offset(y: -size * 0.12)
        }
        .frame(width: size, height: size * 1.2)
        .shadow(color: .black.opacity(0.18), radius: 3, y: 4)
    }
}

/// `M20 47 C20 47 4 30 4 18 A16 16 0 1 1 36 18 C36 30 20 47 20 47 Z` in a 40x48 box.
private struct PinShape: InsettableShape {
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> PinShape {
        var s = self; s.inset += amount; return s
    }

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 40, sy = rect.height / 48
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var path = Path()
        path.move(to: p(20, 47))
        path.addCurve(to: p(4, 18), control1: p(20, 47), control2: p(4, 30))
        path.addArc(center: p(20, 18), radius: 16 * sx,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addCurve(to: p(20, 47), control1: p(36, 30), control2: p(20, 47))
        path.closeSubpath()
        return path.strokedPath(.init(lineWidth: 0)).isEmpty ? path : path
    }
}

// MARK: - Location (port of the browser geolocation flow)

@MainActor
final class Locator: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var center: CLLocationCoordinate2D?
    @Published var locating = false
    @Published var denied = false
    /// Changes only when the rounded position moves — mirrors the web query key.
    @Published var centerKey: String = ""

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func request() {
        locating = true
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        Task { @MainActor in
            center = c
            denied = false
            locating = false
            centerKey = String(format: "%.3f,%.3f", c.latitude, c.longitude)
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locating = false
            denied = true
        }
    }
}
