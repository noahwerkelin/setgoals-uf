import Foundation

/// Pure rules shared by the store and executable regression tests.
enum CampaignRules {
    static func date(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }
    static func adult(role: String, birthday: String?, now: Date = Date()) -> Bool {
        guard role != "child", let birthday else { return false }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let birth = f.date(from: birthday), birth <= now,
              let cutoff = Calendar.current.date(byAdding: .year, value: -18, to: now) else { return false }
        return birth <= cutoff
    }
    static func announcementEligible(mode: String, requiresAck: Bool, displayed: Bool,
                                     dismissed: Bool, acknowledged: Bool, sessionSeen: Bool) -> Bool {
        if acknowledged { return false }
        if requiresAck { return true }
        switch mode {
        case "once_per_user": return !displayed && !dismissed
        case "once_per_session": return !sessionSeen
        case "until_dismissed": return !dismissed
        default: return !sessionSeen // every_launch: once on each foreground
        }
    }
    static func adEligible(today: Int, total: Int, last: Date?, maxDaily: Int,
                           maxTotal: Int?, once: Bool, gap: Int, now: Date = Date()) -> Bool {
        today < maxDaily && (maxTotal.map { total < $0 } ?? true) && (!once || total == 0)
            && (last.map { now.timeIntervalSince($0) >= Double(gap * 60) } ?? true)
    }
    static func safeURL(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme?.lowercased() == "https", url.host != nil else { return nil }
        return url
    }
}
