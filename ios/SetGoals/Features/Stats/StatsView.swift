import SwiftUI

/// Port of `src/routes/stats.tsx` — weekly bars, four stat cards, the
/// 8-week trend line and the PRO insights block (`src/lib/insights.ts`).
struct StatsView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @Binding var tab: AppTab

    @State private var week: [(day: String, steps: Int)] = []
    @State private var history: [(day: String, steps: Int, distance: Double)] = []

    private var maxSteps: Int { max(1, week.map(\.steps).max() ?? 1) }
    private var avg: Int { week.isEmpty ? 0 : week.reduce(0) { $0 + $1.steps } / week.count }
    private var weeklyEarned: Int { week.reduce(0) { $0 + settings.earnedMin(from: $1.steps) } }
    private var goal: Int { max(1, settings.dailyGoal) }
    private var last30: [(day: String, steps: Int, distance: Double)] { Array(history.suffix(30)) }
    private var goalPct: Int {
        last30.isEmpty ? 0 : Int(Double(last30.filter { $0.steps >= goal }.count) / Double(last30.count) * 100)
    }
    private var activeDays: Int { week.filter { $0.steps >= goal }.count }
    private var best: (day: String, steps: Int, distance: Double)? {
        last30.max(by: { $0.steps < $1.steps })
    }
    private var vsLastPct: Int? {
        let last7 = history.suffix(7).reduce(0) { $0 + $1.steps }
        let prev7 = history.dropLast(7).suffix(7).reduce(0) { $0 + $1.steps }
        guard prev7 > 0 else { return nil }
        return Int(Double(last7 - prev7) / Double(prev7) * 100)
    }
    private var weeklyAverages: [Double] {
        (1...8).reversed().map { i in
            let slice = history.suffix(7 * i).prefix(7)
            return slice.isEmpty ? 0 : Double(slice.reduce(0) { $0 + $1.steps }) / Double(slice.count)
        }
    }

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(eyebrow: L.t("stats.eyebrow"), title: L.t("stats.title")) { EmptyView() }
            VStack(spacing: 20) {
                weekCard
                cardsGrid
                trendCard
                insightsCard
            }
            .padding(.horizontal, 24)
        }
        .task {
            history = await SupabaseAPI.historyFilled(days: 180)
            week = history.suffix(7).map { ($0.day, $0.steps) }
        }
    }

    private var weekCard: some View {
        CardSurface(padding: 24) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("stats.avg")).eyebrow(theme.p.s600)
                        Text(avg.formatted()).font(F.xl3).tabularNums().foregroundStyle(theme.p.s950)
                    }
                    Spacer()
                    Text(vsLastPct == nil ? L.t("stats.no_data")
                         : L.t("stats.vs_last", ["pct": "\(vsLastPct! > 0 ? "+" : "")\(vsLastPct!)"]))
                        .font(F.sans(12, .medium)).foregroundStyle(theme.p.s700)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(theme.p.s100, in: Capsule())
                }
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(week.enumerated()), id: \.element.day) { i, d in
                        VStack(spacing: 8) {
                            GeometryReader { geo in
                                VStack {
                                    Spacer(minLength: 0)
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(theme.p.s600)
                                        .opacity(i == week.count - 1 ? 1 : 0.55)
                                        .frame(height: max(2, geo.size.height * Double(d.steps) / Double(maxSteps)))
                                }
                            }
                            .frame(height: 140)
                            Text(Self.weekdayNarrow(d.day)).font(F.sans(10, .medium))
                                .foregroundStyle(theme.p.s600)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .rise()
    }

    private var cardsGrid: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                miniCard(L.t("stats.screen"), SettingsStore.formatScreenMin(weeklyEarned), L.t("stats.screen_sub"))
                miniCard(L.t("stats.goal"), "\(goalPct)%", L.t("stats.goal_sub"))
            }
            HStack(spacing: 16) {
                miniCard(L.t("stats.active"), "\(activeDays) / \(max(1, week.count))", L.t("stats.active_sub"))
                miniCard(L.t("stats.best"),
                         (best?.steps ?? 0) > 0 ? best!.steps.formatted() : "—",
                         (best?.steps ?? 0) > 0 ? Self.weekdayShort(best!.day) : L.t("stats.no_data"))
            }
        }
        .rise(delay: 0.06)
    }

    private func miniCard(_ label: String, _ value: String, _ sub: String) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 6) {
                Text(label).eyebrow(theme.p.s600)
                Text(value).font(F.sans(22, .semibold)).tabularNums().foregroundStyle(theme.p.s950)
                Text(sub).font(F.text11).foregroundStyle(theme.p.s600)
            }
        }
    }

    private var trendCard: some View {
        CardSurface(padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text(L.t("stats.trend")).eyebrow(theme.p.s600)
                GeometryReader { geo in
                    let vals = weeklyAverages
                    let maxV = max(1, vals.max() ?? 1)
                    let pts = vals.enumerated().map { i, v in
                        CGPoint(x: geo.size.width * Double(i) / Double(max(1, vals.count - 1)),
                                y: geo.size.height * (1 - v / maxV * 0.9))
                    }
                    ZStack {
                        Path { p in
                            guard let f = pts.first else { return }
                            p.move(to: f); pts.dropFirst().forEach { p.addLine(to: $0) }
                            p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                            p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                            p.closeSubpath()
                        }
                        .fill(LinearGradient(colors: [theme.p.s300.opacity(0.6), .clear],
                                             startPoint: .top, endPoint: .bottom))
                        Path { p in
                            guard let f = pts.first else { return }
                            p.move(to: f); pts.dropFirst().forEach { p.addLine(to: $0) }
                        }
                        .stroke(theme.p.s600, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(height: 110)
                Text(L.t("stats.trend_sub")).font(F.text11).foregroundStyle(theme.p.s600)
            }
        }
        .rise(delay: 0.12)
    }

    private var insightsCard: some View {
        CardSurface(padding: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: settings.isPro ? "sparkles" : "lock.fill")
                        .foregroundStyle(theme.p.s700)
                    Text(L.t("stats.insights")).eyebrow(theme.p.s600)
                }
                if settings.isPro {
                    let ins = Insights.compute(history: history, goal: goal, settings: settings)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(ins.score)").font(F.xl3).tabularNums().foregroundStyle(theme.p.s950)
                        Text("/ 100").font(F.sm).foregroundStyle(theme.p.s600)
                    }
                    ForEach(ins.messages, id: \.self) { m in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(theme.p.s600).frame(width: 5, height: 5).padding(.top, 6)
                            Text(m).font(F.sm).foregroundStyle(theme.p.s700)
                        }
                    }
                    HStack(spacing: 16) {
                        trendPill("7d", ins.trend7)
                        trendPill("30d", ins.trend30)
                        trendPill("90d", ins.trend90)
                    }
                } else {
                    Text(L.t("stats.insights_locked")).font(F.sm).foregroundStyle(theme.p.s600)
                }
            }
        }
        .rise(delay: 0.18)
    }

    private func trendPill(_ label: String, _ pct: Int?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: (pct ?? 0) > 0 ? "arrow.up.right" : (pct ?? 0) < 0 ? "arrow.down.right" : "minus")
                .font(.system(size: 10))
            Text(pct == nil ? "—" : "\(label) \(pct! > 0 ? "+" : "")\(pct!)%")
                .font(F.sans(11, .medium)).tabularNums()
        }
        .foregroundStyle(theme.p.s700)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(theme.p.s100, in: Capsule())
    }

    static func weekdayNarrow(_ iso: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: iso) else { return "" }
        let o = DateFormatter(); o.locale = Locale(identifier: L.lang == "sv" ? "sv_SE" : "en_US")
        o.dateFormat = "EEEEE"
        return o.string(from: d).uppercased()
    }

    static func weekdayShort(_ iso: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: iso) else { return "" }
        let o = DateFormatter(); o.locale = Locale(identifier: L.lang == "sv" ? "sv_SE" : "en_US")
        o.dateFormat = "EEE d MMM"
        return o.string(from: d)
    }
}

