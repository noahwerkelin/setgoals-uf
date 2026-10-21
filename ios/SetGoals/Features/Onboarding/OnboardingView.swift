import SwiftUI
import CoreLocation
import FamilyControls

/// Redesigned onboarding: seven slides followed by the account flows.
/// Every permission goes through the real Apple API via the existing
/// services; nothing is marked as done without confirmation from iOS.
struct OnboardingView: View {
    @EnvironmentObject var theme: Theme
    /// `authOnly` is used after sign-out: skips the slides and starts at the
    /// account choice.
    var authOnly: Bool = false
    var onDone: () -> Void

    enum Step: Int, CaseIterable { case welcome, language, health, location, screenTime, apps, journey }
    enum Route: Equatable { case slides, signIn, forgot, accountType, child, signUp, celebrate }

    @AppStorage("onb.step") private var savedStep = 0
    @AppStorage("app.lang") private var lang: String = L.lang
    @State private var step: Step = .welcome
    @State private var route: Route = .slides
    @State private var forward = true
    /// Set when a returning user signs in early: remaining slides only cover
    /// missing essentials, then finish.
    @State private var postAuth = false

    var body: some View {
        ZStack {
            OnboardingBackdrop(index: route == .slides ? step.rawValue : 7)
            VStack(spacing: 0) {
                topBar.padding(.horizontal, 24).padding(.top, 8)
                ZStack {
                    content
                        .id("\(route)-\(step.rawValue)")
                        .transition(.asymmetric(
                            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: 520)
        }
        .font(F.sm)
        .foregroundStyle(theme.foreground)
        .tint(theme.primary)
        .id(lang)
        .onAppear {
            if authOnly { step = .journey }
            else { step = Step(rawValue: savedStep) ?? .welcome }
        }
        .sensoryFeedback(.selection, trigger: step)
    }

    // MARK: navigation

    private var stepsTotal: Int { Step.allCases.count + 1 }
    private var progress: Double {
        let base: Double
        switch route {
        case .slides: base = Double(step.rawValue)
        case .celebrate: base = Double(stepsTotal - 1)
        default: base = Double(Step.allCases.count)
        }
        return base / Double(stepsTotal - 1)
    }

    private var canGoBack: Bool {
        switch route {
        case .slides: return !authOnly && step != .welcome && !postAuth
        case .celebrate: return false
        default: return true
        }
    }

    func go(_ s: Step) {
        forward = s.rawValue >= step.rawValue
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { step = s }
        if !authOnly { savedStep = s.rawValue }
    }

    func open(_ r: Route) {
        forward = true
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { route = r }
    }

    private func back() {
        forward = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
            switch route {
            case .slides:
                if let prev = Step(rawValue: step.rawValue - 1) { step = prev; savedStep = prev.rawValue }
            case .forgot: route = .signIn
            case .child, .signUp: route = .accountType
            default: route = .slides
            }
        }
    }

    /// After authentication: load the account, then only ask for the
    /// essentials that are still missing on this device.
    func didAuthenticate(newAccount: Bool) {
        Task {
            await SettingsStore.shared.load()
            ScreenTimeService.shared.refreshAuthorization()
            let isChild = SettingsStore.shared.role == "child"
            let needsScreenTime = !ScreenTimeService.shared.authorized
            let needsApps = !ScreenTimeRules.hasRestrictions
            if authOnly || isChild || newAccount || !(needsScreenTime || needsApps) {
                finish(celebrate: newAccount)
            } else {
                postAuth = true
                forward = true
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                    route = .slides
                    step = needsScreenTime ? .screenTime : .apps
                }
            }
        }
    }

    func finish(celebrate: Bool) {
        savedStep = 0
        if celebrate && !authOnly {
            open(.celebrate)
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                onDone()
            }
        } else {
            onDone()
        }
    }

    // MARK: chrome

    private var topBar: some View {
        HStack(spacing: 14) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.p.s700)
                    .frame(width: 40, height: 40)
                    .background(theme.card, in: Circle())
                    .overlay(Circle().strokeBorder(theme.ringBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.t("ob.back"))
            .opacity(canGoBack ? 1 : 0)
            .disabled(!canGoBack)

            WalkerPath(progress: progress, steps: stepsTotal)
        }
        .frame(height: 44)
    }

    @ViewBuilder private var content: some View {
        switch route {
        case .slides:
            switch step {
            case .welcome: WelcomeSlide(flow: self)
            case .language: LanguageSlide(flow: self, lang: $lang)
            case .health: HealthSlide(flow: self)
            case .location: LocationSlide(flow: self)
            case .screenTime: ScreenTimeSlide(flow: self, postAuth: postAuth)
            case .apps: AppsSlide(flow: self, postAuth: postAuth)
            case .journey: JourneySlide(flow: self)
            }
        case .signIn: SignInScreen(flow: self)
        case .forgot: ForgotScreen(flow: self)
        case .accountType: AccountTypeScreen(flow: self)
        case .child: ChildCodeScreen(flow: self)
        case .signUp: SignUpScreen(flow: self)
        case .celebrate: CelebrateScreen()
        }
    }
}

