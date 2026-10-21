import SwiftUI

// MARK: - Inputs

struct OBField: View {
    @EnvironmentObject var theme: Theme
    let label: String
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default
    var content: UITextContentType? = nil
    var error: Bool = false
    @State private var reveal = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(F.sans(12, .semibold)).foregroundStyle(theme.p.s700)
            HStack {
                Group {
                    if secure && !reveal { SecureField("", text: $text) }
                    else { TextField("", text: $text) }
                }
                .focused($focused)
                .keyboardType(keyboard)
                .textContentType(content)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(F.base)
                if secure {
                    Button(reveal ? L.t("ob.hide") : L.t("ob.show")) { reveal.toggle() }
                        .font(F.sans(12, .semibold)).foregroundStyle(theme.p.s700)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                .strokeBorder(error ? theme.destructive : focused ? theme.primary : theme.ringBorder,
                              lineWidth: focused || error ? 1.5 : 1))
            .animation(.easeOut(duration: 0.15), value: focused)
        }
    }
}

struct Hint: View {
    @EnvironmentObject var theme: Theme
    let text: String
    let ok: Bool?
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: ok == true ? "checkmark.circle.fill" : ok == false ? "xmark.circle.fill" : "circle")
            Text(text)
        }
        .font(F.sans(12, .medium))
        .foregroundStyle(ok == true ? theme.p.s700 : ok == false ? theme.destructive : theme.p.s500)
    }
}

private struct ErrorText: View {
    @EnvironmentObject var theme: Theme
    let text: String?
    var body: some View {
        if let text {
            Text(text).font(F.sans(12, .medium)).foregroundStyle(theme.destructive)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
        }
    }
}

private struct AuthHeader: View {
    @EnvironmentObject var theme: Theme
    let icon: String
    var body: some View {
        Image(systemName: icon).font(.system(size: 30, weight: .semibold))
            .foregroundStyle(theme.primaryForeground)
            .frame(width: 72, height: 72)
            .background(theme.primary,
                        in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
    }
}

private func validEmail(_ s: String) -> Bool {
    s.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$"#, options: .regularExpression) != nil
}

// MARK: - Sign in

struct SignInScreen: View {
    let flow: OnboardingView
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @State private var tried = false

    var body: some View {
        SlideLayout(title: L.t("ob.signin.title"), subtitle: L.t("ob.signin.sub")) {
            AuthHeader(icon: "shoeprints.fill")
        } bodyContent: {
            VStack(spacing: 14) {
                OBField(label: L.t("ob.signup.email"), text: $email, keyboard: .emailAddress,
                        content: .username, error: tried && !validEmail(email))
                OBField(label: L.t("ob.signup.password"), text: $password, secure: true,
                        content: .password, error: tried && password.isEmpty)
                HStack {
                    Spacer()
                    OBTextButton(title: L.t("ob.forgot")) { flow.open(.forgot) }
                }
                ErrorText(text: error)
            }
        } footer: {
            OBPrimaryButton(title: busy ? L.t("ob.signin.busy") : L.t("ob.signin.cta"), busy: busy) {
                Task { await submit() }
            }
        }
    }

    private func submit() async {
        tried = true
        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard validEmail(e) else { error = L.t("ob.signup.email_bad"); return }
        guard !password.isEmpty else { return }
        busy = true; error = nil
        do {
            try await AuthStore.shared.signIn(email: e, password: password)
            flow.didAuthenticate(newAccount: false)
        } catch {
            withAnimation { self.error = L.t("ob.signin.failed") }
        }
        busy = false
    }
}

struct ForgotScreen: View {
    let flow: OnboardingView
    @State private var email = ""
    @State private var busy = false
    @State private var sent = false
    @State private var error: String?

