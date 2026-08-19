import SwiftUI

/// 1:1 port of `src/routes/stats.tsx` — weekly bar card, four stat cards,
/// the 8-week trend chart and the PRO insights block (`src/lib/insights.ts`).
struct StatsView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @ObservedObject var health = HealthKitService.shared
    @Binding var tab: AppTab

    @State private var history: [DayTotals] = []
    @State private var proOpen = false

    // MARK: Derived numbers — same math as the web page

    /// Last 7 days, with today's live HealthKit total layered on top so the
    /// page always matches what the rest of the app shows.
    private var week: [DayTotals] {
        let last7 = Array(history.suffix(7))
        guard let today = last7.last else { return last7 }
        var out = last7
        out[out.count - 1] = DayTotals(day: today.day,
                                       steps: max(today.steps, health.steps),
                                       distanceKm: max(today.distanceKm, health.distanceKm),
                                       calories: max(today.calories, health.calories),
                                       exerciseMinutes: max(today.exerciseMinutes, health.exerciseMinutes))
        return out
    }
    private var syncedHistory: [DayTotals] {
        guard !history.isEmpty else { return [] }
        var out = history
        out.replaceSubrange((out.count - week.count)..<out.count, with: week)
        return out
    }
    private var maxSteps: Int { max(1, week.map(\.steps).max() ?? 1) }
    private var avg: Int { week.isEmpty ? 0 : week.reduce(0) { $0 + $1.steps } / week.count }
    private var weeklyEarnedMin: Int { week.reduce(0) { $0 + settings.earnedMin(from: $1.steps) } }
    private var goal: Int { max(1, settings.dailyGoal) }
    private var last30: [DayTotals] { Array(syncedHistory.suffix(30)) }
    private var goalPct: Int {
        last30.isEmpty ? 0 : Int((Double(last30.filter { $0.steps >= goal }.count) / Double(last30.count) * 100).rounded())
    }
    private var activeDays: Int { week.filter { $0.steps >= goal }.count }
    private var best: DayTotals? { last30.max(by: { $0.steps < $1.steps }) }
    private var vsLastPct: Int? {
        let h = syncedHistory
        let last7 = h.suffix(7).reduce(0) { $0 + $1.steps }
        let prev7 = h.dropLast(7).suffix(7).reduce(0) { $0 + $1.steps }
        guard prev7 > 0 else { return nil }
        return Int((Double(last7 - prev7) / Double(prev7) * 100).rounded())
    }
    /// Weekly step averages for the last 8 weeks (oldest first).
    private var weeklyAverages: [Double] {
        let h = syncedHistory
        return (1...8).reversed().map { i -> Double in
            let end = h.count - 7 * (i - 1)
            let start = max(0, h.count - 7 * i)
            guard end > start else { return 0 }
            let slice = h[start..<end]
            return slice.isEmpty ? 0 : Double(slice.reduce(0) { $0 + $1.steps }) / Double(slice.count)
        }
    }
    private var trendPct: Int? {
        let w = weeklyAverages
        let recent4 = w.suffix(4).reduce(0, +)
        let prior4 = w.prefix(4).reduce(0, +)
        guard prior4 > 0 else { return nil }
        return Int(((recent4 - prior4) / prior4 * 100).rounded())
    }
    private var hasTrendData: Bool { weeklyAverages.contains { $0 > 0 } }
    private var insights: Insights {
        Insights.compute(history: syncedHistory, dailyGoal: settings.dailyGoal, settings: settings)
    }

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(eyebrow: L.t("stats.eyebrow"), title: L.t("stats.title")) { EmptyView() }
            VStack(spacing: 20) {
                weekCard
                cardsGrid
                trendCard
                proCard
            }
            .padding(.horizontal, 24)
        }
        .task {
            await HealthKitService.shared.refreshToday()
            history = await SupabaseAPI.historyTotals(days: 180)
        }
        .sheet(isPresented: $proOpen) {
            ProUpgradeDialog().environmentObject(theme).environmentObject(settings)
        }
    }

    // MARK: Weekly bars — `rounded-3xl bg-card p-6 ring-1 ring-black/5`

    private var weekCard: some View {
        CardSurface(padding: 24) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t("stats.avg")).eyebrow(theme.p.s600)
                        Text(avg.formatted()).font(F.xl3).tabularNums().foregroundStyle(theme.p.s950)
                    }
                    Spacer()
                    Text(vsLastPct == nil
                         ? L.t("stats.no_data")
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
                                    UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 0,
                                                           bottomTrailingRadius: 0, topTrailingRadius: 8,
                                                           style: .continuous)
                                        .fill(theme.p.s600)
                                        .opacity(i == week.count - 1 ? 1 : 0.55)
                                        .frame(height: max(2, geo.size.height * Double(d.steps) / Double(maxSteps)))
                                }
                            }
                            .frame(height: 160)
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

    // MARK: Four cards

    private var cardsGrid: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                miniCard(L.t("stats.screen"), SettingsStore.formatScreenMin(weeklyEarnedMin), L.t("stats.screen_sub"))
                miniCard(L.t("stats.goal"), "\(goalPct)%", L.t("stats.goal_sub"))
            }
            HStack(spacing: 16) {
                miniCard(L.t("stats.active"), "\(activeDays) / \(max(1, week.count))", L.t("stats.active_sub"))
                miniCard(L.t("stats.best"),
                         (best?.steps ?? 0) > 0 ? best!.steps.formatted() : "—",
                         (best?.steps ?? 0) > 0 ? Self.weekdayLong(best!.day) : L.t("stats.no_data"))
            }
        }
    }

    private func miniCard(_ label: String, _ value: String, _ sub: String) -> some View {
        CardSurface(radius: R.xl2, padding: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).eyebrow(theme.p.s600)
                Text(value).font(F.sans(20, .semibold)).tabularNums().foregroundStyle(theme.foreground)
                Text(sub).font(F.xs).foregroundStyle(theme.p.s600)
            }
        }
    }

    // MARK: 8-week trend

    private var trendCard: some View {
        CardSurface(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L.t("stats.trend")).font(F.sans(14, .semibold)).foregroundStyle(theme.foreground)
                if hasTrendData {
                    GeometryReader { geo in
                        let vals = weeklyAverages
                        let maxV = max(1, vals.max() ?? 1)
                        let pts = vals.enumerated().map { i, v in
                            CGPoint(x: geo.size.width * Double(i) / Double(max(1, vals.count - 1)),
                                    y: geo.size.height * (1 - (v / maxV) * 0.85) - geo.size.height * 0.05)
                        }
                        ZStack {
                            Path { p in
                                guard let f = pts.first else { return }
                                p.move(to: f); pts.dropFirst().forEach { p.addLine(to: $0) }
                                p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                                p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                                p.closeSubpath()
                            }
                            .fill(theme.p.s600.opacity(0.12))
                            Path { p in
                                guard let f = pts.first else { return }
                                p.move(to: f); pts.dropFirst().forEach { p.addLine(to: $0) }
                            }
                            .stroke(theme.p.s600, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .frame(height: 110)
                    Text(trendPct == nil
                         ? L.t("stats.no_data")
                         : L.t("stats.trend_sub", ["pct": "\(trendPct! > 0 ? "+" : "")\(trendPct!)"]))
                        .font(F.xs).foregroundStyle(theme.p.s600)
                } else {
                    Text(L.t("stats.no_data")).font(F.xs).foregroundStyle(theme.p.s600)
                }
            }
        }
    }

    // MARK: PRO insights

    private var proCard: some View {
        let locked = !settings.isPro
        return ZStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: R.xl, style: .continuous).fill(theme.p.s600)
                            Image(systemName: "sparkles").font(.system(size: 15))
                                .foregroundStyle(theme.primaryForeground)
                        }
                        .frame(width: 32, height: 32)
                        Text(L.t("stats.pro_title")).font(F.sans(14, .semibold))
                            .foregroundStyle(theme.foreground)
                    }
                    Spacer()
                    if locked && settings.role != "child" {
                        Button { proOpen = true } label: {
                            Text(L.t("pro.upgrade")).font(F.sans(12, .semibold))
                                .foregroundStyle(theme.primaryForeground)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(theme.p.s600, in: RoundedRectangle(cornerRadius: R.xl, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(settings.isPro
                     ? L.t("stats.pro_sub")
                     : settings.role == "child" ? L.t("pro.child_desc") : L.t("stats.pro.locked"))
                    .font(F.xs).foregroundStyle(theme.p.s600)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                insightsBody
                    .padding(.top, 16)
                    .blur(radius: locked ? 4 : 0)
                    .allowsHitTesting(!locked)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(locked ? theme.p.s50 : theme.card,
                        in: RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                    .strokeBorder(locked ? theme.p.s200 : theme.ringBorder, lineWidth: 1)
            )

            if locked {
                Image(systemName: "lock.fill").font(.system(size: 22))
                    .foregroundStyle(theme.p.s700)
                    .allowsHitTesting(false)
            }
        }
    }

    private var insightsBody: some View {
        let ins = insights
        return VStack(alignment: .leading, spacing: 16) {
            // Activity score
            HStack(spacing: 16) {
                ScoreRing(score: ins.activityScore)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("stats.pro.score")).eyebrow(theme.p.s600)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(ins.activityScore)").font(F.sans(24, .semibold)).tabularNums()
                            .foregroundStyle(theme.foreground)
                        Text("/ 100").font(F.sm).foregroundStyle(theme.p.s600)
                    }
                    Text(L.t("stats.pro.score_sub")).font(F.xs).foregroundStyle(theme.p.s600)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                .strokeBorder(theme.ringBorder, lineWidth: 1))

            // Personal messages
            let messages = Insights.messages(ins)
            if !messages.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t("stats.pro.messages")).eyebrow(theme.p.s600)
                    ForEach(messages, id: \.self) { m in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(theme.p.s600).frame(width: 6, height: 6).padding(.top, 6)
                            Text(m).font(F.sm).foregroundStyle(theme.foreground)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                    .strokeBorder(theme.ringBorder, lineWidth: 1))
            }

            // Trends
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("stats.pro.trends")).eyebrow(theme.p.s600)
                HStack(spacing: 12) {
                    trendTile(L.t("stats.pro.trend7"), ins.trend7)
                    trendTile(L.t("stats.pro.trend30"), ins.trend30)
                    trendTile(L.t("stats.pro.trend90"), ins.trend90)
                }
            }

            // Forecast
            VStack(alignment: .leading, spacing: 2) {
                Text(L.t("stats.pro.forecast")).eyebrow(theme.p.s600)
                Text(ins.forecastSteps.formatted()).font(F.sans(24, .semibold)).tabularNums()
                    .foregroundStyle(theme.foreground)
                Text(L.t("stats.pro.forecast_sub")).font(F.xs).foregroundStyle(theme.p.s600)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                .strokeBorder(theme.ringBorder, lineWidth: 1))
        }
    }

    private func trendTile(_ label: String, _ value: Double) -> some View {
        let rounded = Int(value.rounded())
        let up = rounded > 1, down = rounded < -1
        let color = up ? Color(hex: "#059669") : down ? Color(hex: "#E11D48") : theme.p.s600
        return VStack(alignment: .leading, spacing: 4) {
            Text(label).eyebrow(theme.p.s600)
            HStack(spacing: 4) {
                Image(systemName: up ? "chart.line.uptrend.xyaxis"
                      : down ? "chart.line.downtrend.xyaxis" : "minus")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(rounded > 0 ? "+" : "")\(rounded)%")
                    .font(F.sans(16, .semibold)).tabularNums()
            }
            .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
            .strokeBorder(theme.ringBorder, lineWidth: 1))
    }

    // MARK: Date helpers

    static func weekdayNarrow(_ iso: String) -> String {
        guard let d = parse(iso) else { return "" }
        let o = DateFormatter(); o.locale = Locale(identifier: L.lang == "sv" ? "sv_SE" : "en_US")
        o.dateFormat = "EEEEE"
        return o.string(from: d).uppercased()
    }

    static func weekdayLong(_ iso: String) -> String {
        guard let d = parse(iso) else { return "" }
        let o = DateFormatter(); o.locale = Locale(identifier: L.lang == "sv" ? "sv_SE" : "en_US")
        o.dateFormat = "EEEE"
        return o.string(from: d)
    }

    private static func parse(_ iso: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.date(from: iso)
    }
}

