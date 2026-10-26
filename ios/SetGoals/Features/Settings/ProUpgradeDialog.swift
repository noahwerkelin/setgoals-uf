import SwiftUI

/// Port of `ProUpgradeDialog` in `src/components/Pro.tsx` — three variants:
/// child (inherits PRO Family), manage (already PRO), upgrade (buy).
struct ProUpgradeDialog: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        if settings.role == "child" {
            ChildProDialog()
        } else if settings.isPro {
            ManageSubscriptionDialog()
        } else {
            UpgradeDialog()
        }
    }
}

private struct SparklesBadge: View {
    @EnvironmentObject var theme: Theme
    var filled: Bool
    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(filled ? theme.primaryForeground : theme.p.s700)
            .frame(width: 48, height: 48)
            .background(filled ? theme.primary : theme.p.s100,
                        in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
            .frame(maxWidth: .infinity)
    }
}

struct ChildProDialog: View {
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let ends = settings.parentFamilyEndsAt.map { Formatters.date($0) }
        let desc: String = settings.parentFamilyCancelling && ends != nil
            ? L.t("pro.child_ending", ["date": ends!])
            : (settings.parentFamilyActive ? L.t("pro.child_active") : L.t("pro.child_desc"))

        AppDialog(title: settings.parentFamilyActive ? L.t("pro.child_active_title") : L.t("pro.child_title"),
                  description: desc, centered: true) {
            SparklesBadge(filled: false)
        } footer: {
            GhostButton(title: L.t("common.close")) { dismiss() }
                .frame(maxWidth: .infinity)
        }
        .presentationDetents([.height(280)])
    }
}

