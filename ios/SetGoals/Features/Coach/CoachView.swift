import SwiftUI

/// Port of `src/routes/coach.tsx` — PRO-locked AI coach chat.
struct CoachView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @Binding var tab: AppTab

    @State private var msgs: [CoachMessage] = []
    @State private var text = ""
    @State private var busy = false

    var body: some View {
        AppShell(tab: $tab) {
            PageHeader(eyebrow: L.t("coach.eyebrow"), title: L.t("coach.title")) {
                ZStack {
                    Circle().fill(theme.p.s600)
                    Image(systemName: "sparkles").font(.system(size: 18))
                        .foregroundStyle(theme.primaryForeground)
                }
                .frame(width: 40, height: 40)
            }
            if !settings.isPro {
                lockCard.padding(.horizontal, 24)
            } else {
                chat
            }
        }
        .task { if msgs.isEmpty { msgs = [CoachMessage(role: "assistant", content: L.t("coach.seed"))] } }
    }

    private var lockCard: some View {
        CardSurface(padding: 24) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: R.xl2, style: .continuous).fill(theme.p.s100)
                    Image(systemName: "sparkles").font(.system(size: 22)).foregroundStyle(theme.p.s700)
                }
                .frame(width: 48, height: 48)
                Text(L.t("coach.locked_title")).font(F.sans(16, .semibold)).foregroundStyle(theme.p.s950)
                Text(settings.role == "child" ? L.t("pro.child_desc") : L.t("coach.locked_desc"))
                    .font(F.sm).foregroundStyle(theme.p.s600).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var chat: some View {
        VStack(spacing: 12) {
            ForEach(msgs) { m in
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
            }
            if busy {
                HStack { ProgressView().tint(theme.p.s600); Spacer() }
            }
            suggestions
            composer
        }
        .padding(.horizontal, 24)
    }

    private var suggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(["coach.s1", "coach.s2", "coach.s3"], id: \.self) { key in
                    Button { Task { await send(L.t(key)) } } label: {
                        Text(L.t(key)).font(F.xs).foregroundStyle(theme.p.s700)
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

    private func send(_ raw: String) async {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !busy else { return }
        msgs.append(CoachMessage(role: "user", content: value))
        text = ""
        busy = true
        do {
            let reply = try await CoachService.chat(messages: msgs)
            msgs.append(CoachMessage(role: "assistant", content: reply))
        } catch {
            msgs.append(CoachMessage(role: "assistant", content: L.t("coach.error")))
        }
        busy = false
    }
}

struct CoachMessage: Identifiable, Codable {
    var id = UUID()
    let role: String
    let content: String
    enum CodingKeys: String, CodingKey { case role, content }
}

/// Calls the same AI coach backend the web app uses, exposed as a public
/// endpoint so the native client can reach it with the user's bearer token.
enum CoachService {
    static let endpoint = URL(string: "https://step-wise-life.lovable.app/api/public/coach")!

    static func chat(messages: [CoachMessage]) async throws -> String {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = try? await supabase.auth.session.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        struct Body: Encodable { let messages: [CoachMessage]; let lang: String }
        req.httpBody = try JSONEncoder().encode(Body(messages: messages, lang: L.lang))
        let (data, _) = try await URLSession.shared.data(for: req)
        struct Reply: Decodable { let reply: String }
        return try JSONDecoder().decode(Reply.self, from: data).reply
    }
}