    var body: some View {
        SlideLayout(title: L.t("ob.forgot.title"), subtitle: L.t("ob.forgot.sub")) {
            AuthHeader(icon: "key.fill")
        } bodyContent: {
            OBField(label: L.t("ob.signup.email"), text: $email, keyboard: .emailAddress, content: .emailAddress)
            ErrorText(text: error)
            if sent { NoteBox(text: L.t("ob.forgot.sent")) }
        } footer: {
            if sent {
                OBPrimaryButton(title: L.t("ob.signup.to_signin")) { flow.open(.signIn) }
            } else {
                OBPrimaryButton(title: L.t("ob.forgot.cta"), busy: busy) {
                    Task {
                        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
                        guard validEmail(e) else { error = L.t("ob.signup.email_bad"); return }
                        busy = true; error = nil
                        try? await AuthStore.shared.resetPassword(email: e)
                        busy = false
                        withAnimation { sent = true }
                    }
                }
            }
        }
    }
}

// MARK: - Account type

struct AccountTypeScreen: View {
    @EnvironmentObject var theme: Theme
    let flow: OnboardingView
    var body: some View {
        SlideLayout(title: L.t("ob.type.title"), subtitle: L.t("ob.type.sub")) {
            EmptyView()
        } bodyContent: {
            VStack(spacing: 12) {
                ChoiceCard(icon: "figure.and.child.holdinghands", title: L.t("ob.type.kid"),
                           desc: L.t("ob.type.kid_desc")) { flow.open(.child) }
                ChoiceCard(icon: "figure.walk.circle", title: L.t("ob.type.adult"),
                           desc: L.t("ob.type.adult_desc")) { flow.open(.signUp) }
                Text(L.t("ob.type.parent_note")).font(F.xs).foregroundStyle(theme.p.s600)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 4)
            }
        } footer: { EmptyView() }
    }
}

// MARK: - Child code

struct ChildCodeScreen: View {
    @EnvironmentObject var theme: Theme
    let flow: OnboardingView
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?
    @State private var success = false
    @State private var shake: CGFloat = 0
    @FocusState private var focused: Bool

    private let length = 8

    var body: some View {
        SlideLayout(title: L.t("ob.child.title"), subtitle: L.t("ob.child.sub")) {
            AuthHeader(icon: success ? "checkmark" : "person.2.fill")
                .contentTransition(.symbolEffect(.replace))
        } bodyContent: {
            VStack(spacing: 16) {
                ZStack {
                    // Hidden field drives the boxes: typing, autofill and paste all work.
                    TextField("", text: $code)
                        .focused($focused)
                        .textContentType(.oneTimeCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .opacity(0.02)
                        .onChange(of: code) { _, v in
                            let clean = String(v.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(length))
                            if clean != v { code = clean }
                            error = nil
                        }
                    HStack(spacing: 6) {
                        ForEach(0..<length, id: \.self) { i in
                            if i == 4 { Text("–").font(.title3).foregroundStyle(theme.p.s300) }
                            box(i)
                        }
                    }
                    .modifier(Shake(amount: shake))
                    .onTapGesture { focused = true }
                }
                Button {
                    if let s = UIPasteboard.general.string { code = s }
                } label: {
                    Label(L.t("ob.child.paste"), systemImage: "doc.on.clipboard")
                        .font(F.sans(12, .semibold)).foregroundStyle(theme.p.s700)
                }
                ErrorText(text: error)
                if success { StatusPill(text: L.t("ob.child.success")) }
            }
        } footer: {
            OBPrimaryButton(title: busy ? L.t("ob.child.busy") : L.t("ob.child.cta"),
                            busy: busy, enabled: code.count == length && !success) {
                Task { await connect() }
            }
        }
        .onAppear { focused = true }
        .sensoryFeedback(.success, trigger: success)
        .sensoryFeedback(.error, trigger: shake)
    }

    private func box(_ i: Int) -> some View {
        let chars = Array(code)
        let ch = i < chars.count ? String(chars[i]) : ""
        let active = focused && i == min(chars.count, length - 1)
        return Text(ch)
            .font(.system(.title2, design: .rounded, weight: .bold))
            .foregroundStyle(theme.p.s950)
            .frame(width: 34, height: 48)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(error != nil ? theme.destructive : active ? theme.primary : theme.ringBorder,
                              lineWidth: active || error != nil ? 2 : 1))
            .scaleEffect(ch.isEmpty ? 1 : 1.04)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: ch)
    }

    private func connect() async {
        busy = true; error = nil
        do {
            // Validated by the existing backend function; it returns the
            // child's sign-in only for a real, unused invitation code.
            let creds: [String: String] = try await supabase
                .rpc("redeem_child_code", params: ["_code": code]).execute().value
            guard let e = creds["email"], let p = creds["password"] else { throw URLError(.badServerResponse) }
            try await AuthStore.shared.signIn(email: e, password: p)
            withAnimation(.spring) { success = true }
            // Child devices authorize as `.child` so the parent stays the
            // moderator in Apple's Screen Time.
            await ScreenTimeService.shared.requestAuthorization(forChild: true)
            ScreenTimeService.shared.refreshFromStore()
            try? await Task.sleep(for: .seconds(1))
            flow.didAuthenticate(newAccount: false)
        } catch {
            withAnimation { self.error = L.t("ob.child.invalid") }
            withAnimation(.linear(duration: 0.4)) { shake += 1 }
        }
        busy = false
    }
}

private struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat { get { amount } set { amount = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 6), y: 0))
    }
}


// MARK: - Sign up

struct SignUpScreen: View {
    @EnvironmentObject var theme: Theme
    let flow: OnboardingView

    enum Avail { case idle, checking, available, taken }

    @State private var stage = 0
    @State private var displayName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var accepted = false
    @State private var avail: Avail = .idle
    @State private var busy = false
    @State private var error: String?
    @State private var legalDoc: LegalDoc?
    @State private var verifyEmail: String?

    private var usernameValid: Bool { username.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil }
    private var pwLong: Bool { password.count >= 8 }
    private var pwMatch: Bool { !confirm.isEmpty && confirm == password }

    var body: some View {
        Group {
            if let verifyEmail {
                SlideLayout(title: L.t("ob.signup.verify_title"),
                            subtitle: L.t("ob.signup.verify_sub", ["email": verifyEmail])) {
                    AuthHeader(icon: "envelope.open.fill")
                } bodyContent: { EmptyView() } footer: {
                    OBPrimaryButton(title: L.t("ob.signup.to_signin")) { flow.open(.signIn) }
                }
            } else {
                form
            }
        }
        .sheet(item: $legalDoc) { LegalDocSheet(doc: $0).environmentObject(theme) }
    }

    private var form: some View {
        SlideLayout(title: L.t("ob.signup.title"), subtitle: L.t("ob.signup.sub")) {
            AuthHeader(icon: "person.crop.circle.badge.plus")
        } bodyContent: {
            VStack(spacing: 14) {
                if stage == 0 {
                    OBField(label: L.t("ob.signup.name"), text: $displayName, content: .nickname)
                    OBField(label: L.t("ob.signup.username"), text: $username, content: .username,
                            error: avail == .taken)
                        .onChange(of: username) { _, v in
                            let clean = v.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            if clean != v { username = clean }
                        }
                        .task(id: username) { await checkUsername() }
                    HStack(spacing: 14) {
                        Hint(text: L.t("ob.signup.user_rule"), ok: username.isEmpty ? nil : usernameValid)
                        Spacer()
                        switch avail {
                        case .checking: Text(L.t("ob.signup.checking")).font(F.xs).foregroundStyle(theme.p.s500)
                        case .available: Hint(text: L.t("ob.signup.available"), ok: true)
                        case .taken: Hint(text: L.t("ob.signup.taken"), ok: false)
                        case .idle: EmptyView()
                        }
                    }
                } else {
                    OBField(label: L.t("ob.signup.email"), text: $email, keyboard: .emailAddress,
                            content: .emailAddress, error: !email.isEmpty && !validEmail(email))
                    OBField(label: L.t("ob.signup.password"), text: $password, secure: true, content: .newPassword)
                    OBField(label: L.t("ob.signup.confirm"), text: $confirm, secure: true, content: .newPassword,
                            error: !confirm.isEmpty && !pwMatch)
                    VStack(alignment: .leading, spacing: 6) {
                        Hint(text: L.t("ob.signup.pw_len"), ok: password.isEmpty ? nil : pwLong)
                        Hint(text: L.t("ob.signup.pw_match"), ok: confirm.isEmpty ? nil : pwMatch)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    acceptRow
                }
                ErrorText(text: error)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: stage)
        } footer: {
            if stage == 0 {
                OBPrimaryButton(title: L.t("ob.signup.next"),
                                enabled: !displayName.trimmingCharacters(in: .whitespaces).isEmpty
                                    && usernameValid && avail == .available) {
                    error = nil
                    withAnimation { stage = 1 }
                }
            } else {
                OBPrimaryButton(title: busy ? L.t("ob.signup.busy") : L.t("ob.signup.cta"), busy: busy,
                                enabled: validEmail(email) && pwLong && pwMatch && accepted) {
                    Task { await submit() }
                }
                OBTextButton(title: L.t("ob.back")) { withAnimation { stage = 0 } }
            }
        }
    }

    private var acceptRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { accepted.toggle() } label: {
                Image(systemName: accepted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24))
                    .foregroundStyle(accepted ? theme.primary : theme.p.s300)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L.t("ob.signup.agree"))
            .accessibilityAddTraits(accepted ? .isSelected : [])

