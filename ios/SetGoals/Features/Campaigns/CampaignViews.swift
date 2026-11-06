import SwiftUI

struct CampaignPresenter: ViewModifier {
    var enabled: Bool
    @ObservedObject private var store = CampaignStore.shared
    @EnvironmentObject var theme: Theme
    func body(content: Content) -> some View {
        content.sheet(item: Binding(get: { enabled ? store.presentation : nil }, set: { store.presentation = $0 })) { item in
            CampaignSheet(item: item).environmentObject(theme)
                .interactiveDismissDisabled(true)
                .onAppear { store.didDisplay(item) }
        }
    }
}

struct CampaignSheet: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.openURL) var openURL
    @ObservedObject private var store = CampaignStore.shared
    let item: CampaignPresentation
    private var content: CampaignContent { switch item { case .announcement(let a): a.content; case .advertisement(let a): a.content } }
    private var style: CampaignStyle { switch item { case .announcement(let a): a.style; case .advertisement(let a): a.style } }
    private var template: String { if case .advertisement(let a) = item { return a.template }; return "minimal" }
    private var image: String? {
        template == "centered_logo" ? (content.logo_url ?? style.logo_url) : (content.image_url ?? style.background_image_url ?? style.illustration_url)
    }
    private var canClose: Bool { if case .announcement(let a) = item { return a.canClose }; return true }
    private var requiresAck: Bool { if case .announcement(let a) = item { return a.requires_ack }; return false }
    private var primaryURL: String? {
        if case .advertisement(let a) = item { return a.cta_url }
        return content.action_url ?? style.button_destination
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    if case .advertisement(let a) = item {
                        Text("\(CampaignCopy.sponsored) · \(a.sponsor_name)").font(F.xs).foregroundStyle(theme.p.s600)
                    } else { Image(systemName: style.icon ?? "bell").foregroundStyle(theme.p.s600) }
                    Spacer()
                    if canClose {
                        Button { store.dismiss() } label: { Image(systemName: "xmark").font(F.sm).frame(width: 44, height: 44) }
                            .buttonStyle(FlatPress()).foregroundStyle(theme.p.s700).accessibilityLabel(CampaignCopy.close)
                    }
                }
                if template != "minimal" { media }
                Text(content.title ?? "SetGoals").font(F.xl2).foregroundStyle(theme.foreground)
                Text(content.body).font(F.sm).foregroundStyle(theme.p.s700)
                if CampaignRules.safeURL(primaryURL) != nil {
                    PrimaryButton(title: content.button) { navigate(primaryURL, event: "cta_click") }
                }
                if case .advertisement(let a) = item, CampaignRules.safeURL(a.secondary_url) != nil {
                    SecondaryButton(title: content.secondary_label ?? CampaignCopy.open) { navigate(a.secondary_url, event: "secondary_click") }
                }
                if requiresAck { PrimaryButton(title: CampaignCopy.acknowledge) { store.dismiss(acknowledged: true) } }
                else if !canClose { PrimaryButton(title: CampaignCopy.acknowledge) { store.dismiss(acknowledged: true) } }
            }.padding(24)
        }
        .background(theme.background)
        .presentationDetents(template == "fullscreen_image" ? [.large] : [.medium, .large])
        .presentationCornerRadius(R.xl3)
    }
    @ViewBuilder private var media: some View {
        if template == "gradient_illustration" {
            ZStack {
                LinearGradient(colors: [theme.p.s100, theme.p.s300], startPoint: .topLeading, endPoint: .bottomTrailing)
                if let url = CampaignRules.safeURL(image) {
                    AsyncImage(url: url) { i in i.resizable().scaledToFit() } placeholder: { ProgressView().tint(theme.p.s600) }
                        .padding(20)
                } else { Image(systemName: "sparkles").font(.system(size: 54)).foregroundStyle(theme.p.s600) }
            }.frame(height: 220).clipShape(RoundedRectangle(cornerRadius: R.xl2))
        } else if let url = CampaignRules.safeURL(image) {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFit() }
                else if phase.error != nil { Image(systemName: "photo").foregroundStyle(theme.p.s600) }
                else { ProgressView().tint(theme.p.s600) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: template == "fullscreen_image" ? 360 : (template == "centered_logo" ? 120 : 220))
            .clipShape(RoundedRectangle(cornerRadius: R.xl2))
        }
    }
    private func navigate(_ raw: String?, event: String) {
        guard let url = CampaignRules.safeURL(raw) else { return }
        store.record(item, event); openURL(url)
    }
}

struct SponsoredChallengesSection: View {
    @EnvironmentObject var theme: Theme
    @ObservedObject private var store = CampaignStore.shared
    var body: some View {
        if !store.challenges.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(CampaignCopy.challenges).eyebrow(theme.p.s600)
                ForEach(store.challenges) { c in
                    CardSurface(radius: R.xl2, padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                if let url = CampaignRules.safeURL(c.sponsor_logo_url) {
                                    AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { Image(systemName: "flag") }
                                        .frame(width: 32, height: 32)
                                }
                                if c.sponsored_label {
                                    Text([CampaignCopy.sponsored, c.sponsor_name].compactMap { $0 }.joined(separator: " · "))
                                        .font(F.xs).foregroundStyle(theme.p.s600)
                                }
                                Spacer()
                                Text("+\(c.reward_minutes) min").font(F.xs).foregroundStyle(theme.p.s600)
                            }
                            Text(c.content.title ?? "SetGoals").font(F.sans(16, .semibold)).foregroundStyle(theme.foreground)
                            Text(c.content.body).font(F.sm).foregroundStyle(theme.p.s700)
                            ProgressView(value: c.fraction).tint(theme.p.s600)
                            Text("\(metricValue(c.progress ?? 0, c.metric)) / \(metricValue(Double(c.target), c.metric))")
                                .font(F.xs).foregroundStyle(theme.p.s600)
                            if c.reward_claimed {
                                Label(CampaignCopy.claimed, systemImage: "checkmark.circle.fill").font(F.sm).foregroundStyle(theme.p.s600)
                            } else if !c.joined {
                                PrimaryButton(title: CampaignCopy.join, busy: store.busy, enabled: c.canJoin) { Task { await store.join(c) } }
                            } else if c.fraction >= 1, c.phase == "active" {
                                PrimaryButton(title: CampaignCopy.claim, busy: store.busy) { Task { await store.claim(c) } }
                            }
                        }
                    }
                }
                if let error = store.error { Text(error).font(F.sm).foregroundStyle(theme.p.s700) }
            }
            .alert(CampaignCopy.claimed, isPresented: Binding(get: { store.rewardMinutes != nil }, set: { if !$0 { store.rewardMinutes = nil } })) {
                Button(CampaignCopy.acknowledge) { store.rewardMinutes = nil }
            } message: { Text("+\(store.rewardMinutes ?? 0) min") }
        }
    }

    private func metricValue(_ value: Double, _ metric: String) -> String {
        switch metric {
        case "distance_km": return String(format: "%.1f km", value)
        case "exercise_minutes": return "\(Int(value)) min"
        case "active_days": return "\(Int(value)) \(L.t("challenges.unit.days"))"
        default: return "\(Int(value).formatted()) \(L.t("challenges.unit.steps"))"
        }
    }
}
