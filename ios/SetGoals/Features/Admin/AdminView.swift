import SwiftUI
import Charts
import Supabase

// MARK: - Models (mirror admin_* database functions; admin-only, enforced server-side)

struct AdminUserRow: Codable, Identifiable, Hashable {
    let user_id: UUID
    let email: String?
    let username: String
    let display_name: String
    let created_at: String
    let last_active_at: String?
    let total_steps: Int
    let avg_daily_steps: Double?
    let step_goal: Int?
    let avg_earned_seconds: Double?
    let avg_used_seconds: Double?
    let last_activity_date: String?
    let days_recorded: Int
    let total_count: Int
    var id: UUID { user_id }
}

struct DailyStatRow: Codable, Identifiable {
    let stat_date: String
    let steps: Int
    let step_goal: Int?
    let screen_time_earned_seconds: Int
    let screen_time_bonus_seconds: Int
    let screen_time_used_seconds: Int?
    let screen_time_remaining_seconds: Int?
    var id: String { stat_date }
    var date: Date { AdminAPI.parse(stat_date) }
}

struct OverviewDay: Codable, Identifiable {
    let day: String
    let active_users: Int
    let new_users: Int
    let avg_steps: Double?
    let goal_rate: Double?
    let avg_earned_seconds: Double?
    let avg_used_seconds: Double?
    var id: String { day }
    var date: Date { AdminAPI.parse(day) }
}

struct OverviewTotals: Codable {
    let total_users: Int
    let active_1d: Int
    let active_7d: Int
    let active_30d: Int
}

enum AdminAPI {
    static func parse(_ s: String) -> Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.date(from: String(s.prefix(10))) ?? Date()
    }
    static func key(daysAgo: Int) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.string(from: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date())
    }
    static func isAdmin() async -> Bool {
        (try? await supabase.rpc("is_admin").execute().value as Bool) ?? false
    }
    static func users(search: String, sort: String, desc: Bool, page: Int, size: Int = 25) async throws -> [AdminUserRow] {
        try await supabase.rpc("admin_users", params: [
            "_search": AnyJSON.string(search), "_sort": .string(sort), "_desc": .bool(desc),
            "_limit": .integer(size), "_offset": .integer(page * size),
        ]).execute().value
    }
    static func history(_ uid: UUID, days: Int?) async throws -> [DailyStatRow] {
        var p: [String: AnyJSON] = ["_uid": .string(uid.uuidString)]
        if let days { p["_from"] = .string(key(daysAgo: days - 1)) }
        return try await supabase.rpc("admin_user_history", params: p).execute().value
    }
    static func overview(days: Int) async throws -> [OverviewDay] {
        try await supabase.rpc("admin_overview_daily", params: ["_from": AnyJSON.string(key(daysAgo: days - 1))])
            .execute().value
    }
    static func totals() async throws -> OverviewTotals? {
        let r: [OverviewTotals] = try await supabase.rpc("admin_overview_totals").execute().value
        return r.first
    }
}

private func mins(_ s: Double?) -> String {
    guard let s else { return "–" }
    let m = Int(s / 60); return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
}
private func num(_ v: Double?) -> String { v.map { Int($0).formatted() } ?? "–" }

// MARK: - Root

struct AdminView: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    @State private var section = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $section) {
                    Text("Overview").tag(0); Text("Users").tag(1)
                }
                .pickerStyle(.segmented).padding()
                if section == 0 { AdminOverview() } else { AdminUsersList() }
            }
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .tint(theme.p.s600)
    }
}

// MARK: - Overview

private struct AdminOverview: View {
    @State private var range = 30
    @State private var totals: OverviewTotals?
    @State private var days: [OverviewDay] = []
    @State private var error: String?

