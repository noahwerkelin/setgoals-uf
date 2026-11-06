import Foundation
import SwiftUI
import Supabase

/// One account-scoped snapshot. Fetches never hold up the splash or navigation.
@MainActor
final class CampaignStore: ObservableObject {
    static let shared = CampaignStore()
    @Published var presentation: CampaignPresentation?
    @Published private(set) var challenges: [SponsoredChallenge] = []
    @Published private(set) var busy = false
    @Published var error: String?
    @Published var rewardMinutes: Int?
    private var account: UUID?
    private var generation = UUID()
    private var sessionSeen: Set<UUID> = []
    private var foregroundSeen: Set<UUID> = []
    private var fetching = false
    private var lastOpen: Date?
    private var visibleRecorded: UUID?
    private var pendingEvents: [Event] = []
    private let defaults = UserDefaults.standard
    private struct Event: Codable { let type: String; let id: UUID; let event: String }
    static var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0" }
    private func key(_ suffix: String) -> String { "campaigns.\(account?.uuidString ?? "signed-out").\(suffix)" }
    private func flag(_ id: UUID, _ event: String) -> Bool { defaults.bool(forKey: key("\(id).\(event)")) }
    private func setFlag(_ id: UUID, _ event: String) { defaults.set(true, forKey: key("\(id).\(event)")) }

