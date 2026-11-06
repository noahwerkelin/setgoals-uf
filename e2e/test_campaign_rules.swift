import Foundation

@main struct CampaignRulesTests {
    static func main() {
        let now = CampaignRules.date("2026-11-06T12:00:00Z") ?? Date()
        assert(!CampaignRules.adult(role: "child", birthday: "2000-01-01", now: now))
        assert(!CampaignRules.adult(role: "individual", birthday: "2009-01-01", now: now))
        assert(!CampaignRules.adult(role: "individual", birthday: nil, now: now))
        assert(CampaignRules.adult(role: "individual", birthday: "2008-11-06", now: now))
        assert(!CampaignRules.announcementEligible(mode: "once_per_user", requiresAck: false, displayed: true, dismissed: false, acknowledged: false, sessionSeen: false))
        assert(CampaignRules.announcementEligible(mode: "once_per_user", requiresAck: true, displayed: true, dismissed: false, acknowledged: false, sessionSeen: true))
        assert(!CampaignRules.announcementEligible(mode: "until_dismissed", requiresAck: false, displayed: false, dismissed: true, acknowledged: false, sessionSeen: false))
        assert(!CampaignRules.announcementEligible(mode: "once_per_session", requiresAck: false, displayed: false, dismissed: false, acknowledged: false, sessionSeen: true))
        assert(!CampaignRules.adEligible(today: 1, total: 1, last: nil, maxDaily: 1, maxTotal: nil, once: false, gap: 30, now: now))
        assert(!CampaignRules.adEligible(today: 0, total: 1, last: nil, maxDaily: 5, maxTotal: nil, once: true, gap: 30, now: now))
        assert(!CampaignRules.adEligible(today: 0, total: 2, last: nil, maxDaily: 5, maxTotal: 2, once: false, gap: 30, now: now))
        assert(!CampaignRules.adEligible(today: 0, total: 0, last: now.addingTimeInterval(-1799), maxDaily: 5, maxTotal: nil, once: false, gap: 30, now: now))
        assert(CampaignRules.adEligible(today: 0, total: 0, last: now.addingTimeInterval(-1800), maxDaily: 5, maxTotal: nil, once: false, gap: 30, now: now))
        assert(CampaignRules.safeURL("javascript:alert(1)") == nil)
        assert(CampaignRules.safeURL("https://setgoals.se") != nil)
        print("14 campaign rule assertions passed")
    }
}