    var body: some View {
        List {
            Section {
                Picker("Range", selection: $range) {
                    Text("7d").tag(7); Text("30d").tag(30); Text("90d").tag(90)
                }.pickerStyle(.segmented)
            }
            if let error { Text(error).foregroundStyle(.red) }
            if let t = totals {
                Section("Users") {
                    stat("Registered users", "\(t.total_users)")
                    stat("Active today", "\(t.active_1d)")
                    stat("Active last 7 days", "\(t.active_7d)")
                    stat("Active last 30 days", "\(t.active_30d)")
                }
            }
            let active = days.filter { $0.active_users > 0 }
            Section {
                stat("Avg steps / active user / day", num(avg(active.compactMap(\.avg_steps))))
                stat("Goal completion rate", avg(active.compactMap(\.goal_rate)).map { String(format: "%.0f%%", $0) } ?? "–")
                stat("Avg screen time earned / day", mins(avg(active.compactMap(\.avg_earned_seconds))))
                stat("Avg earned time used in app / day", mins(avg(days.compactMap(\.avg_used_seconds))))
            } header: { Text("Averages (\(range)d)") } footer: {
                Text("Averages count only users with recorded steps that day. \"Used\" is earned time spent through SetGoals, not total device screen time — Apple doesn't share that.")
            }
            Section("Active users per day") {
                Chart(days) { BarMark(x: .value("Day", $0.date, unit: .day), y: .value("Users", $0.active_users)) }
                    .frame(height: 160)
            }
            Section("Avg steps per active user") {
                Chart(days.filter { $0.avg_steps != nil }) {
                    LineMark(x: .value("Day", $0.date, unit: .day), y: .value("Steps", $0.avg_steps ?? 0))
                    PointMark(x: .value("Day", $0.date, unit: .day), y: .value("Steps", $0.avg_steps ?? 0))
                }.frame(height: 160)
            }
            Section("Screen time per active user (min)") {
                Chart {
                    ForEach(days.filter { $0.avg_earned_seconds != nil }) {
                        LineMark(x: .value("Day", $0.date, unit: .day), y: .value("Min", ($0.avg_earned_seconds ?? 0) / 60))
                            .foregroundStyle(by: .value("Kind", "Earned"))
                    }
                    ForEach(days.filter { $0.avg_used_seconds != nil }) {
                        LineMark(x: .value("Day", $0.date, unit: .day), y: .value("Min", ($0.avg_used_seconds ?? 0) / 60))
                            .foregroundStyle(by: .value("Kind", "Used"))
                    }
                }.frame(height: 160)
            }
            Section("New registrations") {
                Chart(days) { BarMark(x: .value("Day", $0.date, unit: .day), y: .value("New", $0.new_users)) }
                    .frame(height: 140)
            }
        }
        .task(id: range) { await load() }
        .refreshable { await load() }
    }

