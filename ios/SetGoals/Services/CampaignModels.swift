import Foundation

/// Dashboard content supports both the original and the current editor field names.
struct CampaignContent: Codable {
    var title: String?
    var message: String?
    var description: String?
    var subtitle: String?
    var cta_label: String?
    var button_text: String?
    var action_url: String?
    var image_url: String?
    var logo_url: String?
    var secondary_label: String?
    var body: String { message ?? description ?? subtitle ?? "" }
    var button: String { cta_label ?? button_text ?? CampaignCopy.open }
}
struct CampaignStyle: Codable {
    var icon: String?
    var background_image_url: String?
    var illustration_url: String?
    var logo_url: String?
    var button_destination: String?
    var cover_image_url: String?
}
struct AppAnnouncement: Codable, Identifiable {
    let id: UUID
    let kind: String
    let display_mode: String
    let requires_ack: Bool
    let dismissible: Bool
    let content: CampaignContent
    let style: CampaignStyle
    var canClose: Bool { dismissible && !requires_ack }
}
struct AppAdvertisement: Codable, Identifiable {
    let id: UUID
    let sponsor_name: String
    let template: String
    let content: CampaignContent
    let style: CampaignStyle
    let cta_url: String?
    let secondary_url: String?
    let max_per_day: Int
    let min_minutes_between: Int
    let max_total_per_user: Int?
    let once_per_campaign: Bool
}
struct SponsoredChallenge: Codable, Identifiable {
    let id: UUID
    let content: CampaignContent
    let sponsor_name: String?
    let sponsor_logo_url: String?
    let sponsored_label: Bool
    let metric: String
    let target: Int
    let reward_minutes: Int
    let join_mode: String
    let phase: String
    let joined: Bool
    let progress: Double?
    let reward_claimed: Bool
    let join_opens_at: String?
    let join_closes_at: String?
    let starts_at: String?
    let ends_at: String?
    var fraction: Double { min(1, max(0, (progress ?? 0) / Double(max(1, target)))) }
    var canJoin: Bool {
        guard !joined, phase != "ended" else { return false }
        let now = Date()
        return (CampaignRules.date(join_opens_at).map { now >= $0 } ?? true)
            && (CampaignRules.date(join_closes_at).map { now < $0 } ?? true)
    }
}
struct SponsoredReward: Codable { let granted: Bool; let minutes: Int?; let reason: String? }
enum CampaignPresentation: Identifiable {
    case announcement(AppAnnouncement), advertisement(AppAdvertisement)
    var id: UUID { switch self { case .announcement(let a): a.id; case .advertisement(let a): a.id } }
    var type: String { switch self { case .announcement: "announcement"; case .advertisement: "advertisement" } }
}
enum CampaignCopy {
    static var open: String { L.lang == "sv" ? "Öppna" : "Open" }
    static var acknowledge: String { L.lang == "sv" ? "Jag förstår" : "Got it" }
    static var close: String { L.lang == "sv" ? "Stäng" : "Close" }
    static var sponsored: String { L.lang == "sv" ? "Sponsrad" : "Sponsored" }
    static var challenges: String { L.lang == "sv" ? "Sponsrade utmaningar" : "Sponsored challenges" }
    static var join: String { L.lang == "sv" ? "Gå med" : "Join" }
    static var claim: String { L.lang == "sv" ? "Hämta belöning" : "Claim reward" }
    static var claimed: String { L.lang == "sv" ? "Belöning hämtad" : "Reward claimed" }
    static var error: String { L.lang == "sv" ? "Kunde inte uppdatera. Försök igen." : "Could not update. Please try again." }
    static var nativePending: String { L.lang == "sv" ? "Belöningen är sparad. Aktivera Skärmtid för att använda den." : "Your reward is saved. Enable Screen Time to use it." }
}