    func clear() {
        account = nil; generation = UUID(); challenges = []; presentation = nil
        sessionSeen = []; foregroundSeen = []; pendingEvents = []; fetching = false
        error = nil; rewardMinutes = nil; visibleRecorded = nil; lastOpen = nil
    }
    func foreground() async {
        guard let session = try? await supabase.auth.session else { clear(); return }
        if account != session.user.id {
            clear(); account = session.user.id
            if let data = defaults.data(forKey: key("pending")) {
                pendingEvents = (try? JSONDecoder().decode([Event].self, from: data)) ?? []
            }
        }
        // Bootstrap, sign-in observation and scene activation can coincide.
        if let lastOpen, Date().timeIntervalSince(lastOpen) < 2 { return }
        lastOpen = Date()
        foregroundSeen = []
        // This caller-scoped RPC deliberately takes no user id.
        let gen = generation
        try? await supabase.rpc("record_app_open", params: ["_app_version": Self.version, "_platform": "ios"]).execute()
        guard generation == gen else { return }
        await refresh()
    }
    func refresh() async {
        guard account != nil, !fetching else { return }
        fetching = true
        let gen = generation
        defer { if gen == generation { fetching = false } }
        await flushEvents()
        do {
            async let announcements: [AppAnnouncement] = supabase.rpc("get_active_announcements", params: ["_lang": L.lang, "_app_version": Self.version]).execute().value
            async let sponsored: [SponsoredChallenge] = supabase.rpc("get_sponsored_challenges", params: ["_lang": L.lang]).execute().value
            let (messages, rows) = try await (announcements, sponsored)
            guard gen == generation else { return }
            challenges = rows.filter { $0.phase != "ended" }
            guard presentation == nil else { return }
            if let a = messages.first(where: {
                CampaignRules.announcementEligible(mode: $0.display_mode, requiresAck: $0.requires_ack,
                    displayed: flag($0.id, "displayed"), dismissed: flag($0.id, "dismissed"),
                    acknowledged: flag($0.id, "acknowledged"), sessionSeen: $0.display_mode == "every_launch" ? foregroundSeen.contains($0.id) : sessionSeen.contains($0.id))
            }) { presentation = .announcement(a); return }
            // Defense in depth: failed/missing identity or birthday means no advertisement.
            guard let profile = try await SupabaseAPI.profile(),
                  CampaignRules.adult(role: profile.role, birthday: profile.birthday) else { return }
            guard gen == generation else { return }
            let ads: [AppAdvertisement] = try await supabase.rpc("get_native_advertisements", params: ["_lang": L.lang, "_app_version": Self.version]).execute().value
            guard gen == generation, presentation == nil else { return }
            if let ad = ads.first(where: { localAdEligible($0) }) { presentation = .advertisement(ad) }
        } catch { /* Keep the last snapshot; offline campaigns never block entry. */ }
    }
    private func localAdEligible(_ ad: AppAdvertisement) -> Bool {
        let prefix = "\(ad.id)"
        let today = defaults.integer(forKey: key("\(prefix).\(SupabaseAPI.todayKey).count"))
        let total = defaults.integer(forKey: key("\(prefix).total"))
        let last = defaults.object(forKey: key("\(prefix).last")) as? Date
        let global = defaults.object(forKey: key("ad.last")) as? Date
        return CampaignRules.adEligible(today: today, total: total, last: last, maxDaily: ad.max_per_day,
            maxTotal: ad.max_total_per_user, once: ad.once_per_campaign, gap: ad.min_minutes_between)
            && (global.map { Date().timeIntervalSince($0) >= 4 * 3600 } ?? true)
    }
    func didDisplay(_ item: CampaignPresentation) {
        guard presentation?.id == item.id, visibleRecorded != item.id else { return }
        visibleRecorded = item.id
        sessionSeen.insert(item.id); foregroundSeen.insert(item.id); setFlag(item.id, "displayed")
        if case .advertisement = item {
            for suffix in ["\(item.id).\(SupabaseAPI.todayKey).count", "\(item.id).total"] {
                defaults.set(defaults.integer(forKey: key(suffix)) + 1, forKey: key(suffix))
            }
            defaults.set(Date(), forKey: key("\(item.id).last")); defaults.set(Date(), forKey: key("ad.last"))
        }
        record(item, "displayed")
    }
    func dismiss(acknowledged: Bool = false) {
        guard let item = presentation else { return }
        if case .announcement(let a) = item, !a.canClose && !acknowledged { return }
        let event = acknowledged ? "acknowledged" : "dismissed"
        setFlag(item.id, event); record(item, event)
        presentation = nil; visibleRecorded = nil
    }
    func record(_ item: CampaignPresentation, _ event: String) {
        pendingEvents.append(Event(type: item.type, id: item.id, event: event)); persistEvents()
        Task { await flushEvents() }
    }
    private var flushing = false
    private func persistEvents() { defaults.set(try? JSONEncoder().encode(pendingEvents), forKey: key("pending")) }
    private func flushEvents() async {
        guard !flushing, account != nil else { return }
        flushing = true; let gen = generation
        defer { flushing = false }
        while let e = pendingEvents.first {
            do {
                try await supabase.rpc("record_campaign_event", params: ["_type": e.type, "_campaign_id": e.id.uuidString, "_event": e.event]).execute()
                guard gen == generation else { return }
                pendingEvents.removeFirst(); persistEvents()
            } catch { return }
        }
    }
    func join(_ challenge: SponsoredChallenge) async {
        guard !busy else { return }; busy = true; error = nil
        let gen = generation
        defer { busy = false }
        do {
            try await supabase.rpc("join_sponsored_challenge", params: ["_challenge_id": challenge.id.uuidString]).execute()
            guard gen == generation else { return }; await refresh()
        } catch { if gen == generation { self.error = CampaignCopy.error } }
    }
    func claim(_ challenge: SponsoredChallenge) async {
        guard !busy else { return }; busy = true; error = nil
        let gen = generation
        defer { busy = false }
        do {
            let result: SponsoredReward = try await supabase.rpc("claim_sponsored_challenge_reward", params: ["_challenge_id": challenge.id.uuidString, "_day": SupabaseAPI.todayKey]).execute().value
            guard gen == generation else { return }
            // The server has already credited bonus_min. Reconcile the base, never grant() again.
            await SettingsStore.shared.load()
            guard gen == generation else { return }
            if result.granted {
                do {
                    guard let balance = try await SupabaseAPI.todayBalance() else {
                        throw ScreenTimeError.monitoringFailed(CampaignCopy.nativePending)
                    }
                    guard gen == generation else { return }
                    let settings = SettingsStore.shared
                    settings.bonusMin = balance.bonus_min
                    ScreenTimeService.shared.setBaseAllowance(settings.earnedMin(from: HealthKitService.shared.steps)
                        + settings.rolloverMin + balance.bonus_min)
                    try ScreenTimeService.shared.synchronizeServerAllowance()
                    rewardMinutes = result.minutes ?? 0
                } catch { self.error = CampaignCopy.nativePending }
            } else if result.reason != "already_claimed" { self.error = CampaignCopy.error }
            await BadgeStore.shared.preload(); await refresh()
        } catch { if gen == generation { self.error = CampaignCopy.error } }
    }
}
