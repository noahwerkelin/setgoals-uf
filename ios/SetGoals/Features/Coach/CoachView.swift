import SwiftUI
import Supabase

/// Port of `src/routes/coach.tsx` — PRO-locked AI coach, now personalized:
/// daily summary, personal challenges, persistent memory and confirmable actions.
struct CoachView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @Binding var tab: AppTab

    @State private var msgs: [CoachMessage] = []
    @State private var text = ""
    @State private var busy = false
    @State private var proOpen = false

    @State private var state: CoachState?
    @State private var summary: CoachSummary?
    @State private var summaryLoading = false
    @State private var summaryFailed = false
    @State private var lastFailedMessage: String?

    @State private var pendingGoal: Int?
    @State private var editingChallenge: CoachChallengeSpec?
    @State private var showPrefs = false
    @State private var showStats = false
    @State private var showSettings = false
    @State private var toast: String?

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(eyebrow: L.t("coach.eyebrow"), title: L.t("coach.title")) {
                Button { showPrefs = true } label: {
                    ZStack {
                        Circle().fill(theme.p.s600)
                        Image(systemName: "sparkles").font(.system(size: 18))
                            .foregroundStyle(theme.primaryForeground)
                    }
                    .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .disabled(!settings.isPro)
                .accessibilityLabel(L.t("coach.prefs"))
            }
            if !settings.isPro {
                lockCard.padding(.horizontal, 24)
            } else {
                VStack(spacing: 12) {
                    dailyCard
                    challengesCard
                    chat
                }
                .padding(.horizontal, 24)
            }
        }
        .task {
            guard settings.isPro else { return }
            await loadState()
            await loadSummary(force: false)
        }
        .alert(L.t("coach.goal_confirm_title"), isPresented: Binding(get: { pendingGoal != nil }, set: { if !$0 { pendingGoal = nil } })) {
            Button(L.t("coach.cancel"), role: .cancel) { pendingGoal = nil }
            Button(L.t("coach.confirm")) { if let g = pendingGoal { Task { await applyGoal(g) } } }
        } message: {
            Text(L.t("coach.goal_confirm_msg", ["a": "\(settings.dailyGoal)", "b": "\(pendingGoal ?? 0)"]))
        }
        .sheet(item: $editingChallenge) { spec in
            ChallengeEditor(spec: spec) { edited in
                editingChallenge = nil
                Task { await accept(edited) }
            }
            .environmentObject(theme)
        }
        .sheet(isPresented: $showPrefs, onDismiss: { Task { await loadState(); await loadSummary(force: false) } }) {
            CoachPreferencesView(onCleared: { msgs = [] }).environmentObject(theme)
        }
        .fullScreenCover(isPresented: $showStats) {
            StatsView(tab: $tab).environmentObject(theme).environmentObject(settings)
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(tab: $tab).environmentObject(theme).environmentObject(settings)
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast).font(F.sm).foregroundStyle(theme.primaryForeground)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(theme.p.s900, in: Capsule())
                    .padding(.bottom, 100)
                    .transition(.opacity)
            }
        }
    }

    // MARK: Lock

    /// Port of `ProLockCard` in `src/components/Pro.tsx`.
    private var lockCard: some View {
        let isChild = settings.role == "child"
        return CardSurface(padding: 24) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: R.xl2, style: .continuous).fill(theme.p.s100)
                    Image(systemName: "sparkles").font(.system(size: 22)).foregroundStyle(theme.p.s700)
                }
                .frame(width: 48, height: 48)
                VStack(spacing: 4) {
                    Text(L.t("pro.badge")).font(F.sans(12, .semibold))
                        .textCase(.uppercase).tracking(1.6).foregroundStyle(theme.p.s600)
                    Text(L.t("coach.locked_title")).font(F.sans(16, .semibold))
                        .foregroundStyle(theme.foreground)
                    Text(isChild ? L.t("pro.child_desc") : L.t("coach.locked_desc"))
                        .font(F.sm).foregroundStyle(theme.p.s600).multilineTextAlignment(.center)
                }
                if !isChild {
                    Button { proOpen = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles").font(.system(size: 14, weight: .semibold))
                            Text(L.t("pro.upgrade")).font(F.sans(14, .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(theme.primaryForeground)
                        .background(theme.primary, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $proOpen) {
            ProUpgradeDialog().environmentObject(theme).environmentObject(settings)
        }
    }

    // MARK: Daily summary

    private var dailyCard: some View {
        CardSurface(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L.t("coach.today")).font(F.sans(12, .semibold)).textCase(.uppercase)
                        .tracking(1.4).foregroundStyle(theme.p.s600)
                    Spacer()
                    Button { Task { await loadState(); await loadSummary(force: true) } } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.p.s600)
                    }
                    .disabled(summaryLoading)
                    .accessibilityLabel(L.t("coach.refresh"))
                }
                if let st = state {
                    let pct = min(1, Double(st.today.steps) / Double(max(1, st.goal)))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L.t("coach.steps_of", ["a": st.today.steps.formatted(), "b": st.goal.formatted()]))
                            .font(F.sans(15, .semibold)).foregroundStyle(theme.foreground)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(theme.p.s100)
                                Capsule().fill(theme.primary).frame(width: g.size.width * pct)
                            }
                        }
                        .frame(height: 8)
                        HStack {
                            Text(L.t("coach.earned_of", ["a": SettingsStore.formatScreenMin(st.today.earned_min),
                                                          "b": SettingsStore.formatScreenMin(st.cap_min)]))
                            Spacer()
                            if let avg = st.week.avg_steps {
                                Text(L.t("coach.vs_avg", ["n": avg.formatted()]))
                            }
                        }
                        .font(F.xs).foregroundStyle(theme.p.s600)
                    }
                }
                if summaryLoading && summary == nil {
                    HStack { ProgressView().tint(theme.p.s600); Spacer() }
                } else if let s = summary {
                    section(L.t("coach.insight"), s.insight, icon: "lightbulb")
                    section(L.t("coach.next"), s.next_action, icon: "figure.walk", sub: s.next_action_why)
                    Text(s.reinforcement).font(F.xs).foregroundStyle(theme.p.s700)
                    if let ch = s.challenge {
                        suggestedChallenge(ch)
                    }
                } else if summaryFailed {
                    HStack {
                        Text(L.t("coach.summary_error")).font(F.xs).foregroundStyle(theme.p.s600)
                        Spacer()
                        Button(L.t("coach.retry")) { Task { await loadSummary(force: true) } }
                            .font(F.sans(12, .semibold)).foregroundStyle(theme.p.s700)
                    }
                }
            }
        }
    }

    private func section(_ title: String, _ body: String, icon: String, sub: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(theme.p.s700)
                .frame(width: 28, height: 28)
                .background(theme.p.s100, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(F.sans(11, .semibold)).textCase(.uppercase).tracking(1.2).foregroundStyle(theme.p.s500)
                Text(body).font(F.sm).foregroundStyle(theme.foreground).fixedSize(horizontal: false, vertical: true)
                if let sub { Text(sub).font(F.xs).foregroundStyle(theme.p.s600).fixedSize(horizontal: false, vertical: true) }
            }
        }
    }

    private func suggestedChallenge(_ ch: CoachChallengeSpec) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.t("coach.suggested_challenge")).font(F.sans(11, .semibold)).textCase(.uppercase)
                .tracking(1.2).foregroundStyle(theme.p.s500)
            Text(ch.title).font(F.sans(14, .semibold)).foregroundStyle(theme.foreground)
            if !ch.reason.isEmpty { Text(ch.reason).font(F.xs).foregroundStyle(theme.p.s600) }
            Text("\(L.t("coach.metric.\(ch.metric)")) · \(ch.target.formatted()) · \(L.t("coach.days", ["n": "\(ch.days)"]))")
                .font(F.xs).foregroundStyle(theme.p.s600)
            HStack(spacing: 8) {
                pill(L.t("coach.accept"), filled: true) { Task { await accept(ch) } }
                pill(L.t("coach.modify")) { editingChallenge = ch }
                pill(L.t("coach.dismiss")) { summary?.challenge = nil }
            }
        }
        .padding(12)
        .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
    }

    private func pill(_ label: String, filled: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(F.sans(12, .semibold))
                .foregroundStyle(filled ? theme.primaryForeground : theme.p.s700)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(filled ? theme.primary : theme.p.s100, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Challenges

    @ViewBuilder private var challengesCard: some View {
        if let list = state?.challenges, !list.isEmpty {
            CardSurface(padding: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L.t("coach.challenges")).font(F.sans(12, .semibold)).textCase(.uppercase)
                        .tracking(1.4).foregroundStyle(theme.p.s600)
                    ForEach(list) { c in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(c.title).font(F.sans(14, .semibold)).foregroundStyle(theme.foreground)
                                Spacer()
                                if c.status == "completed" {
                                    Label(L.t("coach.completed"), systemImage: "checkmark.seal.fill")
                                        .font(F.xs).foregroundStyle(theme.p.s700)
                                } else {
                                    Button { Task { await dismiss(c.id) } } label: {
                                        Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(theme.p.s500)
                                    }
                                    .accessibilityLabel(L.t("coach.dismiss"))
                                }
                            }
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(theme.p.s100)
                                    Capsule().fill(theme.primary)
                                        .frame(width: g.size.width * min(1, Double(c.progress) / Double(max(1, c.target))))
                                }
                            }
                            .frame(height: 6)
                            Text("\(c.progress.formatted()) / \(c.target.formatted()) · \(L.t("coach.ends", ["d": c.end_day]))")
                                .font(F.xs).foregroundStyle(theme.p.s600)
                        }
                    }
                }
            }
        }
    }

    // MARK: Chat

    private var chat: some View {
        VStack(spacing: 12) {
            ForEach(msgs) { m in
                VStack(alignment: m.role == "user" ? .trailing : .leading, spacing: 6) {
                    HStack {
                        if m.role == "user" { Spacer(minLength: 40) }
                        Text(m.content)
                            .font(F.sm)
                            .foregroundStyle(m.role == "user" ? theme.primaryForeground : theme.p.s900)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(m.role == "user" ? theme.primary : theme.card,
                                        in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                                    .strokeBorder(m.role == "user" ? .clear : theme.ringBorder, lineWidth: 1)
                            )
                        if m.role == "assistant" { Spacer(minLength: 40) }
                    }
                    if !m.actions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(m.actions) { a in actionButton(a) }
                        }
                    }
                }
            }
            if busy {
                HStack { ProgressView().tint(theme.p.s600); Spacer() }
            }
            if let failed = lastFailedMessage, !busy {
                HStack {
                    Spacer()
                    pill(L.t("coach.retry")) { Task { await send(failed, retry: true) } }
                }
            }
            suggestions
            composer
        }
    }

    private func actionButton(_ a: CoachAction) -> some View {
        let (label, icon): (String, String) = {
            switch a.type {
            case "set_daily_goal": return (L.t("coach.action.goal", ["n": "\(a.value ?? 0)"]), "target")
            case "challenge": return (a.challenge?.title ?? L.t("coach.suggested_challenge"), "flag.checkered")
            default: return (L.t("coach.action.\(a.target ?? "stats")"), "arrow.up.right")
            }
        }()
        return Button { perform(a) } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(F.sans(12, .semibold)).lineLimit(1)
            }
            .foregroundStyle(theme.p.s700)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(theme.p.s100, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var suggestions: some View {
        let prompts = state?.prompts ?? ["coach.s1", "coach.s2", "coach.s3"].map { L.t($0) }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(prompts, id: \.self) { p in
                    Button { Task { await send(p) } } label: {
                        Text(p).font(F.xs).foregroundStyle(theme.p.s700)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(theme.p.s100, in: Capsule())
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField(L.t("coach.placeholder"), text: $text).fieldStyle()
            Button { Task { await send(text) } } label: {
                ZStack {
                    Circle().fill(theme.primary)
                    Image(systemName: "paperplane.fill").font(.system(size: 15))
                        .foregroundStyle(theme.primaryForeground)
                }
                .frame(width: 46, height: 46)
            }
            .disabled(busy || text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.top, 4)
    }

    // MARK: Actions

    private func perform(_ a: CoachAction) {
        switch a.type {
        case "set_daily_goal":
            if let v = a.value { pendingGoal = v }
        case "challenge":
            if let c = a.challenge { editingChallenge = c }
        default:
            switch a.target {
            case "stats": showStats = true
            case "challenges": tab = .challenges
            case "screen_time": showSettings = true
            case "preferences": showPrefs = true
            default: break
            }
        }
    }

    private func flash(_ s: String) {
        withAnimation { toast = s }
        Task { try? await Task.sleep(nanoseconds: 2_500_000_000); withAnimation { toast = nil } }
    }

    private func applyGoal(_ g: Int) async {
        pendingGoal = nil
        do {
            try await SupabaseAPI.updateSettings(["daily_goal": .integer(g)])
            settings.dailyGoal = g
            flash(L.t("coach.goal_saved", ["n": "\(g)"]))
            await loadState()
        } catch {
            flash(L.t("coach.goal_failed"))
        }
    }

    private func accept(_ c: CoachChallengeSpec) async {
        do {
            let _: CoachOK = try await CoachService.call(["action": "accept_challenge", "challenge": c.json])
            summary?.challenge = nil
            flash(L.t("coach.challenge_saved"))
            await loadState()
        } catch {
            flash(L.t("coach.challenge_failed"))
        }
    }

    private func dismiss(_ id: String) async {
        let _: CoachOK? = try? await CoachService.call(["action": "dismiss_challenge", "id": .string(id)])
        await loadState()
    }

    // MARK: Loading

    private func loadState() async {
        guard let s: CoachState = try? await CoachService.call(["action": "state", "lang": .string(L.lang)]) else { return }
        state = s
        if msgs.isEmpty {
            msgs = s.history.isEmpty
                ? [CoachMessage(role: "assistant", content: L.t("coach.seed"))]
                : s.history.map { CoachMessage(role: $0.role, content: $0.content) }
        }
    }

    private func loadSummary(force: Bool) async {
        summaryLoading = true
        summaryFailed = false
        do {
            summary = try await CoachService.call(["action": "summary", "lang": .string(L.lang), "force": .bool(force)])
        } catch {
            summaryFailed = true
        }
        summaryLoading = false
    }

    private func send(_ raw: String, retry: Bool = false) async {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !busy else { return }
        if !retry { msgs.append(CoachMessage(role: "user", content: value)) }
        lastFailedMessage = nil
        text = ""
        busy = true
        do {
            let reply: CoachReply = try await CoachService.call(["action": "chat", "message": .string(value), "lang": .string(L.lang)])
            msgs.append(CoachMessage(role: "assistant", content: reply.reply, actions: reply.actions ?? []))
            Task { await loadState() }
        } catch CoachError.status(429) {
            lastFailedMessage = value
            flash(L.t("coach.rate_limited"))
        } catch {
            lastFailedMessage = value
            flash(L.t("coach.error"))
        }
        busy = false
    }
}

// MARK: - Models

struct CoachMessage: Identifiable {
    var id = UUID()
    let role: String
    let content: String
    var actions: [CoachAction] = []
}

struct CoachChallengeSpec: Codable, Identifiable, Hashable {
    var id: String { "\(title)-\(metric)-\(target)-\(days)" }
    var title: String
    var reason: String
    var metric: String
    var target: Int
    var days: Int
    var json: AnyJSON {
        .object(["title": .string(title), "reason": .string(reason), "metric": .string(metric),
                 "target": .integer(target), "days": .integer(days)])
    }
    enum CodingKeys: String, CodingKey { case title, reason, metric, target, days }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        reason = (try? c.decode(String.self, forKey: .reason)) ?? ""
        metric = try c.decode(String.self, forKey: .metric)
        target = try c.decode(Int.self, forKey: .target)
        days = try c.decode(Int.self, forKey: .days)
    }
}

struct CoachAction: Decodable, Identifiable {
    let id = UUID()
    let type: String
    let value: Int?
    let target: String?
    let challenge: CoachChallengeSpec?
    enum CodingKeys: String, CodingKey { case type, value, target, challenge }
}

struct CoachReply: Decodable { let reply: String; let actions: [CoachAction]? }
struct CoachOK: Decodable { let ok: Bool? }

struct CoachSummary: Decodable {
    let insight: String
    let next_action: String
    let next_action_why: String
    let reinforcement: String
    var challenge: CoachChallengeSpec?
}

struct CoachProfile: Decodable {
    var main_goal: String
    var coaching_style: String
    var personal_target: String
    var preferences: [String]
    var strategies: [Strategy]
    struct Strategy: Decodable { let text: String; let useful: Bool? }
}

struct CoachState: Decodable {
    struct Today: Decodable { let steps: Int; let earned_min: Int }
    struct Week: Decodable { let avg_steps: Int?; let prev_avg_steps: Int?; let goal_days: Int }
    struct Hist: Decodable { let role: String; let content: String }
    struct Challenge: Decodable, Identifiable {
        let id: String; let title: String; let metric: String
        let target: Int; let progress: Int; let status: String; let end_day: String
    }
    let profile: CoachProfile
    let history: [Hist]
    let challenges: [Challenge]
    let today: Today
    let goal: Int
    let cap_min: Int
    let week: Week
    let prompts: [String]
}

enum CoachError: Error { case status(Int) }

/// Calls the personalized coach backend with the user's bearer token.
enum CoachService {
    static let endpoint = URL(string: "https://step-wise-life.lovable.app/api/public/coach")!

    static func call<T: Decodable>(_ body: [String: AnyJSON]) async throws -> T {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = try? await supabase.auth.session.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw CoachError.status(code) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Challenge editor

private struct ChallengeEditor: View {
    @EnvironmentObject var theme: Theme
    @State var spec: CoachChallengeSpec
    let onSave: (CoachChallengeSpec) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField(L.t("coach.suggested_challenge"), text: $spec.title) }
                Section(L.t("coach.target")) {
                    Text(L.t("coach.metric.\(spec.metric)")).foregroundStyle(theme.p.s600)
                    Stepper(spec.target.formatted(), value: $spec.target,
                            in: spec.metric == "goal_days" ? 1...14 : 1000...150000,
                            step: spec.metric == "goal_days" ? 1 : 500)
                }
                Section(L.t("coach.duration")) {
                    Stepper("\(spec.days)", value: $spec.days, in: 1...14)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L.t("coach.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("coach.accept")) {
                        if spec.metric == "goal_days" { spec.target = min(spec.target, spec.days) }
                        onSave(spec)
                    }
                }
            }
        }
    }
}