/// Port of `src/lib/insights.ts` — activity score, personal messages and
/// 7 / 30 / 90 day trends.
enum Insights {
    struct Result { let score: Int; let messages: [String]; let trend7: Int?; let trend30: Int?; let trend90: Int? }

    static func compute(history: [(day: String, steps: Int, distance: Double)], goal: Int,
                        settings: SettingsStore) -> Result {
        func avg(_ s: ArraySlice<(day: String, steps: Int, distance: Double)>) -> Double {
            s.isEmpty ? 0 : Double(s.reduce(0) { $0 + $1.steps }) / Double(s.count)
        }
        func trend(_ n: Int) -> Int? {
            let recent = avg(history.suffix(n))
            let prior = avg(history.dropLast(n).suffix(n))
            guard prior > 0 else { return nil }
            return Int((recent - prior) / prior * 100)
        }
        let last30 = history.suffix(30)
        let consistency = last30.isEmpty ? 0 : Double(last30.filter { $0.steps >= goal }.count) / Double(last30.count)
        let volume = min(1, avg(last30) / Double(max(1, goal)))
        let score = Int(((consistency * 0.6) + (volume * 0.4)) * 100)

        // Best weekday
        var byWeekday: [Int: [Int]] = [:]
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        for d in history.suffix(90) {
            guard let date = f.date(from: d.day) else { continue }
            byWeekday[Calendar.current.component(.weekday, from: date), default: []].append(d.steps)
        }
        var messages: [String] = []
        if let best = byWeekday.max(by: { (avgOf($0.value)) < (avgOf($1.value)) })?.key {
            let df = DateFormatter(); df.locale = Locale(identifier: L.lang == "sv" ? "sv_SE" : "en_US")
            let name = df.weekdaySymbols[best - 1]
            messages.append(L.t("insights.best_day", ["d": name]))
        }
        if let t7 = trend(7) {
            messages.append(t7 >= 0 ? L.t("insights.up", ["pct": "\(t7)"]) : L.t("insights.down", ["pct": "\(abs(t7))"]))
        }
        let forecast = Int(avg(history.suffix(14)) * 30)
        messages.append(L.t("insights.forecast", ["n": forecast.formatted()]))
        return Result(score: score, messages: messages, trend7: trend(7), trend30: trend(30), trend90: trend(90))
    }

    private static func avgOf(_ a: [Int]) -> Double {
        a.isEmpty ? 0 : Double(a.reduce(0, +)) / Double(a.count)
    }
}