/// Port of the 72pt `ScoreRing` svg in `src/routes/stats.tsx`.
private struct ScoreRing: View {
    @EnvironmentObject var theme: Theme
    let score: Int

    var body: some View {
        ZStack {
            Circle().stroke(theme.p.s100, lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0, min(1, Double(score) / 100)))
                .stroke(theme.p.s600, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)").font(F.sans(14, .semibold)).tabularNums()
                .foregroundStyle(theme.foreground)
        }
        .frame(width: 72, height: 72)
    }
}

/// 1:1 port of `src/lib/insights.ts`.
struct Insights {
    var activityScore: Int
    var trend7: Double
    var trend30: Double
    var trend90: Double
    var forecastSteps: Int
    var bestWeekday: Int
    var worstWeekday: Int
    var weekendScreenBias: Double
    var activeDays: Int

    private static func avg(_ xs: [Double]) -> Double {
        xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count)
    }

    private static func pctChange(_ a: Double, _ b: Double) -> Double {
        if b == 0 { return a == 0 ? 0 : 100 }
        return (a - b) / b * 100
    }

    private static func linreg(_ ys: [Double]) -> (slope: Double, intercept: Double) {
        let n = ys.count
        guard n > 0 else { return (0, 0) }
        let xs = (0..<n).map(Double.init)
        let mx = avg(xs), my = avg(ys)
        var num = 0.0, den = 0.0
        for i in 0..<n {
            num += (xs[i] - mx) * (ys[i] - my)
            den += pow(xs[i] - mx, 2)
        }
        let slope = den == 0 ? 0 : num / den
        return (slope, my - slope * mx)
    }

    private static func slice(_ xs: [Double], _ from: Int, _ to: Int?) -> [Double] {
        let count = xs.count
        let start = from < 0 ? max(0, count + from) : min(from, count)
        let endRaw = to ?? count
        let end = endRaw < 0 ? max(0, count + endRaw) : min(endRaw, count)
        guard end > start else { return [] }
        return Array(xs[start..<end])
    }

    static func compute(history: [DayTotals], dailyGoal: Int, settings: SettingsStore) -> Insights {
        let steps = history.map { Double($0.steps) }

        let last7 = slice(steps, -7, nil)
        let prev7 = slice(steps, -14, -7)
        let last30 = slice(steps, -30, nil)
        let prev30 = slice(steps, -60, -30)
        let last90 = slice(steps, -90, nil)
        let prev90 = slice(steps, -180, -90)

        let trend7 = pctChange(avg(last7), avg(prev7))
        let trend30 = pctChange(avg(last30), avg(prev30))
        let trend90 = pctChange(avg(last90), avg(prev90))

        let window = last30.isEmpty ? last7 : last30
        let reg = linreg(window)
        let forecast = max(0, Int((reg.slope * Double(window.count) + reg.intercept).rounded()))

        // Weekday averages over the last 30 days.
        var buckets: [[Double]] = Array(repeating: [], count: 7)
        let src = Array(history.suffix(30))
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        var weekendMin = 0.0, weekdayMin = 0.0
        var weekendCount = 0, weekdayCount = 0
        for d in src {
            guard let date = f.date(from: d.day) else { continue }
            let dow = Calendar.current.component(.weekday, from: date) - 1  // 0 = Sunday
            buckets[dow].append(Double(d.steps))
            let min = Double(settings.earnedMin(from: d.steps))
            if dow == 0 || dow == 6 { weekendMin += min; weekendCount += 1 }
            else { weekdayMin += min; weekdayCount += 1 }
        }
        let dayAvgs = buckets.map { avg($0) }
        let maxIdx = dayAvgs.firstIndex(of: dayAvgs.max() ?? 0) ?? 0
        let nonZero = dayAvgs.map { $0 == 0 ? Double.infinity : $0 }
        let minIdx = nonZero.firstIndex(of: nonZero.min() ?? 0) ?? 0

        let weAvg = weekendCount > 0 ? weekendMin / Double(weekendCount) : 0
        let wdAvg = weekdayCount > 0 ? weekdayMin / Double(weekdayCount) : 0
        let bias = pctChange(weAvg, wdAvg)

        let goal = Double(max(1, dailyGoal))
        let goalHitRatio = last30.isEmpty ? 0 : Double(last30.filter { $0 >= goal }.count) / Double(last30.count)
        let avgRatio = min(1, avg(last30) / goal)
        let mean = avg(last30)
        let sd = last30.isEmpty ? 0 : sqrt(avg(last30.map { pow($0 - mean, 2) }))
        let consistency = last30.isEmpty ? 0 : 1 - min(1, sd / max(1, mean))
        let trendComponent = max(0, min(1, 0.5 + trend30 / 200))
        let score = Int((goalHitRatio * 40 + avgRatio * 30 + consistency * 15 + trendComponent * 15).rounded())

        return Insights(activityScore: max(0, min(100, score)),
                        trend7: trend7, trend30: trend30, trend90: trend90,
                        forecastSteps: forecast,
                        bestWeekday: maxIdx, worstWeekday: minIdx,
                        weekendScreenBias: bias,
                        activeDays: last30.filter { $0 >= goal }.count)
    }

    /// Port of `buildMessages` — at most three personal notes.
    static func messages(_ ins: Insights) -> [String] {
        var msgs: [String] = []
        let best = L.weekdayPlural(ins.bestWeekday)
        let worst = L.weekdayPlural(ins.worstWeekday)

        msgs.append(L.t("insights.msg.best_day", ["d": best]))
        if ins.weekendScreenBias > 10 {
            msgs.append(L.t("insights.msg.weekend_more", ["pct": "\(Int(ins.weekendScreenBias.rounded()))"]))
        } else if ins.weekendScreenBias < -10 {
            msgs.append(L.t("insights.msg.weekend_less", ["pct": "\(Int(ins.weekendScreenBias.rounded()))"]))
        }
        if ins.trend30 > 5 {
            msgs.append(L.t("insights.msg.trend_up", ["pct": "\(Int(ins.trend30.rounded()))"]))
        } else if ins.trend30 < -5 {
            msgs.append(L.t("insights.msg.trend_down", ["pct": "\(Int(abs(ins.trend30).rounded()))"]))
        }
        if ins.activeDays >= 20 {
            msgs.append(L.t("insights.msg.strong_month", ["n": "\(ins.activeDays)"]))
        }
        if worst != best {
            msgs.append(L.t("insights.msg.quietest", ["d": worst]))
        }
        return Array(msgs.prefix(3))
    }
}