struct UpgradeDialog: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var plan: StoreKitService.Plan = .monthly
    @State private var busy: String?
    @State private var note: String?

    private var features: [String] {
        var f = ["pro.feature.earning", "pro.feature.bonus", "pro.feature.parental",
                 "pro.feature.stats", "pro.feature.theme", "pro.feature.premium_badge"]
        if plan.isFamily { f.append("pro.feature.family") }
        return f
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "crown")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(theme.primaryForeground)
                        .frame(width: 64, height: 64)
                        .background(theme.primary, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                    Text(L.t("pro.title")).font(F.sans(28, .semibold)).foregroundStyle(theme.foreground)
                    Text(L.t("pro.upgrade_subtitle")).font(F.sm).foregroundStyle(theme.mutedForeground)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.top, 12)
                Divider().overlay(theme.border)
                VStack(alignment: .leading, spacing: 14) {
                    Text(L.t("pro.included")).font(F.xs).foregroundStyle(theme.mutedForeground)
                    ForEach(features, id: \.self) { k in
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: featureIcon(k))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(theme.primary)
                                .frame(width: 34, height: 34)
                                .background(theme.muted, in: RoundedRectangle(cornerRadius: R.sm, style: .continuous))
                            Text(L.t(k)).font(F.sm).foregroundStyle(theme.foreground).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Divider().overlay(theme.border)
                VStack(alignment: .leading, spacing: 12) {
                    Text(L.t("pro.choose_plan")).font(F.xs).foregroundStyle(theme.mutedForeground)
                    planGrid
                }
                Text(L.t("pro.store.billed_by_apple"))
                    .font(F.text11).foregroundStyle(theme.p.s600)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                if let note {
                    Text(note).font(F.xs).foregroundStyle(theme.p.s700)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(12)
                        .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                            .strokeBorder(theme.p.s200, lineWidth: 1))
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                PrimaryButton(title: busy == "buy" ? L.t("pro.store.opening") : L.t("pro.store.buy_with_apple"),
                              busy: busy != nil) {
                    Task { await run("buy") }
                }
                GhostButton(title: busy == "restore" ? L.t("pro.store.restoring") : L.t("pro.store.restore")) {
                    Task { await run("restore") }
                }
                .disabled(busy != nil)
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            .background(theme.card)
        }
        .background(theme.card)
        .presentationBackground(theme.card)
        .presentationCornerRadius(R.xl3)
        .presentationDetents([.large])
    }

    private func featureIcon(_ key: String) -> String {
        switch key {
        case "pro.feature.earning": return "slider.horizontal.3"
        case "pro.feature.bonus": return "arrow.trianglehead.clockwise"
        case "pro.feature.parental": return "checkmark.shield"
        case "pro.feature.stats": return "chart.bar.xaxis"
        case "pro.feature.theme": return "paintpalette"
        case "pro.feature.family": return "person.2"
        default: return "crown"
        }
    }

    private var planGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(StoreKitService.Plan.allCases) { p in
                let active = plan == p
                Button { plan = p } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 4) {
                            Text(L.t("pro.plan.\(p.rawValue)")).font(F.xs)
                                .foregroundStyle(theme.mutedForeground)
                            Spacer(minLength: 0)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(theme.primary).opacity(active ? 1 : 0)
                        }
                        Text(L.t("pro.price.\(p.rawValue)")).font(F.sans(15, .semibold))
                            .foregroundStyle(theme.foreground).fixedSize(horizontal: false, vertical: true)
                        if p.rawValue.hasSuffix("yearly") {
                            Text(L.t("pro.save_badge")).font(F.text11).foregroundStyle(theme.primary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                    .background(active ? theme.secondary : theme.card,
                                in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                        .strokeBorder(active ? theme.primary : theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(busy != nil)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
    }

    private func run(_ kind: String) async {
        busy = kind
        note = nil
        let res = kind == "buy" ? await StoreKitService.purchase(plan) : await StoreKitService.restore()
        switch res {
        case .purchased:
            await settings.load()
            if settings.isPro { dismiss() } else { note = L.t("pro.store.pending") }
        case .pending: note = L.t("pro.store.pending")
        case .nothingToRestore: note = L.t("pro.store.nothing_to_restore")
        case .cancelled: break
        case .failed: note = L.t(kind == "buy" ? "pro.store.failed" : "pro.store.restore_failed")
        }
        busy = nil
    }
}

struct ManageSubscriptionDialog: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false

    var body: some View {
        AppDialog(title: L.t("pro.manage.title"), description: L.t("pro.store.manage_note"), centered: true) {
            VStack(spacing: 12) {
                SparklesBadge(filled: true)
                CardSurface(radius: R.xl2, padding: 16) {
                    VStack(spacing: 10) {
                        row(L.t("pro.plan"), L.t("pro.plan.\(settings.proPlan)"))
                        row(L.t("pro.price"), L.t("pro.price.\(settings.proPlan)"))
                        if let since = settings.proSince {
                            row(L.t("pro.member_since"), Formatters.date(since))
                        }
                        if let ends = settings.proExpiresAt {
                            row(L.t("pro.next_billing"), Formatters.date(ends))
                        }
                    }
                }
            }
        } footer: {
            VStack(spacing: 8) {
                PrimaryButton(title: L.t("pro.store.manage_in_appstore"), busy: busy) {
                    Task { await StoreKitService.openManageSubscriptions() }
                }
                GhostButton(title: L.t("pro.store.restore")) {
                    busy = true
                    Task {
                        _ = await StoreKitService.restore()
                        await settings.load()
                        busy = false
                    }
                }
                GhostButton(title: L.t("common.close")) { dismiss() }
            }
        }
        .presentationDetents([.height(520)])
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(F.xs).foregroundStyle(theme.p.s600)
            Spacer()
            Text(value).font(F.sans(13, .semibold)).foregroundStyle(theme.p.s900)
        }
    }
}

enum Formatters {
    /// `toLocaleDateString(lang, { year, month: "short", day })`
    static func date(_ iso: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = parser.date(from: iso)
            ?? ISO8601DateFormatter().date(from: iso)
            ?? Date()
        let f = DateFormatter()
        f.locale = Locale(identifier: L.lang == "sv" ? "sv_SE" : "en_US")
        f.setLocalizedDateFormatFromTemplate("d MMM y")
        return f.string(from: d)
    }
}