// MARK: - Shared slide layout

struct SlideLayout<Art: View, Middle: View, Footer: View>: View {
    @EnvironmentObject var theme: Theme
    let title: String
    let subtitle: String
    @ViewBuilder var art: Art
    @ViewBuilder var bodyContent: Middle
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    art.rise()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(F.xl3)
                            .foregroundStyle(theme.foreground)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subtitle)
                            .font(F.sm).foregroundStyle(theme.mutedForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .rise(delay: 0.08)
                    bodyContent.rise(delay: 0.16)
                }
                .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 12)
            }
            VStack(spacing: 10) { footer }
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 16)
        }
    }
}

struct OBPrimaryButton: View {
    @EnvironmentObject var theme: Theme
    let title: String
    var busy = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        PrimaryButton(title: title, busy: busy, action: action)
            .overlay(alignment: .leading) {
                if busy {
                    ProgressView().tint(theme.primaryForeground).padding(.leading, 16)
                }
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.45)
        .sensoryFeedback(.impact(weight: .light), trigger: busy)
    }
}

struct OBTextButton: View {
    @EnvironmentObject var theme: Theme
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(F.sans(12, .medium)).foregroundStyle(theme.p.s700)
                .frame(minHeight: 32)
        }
        .buttonStyle(.plain)
    }
}

struct BenefitList: View {
    @EnvironmentObject var theme: Theme
    let items: [(String, String)]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items, id: \.1) { icon, text in
                HStack(spacing: 14) {
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.p.s700)
                        .frame(width: 36, height: 36)
                        .background(theme.secondary, in: RoundedRectangle(cornerRadius: R.lg, style: .continuous))
                    Text(text).font(F.sm).foregroundStyle(theme.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct StatusPill: View {
    @EnvironmentObject var theme: Theme
    let text: String
    var ok = true
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "info.circle.fill")
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(F.sans(12, .semibold))
        .foregroundStyle(ok ? theme.p.s700 : theme.p.s900)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(ok ? theme.p.s100 : theme.p.s200, in: Capsule())
        .transition(.scale.combined(with: .opacity))
    }
}