            VStack(alignment: .leading, spacing: 4) {
                Text(L.t("ob.signup.agree")).font(F.xs).foregroundStyle(theme.p.s700)
                HStack(spacing: 6) {
                    Button(L.t("auth.accept_terms")) { legalDoc = .terms }
                        .font(F.sans(12, .semibold)).foregroundStyle(theme.p.s900).underline()
                    Text(L.t("ob.signup.and")).font(F.xs).foregroundStyle(theme.p.s700)
                    Button(L.t("auth.accept_privacy")) { legalDoc = .privacy }
                        .font(F.sans(12, .semibold)).foregroundStyle(theme.p.s900).underline()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous).strokeBorder(theme.ringBorder, lineWidth: 1))
        .sensoryFeedback(.selection, trigger: accepted)
    }

    private func checkUsername() async {
        guard usernameValid else { avail = .idle; return }
        avail = .checking
        try? await Task.sleep(for: .milliseconds(400))   // debounce
        guard !Task.isCancelled else { return }
        let ok = (try? await SupabaseAPI.usernameAvailable(username)) ?? false
        guard !Task.isCancelled else { return }
        withAnimation { avail = ok ? .available : .taken }
    }

    private func submit() async {
        guard accepted else { error = L.t("ob.signup.accept_req"); return }
        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
        busy = true; error = nil
        do {
            // Re-check right before creating, in case it was just taken.
            guard try await SupabaseAPI.usernameAvailable(username) else {
                avail = .taken; stage = 0; busy = false; return
            }
            let signedIn = try await AuthStore.shared.signUp(
                email: e, password: password,
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                username: username, birthday: nil, termsAcceptedAt: Date())
            if signedIn { flow.didAuthenticate(newAccount: true) }
            else { withAnimation { verifyEmail = e } }
        } catch {
            withAnimation { self.error = error.localizedDescription }
        }
        busy = false
    }
}

// MARK: - Celebration

struct CelebrateScreen: View {
    @EnvironmentObject var theme: Theme
    @State private var go = 0
    var body: some View {
        VStack(spacing: 20) {
            FinishArt().padding(.horizontal, 24)
            Text(L.t("ob.done.title")).font(F.xl3).foregroundStyle(theme.p.s950)
            Text(L.t("ob.done.sub")).font(F.base).foregroundStyle(theme.p.s600)
        }
        .multilineTextAlignment(.center)
        .onAppear { go += 1 }
        .sensoryFeedback(.success, trigger: go)
    }
}