    private func avg(_ v: [Double]) -> Double? { v.isEmpty ? nil : v.reduce(0, +) / Double(v.count) }
    private func stat(_ l: String, _ v: String) -> some View {
        HStack { Text(l); Spacer(); Text(v).bold().monospacedDigit() }
    }
    private func load() async {
        do {
            async let t = AdminAPI.totals(); async let d = AdminAPI.overview(days: range)
            totals = try await t; days = try await d; error = nil
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: - Users list

private struct AdminUsersList: View {
    @State private var search = ""
    @State private var sort = "created_at"
    @State private var desc = true
    @State private var page = 0
    @State private var rows: [AdminUserRow] = []
    @State private var error: String?

    private var total: Int { rows.first?.total_count ?? 0 }

    var body: some View {
        List {
            Section {
                Picker("Sort", selection: $sort) {
                    Text("Registered").tag("created_at"); Text("Last active").tag("last_active")
                    Text("Total steps").tag("total_steps"); Text("Avg steps").tag("avg_steps")
                    Text("Avg earned").tag("avg_earned")
                }
                Toggle("Descending", isOn: $desc)
            }
            if let error { Text(error).foregroundStyle(.red) }
            Section("\(total) users") {
                ForEach(rows) { u in
                    NavigationLink(value: u) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("@\(u.username) · \(u.display_name)").bold()
                            Text(u.email ?? "–").font(.caption).foregroundStyle(.secondary)
                            Text("\(u.total_steps.formatted()) steps · avg \(num(u.avg_daily_steps))/day · earned \(mins(u.avg_earned_seconds))/day")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if total > 25 {
                HStack {
                    Button("Previous") { page -= 1 }.disabled(page == 0)
                    Spacer(); Text("Page \(page + 1) / \((total + 24) / 25)").font(.caption); Spacer()
                    Button("Next") { page += 1 }.disabled((page + 1) * 25 >= total)
                }.buttonStyle(.borderless)
            }
        }
        .searchable(text: $search, prompt: "Email, username, name or UID")
        .navigationDestination(for: AdminUserRow.self) { AdminUserDetail(user: $0) }
        .task(id: "\(search)|\(sort)|\(desc)|\(page)") {
            try? await Task.sleep(nanoseconds: 300_000_000)
            do { rows = try await AdminAPI.users(search: search, sort: sort, desc: desc, page: page); error = nil }
            catch is CancellationError {} catch { self.error = error.localizedDescription }
        }
        .onChange(of: search) { _ in page = 0 }
        .onChange(of: sort) { _ in page = 0 }
    }
}

// MARK: - User detail

private struct AdminUserDetail: View {
    let user: AdminUserRow
    @State private var range: Int? = 30
    @State private var rows: [DailyStatRow] = []
    @State private var baselineDays = 7

    var body: some View {
        List {
            Section("Profile") {
                kv("Email", user.email ?? "–"); kv("Username", "@\(user.username)")
                kv("Display name", user.display_name)
                kv("UID", user.user_id.uuidString).font(.caption)
                kv("Registered", String(user.created_at.prefix(10)))
                kv("Last active", user.last_active_at.map { String($0.prefix(10)) } ?? "–")
                kv("Last activity day", user.last_activity_date ?? "–")
                kv("Current step goal", user.step_goal.map { $0.formatted() } ?? "–")
            }
            Section("All-time") {
                kv("Total steps", user.total_steps.formatted())
                kv("Avg daily steps", num(user.avg_daily_steps))
                kv("Avg earned / day", mins(user.avg_earned_seconds))
                kv("Avg used in app / day", mins(user.avg_used_seconds))
                kv("Days with records", "\(user.days_recorded)")
            }
            Section {
                Picker("Range", selection: $range) {
                    Text("7d").tag(Int?.some(7)); Text("30d").tag(Int?.some(30))
                    Text("90d").tag(Int?.some(90)); Text("All").tag(Int?.none)
                }.pickerStyle(.segmented)
            } footer: { Text("Days with no record are left blank, not shown as zero.") }

            Section("A · Daily steps vs goal") {
                Chart {
                    ForEach(rows) { r in
                        BarMark(x: .value("Day", r.date, unit: .day), y: .value("Steps", r.steps))
                            .foregroundStyle((r.step_goal.map { r.steps >= $0 } ?? false) ? Color.green : Color.gray)
                            .annotation(position: .top) { if rows.count <= 14 { Text("\(r.steps)").font(.system(size: 7)) } }
                    }
                    ForEach(rows.filter { $0.step_goal != nil }) { r in
                        LineMark(x: .value("Day", r.date, unit: .day), y: .value("Goal", r.step_goal ?? 0))
                            .foregroundStyle(.orange).lineStyle(StrokeStyle(dash: [4, 3]))
                    }
                }.frame(height: 180)
                Text("Green = goal reached · dashed = goal").font(.caption2).foregroundStyle(.secondary)
            }
            Section("B · Screen-time balance (min)") {
                Chart {
                    ForEach(rows) { r in
                        BarMark(x: .value("Day", r.date, unit: .day), y: .value("Min", r.screen_time_earned_seconds / 60))
                            .foregroundStyle(by: .value("Kind", "Earned")).position(by: .value("Kind", "Earned"))
                        if let u = r.screen_time_used_seconds {
                            BarMark(x: .value("Day", r.date, unit: .day), y: .value("Min", u / 60))
                                .foregroundStyle(by: .value("Kind", "Used")).position(by: .value("Kind", "Used"))
                        }
                        if let rem = r.screen_time_remaining_seconds {
                            BarMark(x: .value("Day", r.date, unit: .day), y: .value("Min", rem / 60))
                                .foregroundStyle(by: .value("Kind", "Remaining")).position(by: .value("Kind", "Remaining"))
                        }
                    }
                }.frame(height: 180)
            }
            Section("C · Steps & earned time") {
                ForEach(rows.reversed()) { r in
                    HStack {
                        Text(r.stat_date).font(.caption.monospaced())
                        Spacer()
                        Text("\(r.steps.formatted()) st").font(.caption)
                        Text("· +\(r.screen_time_earned_seconds / 60)m").font(.caption).foregroundStyle(.secondary)
                        Text("· used \(r.screen_time_used_seconds.map { "\($0 / 60)m" } ?? "–")").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Stepper("Baseline: first \(baselineDays) recorded days", value: $baselineDays, in: 3...30)
                let all = rows
                let base = Array(all.prefix(baselineDays)), later = Array(all.suffix(baselineDays))
                if all.count >= baselineDays * 2 {
                    let b = Double(base.map(\.steps).reduce(0, +)) / Double(base.count)
                    let l = Double(later.map(\.steps).reduce(0, +)) / Double(later.count)
                    Chart {
                        BarMark(x: .value("Period", "Baseline"), y: .value("Avg steps", b))
                        BarMark(x: .value("Period", "Latest"), y: .value("Avg steps", l))
                    }.frame(height: 140)
                    kv("Change", b > 0 ? String(format: "%+.0f%%", (l - b) / b * 100) : "–")
                } else {
                    Text("Not enough recorded days in this range to compare.").font(.caption).foregroundStyle(.secondary)
                }
            } header: { Text("D · Progress over time") } footer: {
                Text("Compares average steps between the first and most recent recorded days. Shows change, not cause. Device screen time isn't available from Apple, so no usage comparison is made.")
            }
        }
        .navigationTitle("@\(user.username)")
        .task(id: range) { rows = (try? await AdminAPI.history(user.user_id, days: range)) ?? [] }
    }

    private func kv(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(.secondary); Spacer(); Text(v).multilineTextAlignment(.trailing) }
    }
}