struct NoteBox: View {
    @EnvironmentObject var theme: Theme
    let text: String
    var settingsButton = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text).font(F.xs).foregroundStyle(theme.p.s700)
                .fixedSize(horizontal: false, vertical: true)
            if settingsButton {
                Button(L.t("ob.open_settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(F.sans(12, .semibold)).foregroundStyle(theme.p.s900)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous).strokeBorder(theme.ringBorder, lineWidth: 1))
    }
}

// MARK: - Slide 1

private struct WelcomeSlide: View {
    let flow: OnboardingView
    var body: some View {
        SlideLayout(title: L.t("ob.welcome.title"), subtitle: L.t("ob.welcome.sub")) {
            WelcomeArt()
        } bodyContent: { EmptyView() } footer: {
            OBPrimaryButton(title: L.t("ob.welcome.cta")) { flow.go(.language) }
        }
    }
}

// MARK: - Slide 2

private struct LanguageSlide: View {
    @EnvironmentObject var theme: Theme
    let flow: OnboardingView
    @Binding var lang: String
    @State private var tick = 0

    var body: some View {
        SlideLayout(title: L.t("ob.lang.title"), subtitle: L.t("ob.lang.sub")) {
            LanguageArt(lang: lang)
        } bodyContent: {
            VStack(spacing: 12) {
                card("en", "English", "🇬🇧")
                card("sv", "Svenska", "🇸🇪")
            }
        } footer: {
            OBPrimaryButton(title: L.t("ob.continue")) {
                if UserDefaults.standard.string(forKey: "app.lang") == nil { lang = L.lang }
                flow.go(.health)
            }
        }
        .sensoryFeedback(.selection, trigger: tick)
    }

    private func card(_ code: String, _ name: String, _ flag: String) -> some View {
        let on = lang == code
        return Button {
            tick += 1
            // Saved immediately; every following screen reads `app.lang`.
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { lang = code }
        } label: {
            HStack(spacing: 14) {
                Text(flag).font(.system(size: 28))
                Text(name).font(F.sans(14, .semibold)).foregroundStyle(theme.foreground)
                Spacer()
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24)).foregroundStyle(on ? theme.primary : theme.p.s300)
                    .scaleEffect(on ? 1.1 : 1)
            }
            .padding(.horizontal, 20).frame(minHeight: 56)
            .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                .strokeBorder(on ? theme.primary : theme.ringBorder, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - Slide 3

private struct HealthSlide: View {
    let flow: OnboardingView
    @AppStorage("onb.healthRequested") private var requested = false
    @State private var busy = false
    private var available: Bool { HealthKitService.shared.isAvailable }

    var body: some View {
        SlideLayout(title: L.t("ob.health.title"), subtitle: L.t("ob.health.sub")) {
            HealthArt()
        } bodyContent: {
            BenefitList(items: [("shoeprints.fill", L.t("ob.health.b1")),
                                ("hourglass", L.t("ob.health.b2")),
                                ("chart.bar.fill", L.t("ob.health.b3"))])
            if !available {
                NoteBox(text: L.t("ob.health.unavailable"))
            } else if requested {
                // HealthKit never reveals whether reading was denied, so we
                // only say the request was made — never "Connected".
                StatusPill(text: L.t("ob.health.requested"))
                NoteBox(text: L.t("ob.health.requested_note"))
            }
        } footer: {
            if available && !requested {
                OBPrimaryButton(title: L.t("ob.health.cta"), busy: busy) {
                    Task {
                        busy = true
                        await HealthKitService.shared.requestAuthorization()
                        busy = false
                        withAnimation { requested = true }
                    }
                }
            } else {
                OBPrimaryButton(title: L.t("ob.continue")) { flow.go(.location) }
            }
        }
        .sensoryFeedback(.success, trigger: requested)
    }
}

// MARK: - Slide 4

private struct LocationSlide: View {
    let flow: OnboardingView
    @StateObject private var locator = OnboardingLocator()

    var body: some View {
        SlideLayout(title: L.t("ob.loc.title"), subtitle: L.t("ob.loc.sub")) {
            MapArt()
        } bodyContent: {
            BenefitList(items: [("figure.run", L.t("ob.loc.b1")),
                                ("tree.fill", L.t("ob.loc.b2")),
                                ("map.fill", L.t("ob.loc.b3"))])
            switch locator.status {
            case .authorizedWhenInUse, .authorizedAlways: StatusPill(text: L.t("ob.loc.granted"))
            case .denied, .restricted: NoteBox(text: L.t("ob.loc.denied"), settingsButton: locator.status == .denied)
            default: EmptyView()
            }
        } footer: {
            if locator.status == .notDetermined {
                OBPrimaryButton(title: L.t("ob.loc.cta")) { locator.request() }
            } else {
                OBPrimaryButton(title: L.t("ob.continue")) { flow.go(.screenTime) }
            }
        }
        .animation(.spring, value: locator.status)
        .sensoryFeedback(.success, trigger: locator.status == .authorizedWhenInUse)
    }
}

// MARK: - Slide 5

private struct ScreenTimeSlide: View {
    let flow: OnboardingView
    let postAuth: Bool
    @ObservedObject private var st = ScreenTimeService.shared
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        SlideLayout(title: L.t("ob.st.title"), subtitle: L.t("ob.st.sub")) {
            ScreenTimeArt()
        } bodyContent: {
            BenefitList(items: [("1.circle.fill", L.t("ob.st.b1")),
                                ("2.circle.fill", L.t("ob.st.b2")),
                                ("3.circle.fill", L.t("ob.st.b3"))])
            if st.authorized { StatusPill(text: L.t("ob.st.granted")) }
            else if failed { NoteBox(text: L.t("ob.st.failed")) }
        } footer: {
            if st.authorized {
                OBPrimaryButton(title: L.t("ob.continue")) { flow.go(.apps) }
            } else {
                OBPrimaryButton(title: L.t("ob.st.cta"), busy: busy) {
                    Task {
                        busy = true
                        await st.requestAuthorization(forChild: false)
                        busy = false
                        withAnimation { failed = !st.authorized }
                    }
                }
            }
        }
        .onAppear { st.refreshAuthorization() }
        .sensoryFeedback(.success, trigger: st.authorized)
    }
}

// MARK: - Slide 6

private struct AppsSlide: View {
    @EnvironmentObject var theme: Theme
    let flow: OnboardingView
    let postAuth: Bool
    @ObservedObject private var st = ScreenTimeService.shared
    @State private var selection = ScreenTimeRules.selection(for: ScreenTimeRules.managedKey)
    @State private var showPicker = false
    @State private var saved = 0

    /// Everything SetGoals will restrict, including choices already made in
    /// Settings, so an existing setup is shown and never silently replaced.
    private var total: FamilyActivitySelection {
        var all = ScreenTimeRules.restricted
        all.applicationTokens.formUnion(selection.applicationTokens)
        all.categoryTokens.formUnion(selection.categoryTokens)
        all.webDomainTokens.formUnion(selection.webDomainTokens)
        return all
    }
    private var hasAny: Bool {
        !(total.applicationTokens.isEmpty && total.categoryTokens.isEmpty && total.webDomainTokens.isEmpty)
    }

    var body: some View {
        SlideLayout(title: L.t("ob.apps.title"), subtitle: L.t("ob.apps.sub")) {
            ArtCard {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(54), spacing: 14), count: 4), spacing: 14) {
                    ForEach(0..<8, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(i < min(8, total.applicationTokens.count + total.categoryTokens.count * 2)
                                  ? theme.p.s500 : theme.p.s200)
                            .frame(width: 54, height: 54)
                            .overlay(Image(systemName: "hourglass").foregroundStyle(theme.card.opacity(0.9)))
                    }
                }
                .animation(.spring, value: total.applicationTokens.count + total.categoryTokens.count)
            }
        } bodyContent: {
            if !st.authorized {
                NoteBox(text: L.t("ob.apps.need_auth"))
                Button(L.t("ob.apps.go_auth")) { flow.go(.screenTime) }
                    .font(F.sans(14, .semibold)).foregroundStyle(theme.p.s900)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: hasAny ? "checkmark.seal.fill" : "square.grid.2x2")
                            .font(.system(size: 22)).foregroundStyle(hasAny ? theme.primary : theme.p.s500)
                        Text(hasAny
                             ? L.t("ob.apps.summary", ["a": "\(total.applicationTokens.count)",
                                                        "c": "\(total.categoryTokens.count)",
                                                        "w": "\(total.webDomainTokens.count)"])
                             : L.t("ob.apps.none"))
                            .font(F.sans(14, .semibold)).foregroundStyle(theme.p.s950)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button { showPicker = true } label: {
                        Label(hasAny ? L.t("ob.apps.edit") : L.t("ob.apps.pick"), systemImage: "plus.app")
                            .font(F.sans(14, .semibold)).foregroundStyle(theme.p.s900)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(theme.p.s100, in: Capsule())
                            .overlay(Capsule().strokeBorder(theme.p.s200, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Text(L.t("ob.apps.explain")).font(F.xs).foregroundStyle(theme.p.s600)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous).strokeBorder(theme.ringBorder, lineWidth: 1))
            }
        } footer: {
            if st.authorized && !hasAny {
                Text(L.t("ob.apps.need_one")).font(F.xs).foregroundStyle(theme.p.s600)
            }
            OBPrimaryButton(title: L.t("ob.apps.cta"), enabled: st.authorized && hasAny) {
                // Saved into the same shared rules the shields and the monitor
                // extension read, so this selection is what gets locked.
                ScreenTimeService.shared.setSelection(selection, for: ScreenTimeRules.managedKey)
                saved += 1
                if postAuth { flow.finish(celebrate: false) } else { flow.go(.journey) }
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .sensoryFeedback(.success, trigger: saved)
    }
}

// MARK: - Slide 7

private struct JourneySlide: View {
    let flow: OnboardingView
    var body: some View {
        SlideLayout(title: L.t("ob.journey.title"), subtitle: L.t("ob.journey.sub")) {
            FinishArt()
        } bodyContent: {
            VStack(spacing: 12) {
                ChoiceCard(icon: "sparkles", title: L.t("ob.journey.new"), desc: L.t("ob.journey.new_desc")) {
                    flow.open(.accountType)
                }
                ChoiceCard(icon: "person.crop.circle.badge.checkmark", title: L.t("ob.journey.existing"),
                           desc: L.t("ob.journey.existing_desc")) {
                    flow.open(.signIn)
                }
            }
        } footer: { EmptyView() }
    }
}

struct ChoiceCard: View {
    @EnvironmentObject var theme: Theme
    let icon: String
    let title: String
    let desc: String
    let action: () -> Void
    @State private var pressed = 0

    var body: some View {
        Button { pressed += 1; action() } label: {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(theme.p.s700)
                    .frame(width: 44, height: 44)
                    .background(theme.secondary,
                                in: RoundedRectangle(cornerRadius: R.lg, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(F.sans(14, .semibold)).foregroundStyle(theme.p.s950)
                    Text(desc).font(F.xs).foregroundStyle(theme.p.s600)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.p.s500)
            }
            .padding(20)
            .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.xl3, style: .continuous).strokeBorder(theme.ringBorder, lineWidth: 1))
            .shadow(color: theme.ringBorder, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PressScale())
        .sensoryFeedback(.impact(weight: .light), trigger: pressed)
    }
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Core Location "When In Use" prompt used by onboarding. Reflects changes
/// made in iOS Settings automatically through the delegate.
@MainActor
final class OnboardingLocator: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status: CLAuthorizationStatus = .notDetermined
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        status = manager.authorizationStatus
    }

    func request() { manager.requestWhenInUseAuthorization() }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let s = m.authorizationStatus
        Task { @MainActor in
            self.status = s
            if s == .authorizedWhenInUse || s == .authorizedAlways { NearbyStore.shared.start() }
        }
    }
}