// MARK: - Preferences & privacy

struct CoachPreferencesView: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    var onCleared: () -> Void = {}

    @State private var goal = "balance"
    @State private var style = "supportive"
    @State private var target = ""
    @State private var prefs: [String] = []
    @State private var strategies: [CoachProfile.Strategy] = []
    @State private var confirmReset = false
    @State private var confirmClear = false
    @State private var status: String?

    private let goals = ["walk_more", "reduce_screen", "consistency", "balance"]
    private let styles = ["supportive", "direct", "analytical", "playful"]

    var body: some View {
        NavigationStack {
            Form {
                Section(L.t("coach.prefs.goal")) {
                    Picker(L.t("coach.prefs.goal"), selection: $goal) {
                        ForEach(goals, id: \.self) { Text(L.t("coach.goal.\($0)")).tag($0) }
                    }
                    .pickerStyle(.inline).labelsHidden()
                }
                Section(L.t("coach.prefs.style")) {
                    Picker(L.t("coach.prefs.style"), selection: $style) {
                        ForEach(styles, id: \.self) { Text(L.t("coach.style.\($0)")).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section(L.t("coach.prefs.target")) {
                    TextField(L.t("coach.prefs.target_ph"), text: $target)
                }
                Section { Button(L.t("coach.prefs.save")) { Task { await save() } } }
                Section(L.t("coach.prefs.memory")) {
                    if prefs.isEmpty { Text(L.t("coach.prefs.none")).foregroundStyle(theme.p.s500) }
                    ForEach(prefs, id: \.self) { Text($0).font(F.sm) }
                }
                if !strategies.isEmpty {
                    Section(L.t("coach.prefs.strategies")) {
                        ForEach(Array(strategies.enumerated()), id: \.offset) { i, s in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(s.text).font(F.sm)
                                HStack {
                                    feedback(i, true, s.useful == true, "hand.thumbsup")
                                    feedback(i, false, s.useful == false, "hand.thumbsdown")
                                }
                            }
                        }
                    }
                }
                Section(L.t("coach.prefs.data")) {
                    Text(L.t("coach.prefs.data_body")).font(F.xs).foregroundStyle(theme.p.s600)
                }
                Section {
                    Button(L.t("coach.prefs.reset"), role: .destructive) { confirmReset = true }
                    Button(L.t("coach.prefs.clear"), role: .destructive) { confirmClear = true }
                }
                if let status { Section { Text(status).font(F.xs).foregroundStyle(theme.p.s600) } }
            }
            .navigationTitle(L.t("coach.prefs"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.t("coach.prefs.done")) { dismiss() } } }
            .task { await load() }
            .confirmationDialog(L.t("coach.prefs.reset_confirm"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(L.t("coach.prefs.reset"), role: .destructive) { Task { await reset() } }
            }
            .confirmationDialog(L.t("coach.prefs.clear_confirm"), isPresented: $confirmClear, titleVisibility: .visible) {
                Button(L.t("coach.prefs.clear"), role: .destructive) { Task { await clear() } }
            }
        }
    }

    private func feedback(_ i: Int, _ useful: Bool, _ on: Bool, _ icon: String) -> some View {
        Button {
            Task {
                let _: CoachOK? = try? await CoachService.call(["action": "strategy_feedback", "index": .integer(i), "useful": .bool(useful)])
                await load()
            }
        } label: {
            Label(L.t(useful ? "coach.prefs.useful" : "coach.prefs.not_useful"), systemImage: on ? "\(icon).fill" : icon)
                .font(F.xs).foregroundStyle(on ? theme.p.s800 : theme.p.s500)
        }
        .buttonStyle(.borderless)
    }

    private func load() async {
        guard let s: CoachState = try? await CoachService.call(["action": "state", "lang": .string(L.lang)]) else { return }
        goal = s.profile.main_goal; style = s.profile.coaching_style; target = s.profile.personal_target
        prefs = s.profile.preferences; strategies = s.profile.strategies
    }

    private func save() async {
        do {
            let _: CoachOK = try await CoachService.call(["action": "save_profile", "main_goal": .string(goal),
                                                           "coaching_style": .string(style),
                                                           "personal_target": .string(String(target.prefix(200)))])
            status = L.t("coach.prefs.saved")
        } catch { status = L.t("coach.error") }
    }

    private func reset() async {
        do {
            let _: CoachOK = try await CoachService.call(["action": "reset_profile"])
            await load()
        } catch { status = L.t("coach.error") }
    }

    private func clear() async {
        do {
            let _: CoachOK = try await CoachService.call(["action": "clear_history"])
            onCleared()
        } catch { status = L.t("coach.error") }
    }
}
