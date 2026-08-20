import SwiftUI

/// Port of `src/routes/auth.tsx` — sign in / sign up / forgot / join with code.
struct AuthView: View {
    enum Mode { case signin, signup, forgot, join }

    @EnvironmentObject var theme: Theme
    @State private var mode: Mode = .signin

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if mode != .signin {
                        Button { mode = .signin } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.left").font(.system(size: 12))
                                Text(L.t("auth.back")).font(F.sans(12, .medium))
                            }
                            .foregroundStyle(theme.p.s700)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(theme.card, in: Capsule())
                            .overlay(Capsule().strokeBorder(theme.ringBorder, lineWidth: 1))
                        }
                        .padding(.bottom, 16)
                    }

                    Text("SetGoals")
                        .font(F.sans(10, .semibold)).textCase(.uppercase).tracking(1.5)
                        .foregroundStyle(theme.p.s700)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(theme.p.s100, in: Capsule())

                    Text(title).font(F.xl3).tracking(-0.5).padding(.top, 8)
                    Text(subtitle).font(F.sm).foregroundStyle(theme.p.s600).padding(.top, 8)

                    Group {
                        switch mode {
                        case .signin: SignInForm(mode: $mode)
                        case .signup: SignUpForm(mode: $mode)
                        case .forgot: ForgotForm(mode: $mode)
                        case .join: JoinForm()
                        }
                    }
                    .padding(.top, 32)
                }
                .frame(maxWidth: 448, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
        }
    }

    private var title: String {
        switch mode {
        case .signin: return L.t("auth.welcome")
        case .signup: return L.t("auth.create")
        case .join: return L.t("auth.join_title")
        case .forgot: return L.t("auth.forgot_title")
        }
    }
    private var subtitle: String {
        switch mode {
        case .signin: return L.t("auth.sub_signin")
        case .signup: return L.t("auth.sub_signup")
        case .join: return L.t("auth.join_sub")
        case .forgot: return L.t("auth.forgot_sub")
        }
    }
}

private struct SignInForm: View {
    @EnvironmentObject var theme: Theme
    @Binding var mode: AuthView.Mode
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 12) {
            TextField(L.t("auth.email"), text: $email)
                .keyboardType(.emailAddress).textInputAutocapitalization(.never).fieldStyle()
            SecureField(L.t("auth.password"), text: $password).fieldStyle()

            HStack {
                Spacer()
                Button(L.t("auth.forgot")) { mode = .forgot }
                    .font(F.sans(12, .medium)).foregroundStyle(theme.p.s700)
            }

            if let error { Text(error).font(F.xs).foregroundStyle(theme.destructive) }

            PrimaryButton(title: busy ? L.t("auth.signing_in") : L.t("auth.signin"), busy: busy) {
                Task {
                    busy = true; error = nil
                    do { try await AuthStore.shared.signIn(email: email, password: password) }
                    catch { self.error = error.localizedDescription }
                    busy = false
                }
            }
            .padding(.top, 8)

            SocialButtons()

            Button { mode = .join } label: {
                Text(L.t("auth.join_code"))
                    .font(F.sans(14, .semibold)).foregroundStyle(theme.p.s900)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(theme.p.s100, in: Capsule())
                    .overlay(Capsule().strokeBorder(theme.p.s200, lineWidth: 1))
            }

            HStack(spacing: 4) {
                Text(L.t("auth.no_account")).font(F.xs).foregroundStyle(theme.p.s600)
                Button(L.t("auth.create_one")) { mode = .signup }
                    .font(F.sans(12, .semibold)).foregroundStyle(theme.p.s900)
            }
            .padding(.top, 24)
        }
    }
}

private struct SignUpForm: View {
    @EnvironmentObject var theme: Theme
    @Binding var mode: AuthView.Mode
    @State private var email = "", password = "", displayName = "", username = "", birthday = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 12) {
            TextField(L.t("auth.display_name"), text: $displayName).fieldStyle()
            TextField(L.t("auth.username_ph"), text: $username)
                .textInputAutocapitalization(.never)
                .onChange(of: username) { _, v in
                    username = v.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                }
                .fieldStyle()
            TextField(L.t("auth.email"), text: $email)
                .keyboardType(.emailAddress).textInputAutocapitalization(.never).fieldStyle()
            SecureField(L.t("auth.password_min"), text: $password).fieldStyle()

            VStack(alignment: .leading, spacing: 6) {
                Text(L.t("auth.birthday")).eyebrow(theme.p.s600).padding(.leading, 4)
                TextField("YYYY-MM-DD", text: $birthday).fieldStyle()
            }

            if let error { Text(error).font(F.xs).foregroundStyle(theme.destructive) }

            PrimaryButton(title: busy ? L.t("auth.creating") : L.t("auth.create_btn"), busy: busy) {
                Task { await submit() }
            }
            .padding(.top, 8)

            SocialButtons()
        }
    }

    private func submit() async {
        guard password.count >= 8 else { error = L.t("auth.password_short"); return }
        guard username.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil else {
            error = L.t("auth.username_invalid"); return
        }
        busy = true; error = nil
        do {
            guard try await SupabaseAPI.usernameAvailable(username) else {
                error = L.t("auth.username_taken"); busy = false; return
            }
            try await AuthStore.shared.signUp(
                email: email, password: password, displayName: displayName,
                username: username, birthday: birthday.isEmpty ? nil : birthday
            )
            mode = .signin
        } catch { self.error = error.localizedDescription }
        busy = false
    }
}

private struct ForgotForm: View {
    @EnvironmentObject var theme: Theme
    @Binding var mode: AuthView.Mode
    @State private var email = ""
    @State private var busy = false

    var body: some View {
        VStack(spacing: 12) {
            TextField(L.t("auth.email"), text: $email)
                .keyboardType(.emailAddress).textInputAutocapitalization(.never).fieldStyle()
            PrimaryButton(title: busy ? L.t("auth.sending") : L.t("auth.send_reset"), busy: busy) {
                Task {
                    busy = true
                    try? await AuthStore.shared.resetPassword(email: email)
                    busy = false
                    mode = .signin
                }
            }
            .padding(.top, 8)
        }
    }
}

/// "Join with code" — 8-char XXXX-XXXX child invitation code.
private struct JoinForm: View {
    @EnvironmentObject var theme: Theme
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 12) {
            TextField("A7K9-PQ42", text: $code)
                .multilineTextAlignment(.center)
                .font(F.sans(18, .semibold))
                .tracking(4.8)
                .textInputAutocapitalization(.characters)
                .onChange(of: code) { _, v in
                    let raw = String(v.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
                    code = raw.count > 4 ? "\(raw.prefix(4))-\(raw.dropFirst(4))" : raw
                }
                .fieldStyle()

            if let error { Text(error).font(F.xs).foregroundStyle(theme.destructive) }

            PrimaryButton(title: busy ? L.t("auth.joining") : L.t("auth.join_cta"), busy: busy) {
                Task {
                    let clean = code.filter { $0.isLetter || $0.isNumber }
                    guard clean.count == 8 else { error = L.t("auth.code_len_error"); return }
                    busy = true; error = nil
                    do {
                        // Mirrors the `redeemChildCode` server function: returns
                        // the generated child credentials, then signs in.
                        let creds: [String: String] = try await supabase
                            .rpc("redeem_child_code", params: ["_code": clean]).execute().value
                        if let e = creds["email"], let p = creds["password"] {
                            try await AuthStore.shared.signIn(email: e, password: p)
                        }
                    } catch { self.error = L.t("auth.code_failed") }
                    busy = false
                }
            }
            .padding(.top, 8)
        }
    }
}

private struct SocialButtons: View {
    @EnvironmentObject var theme: Theme
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Rectangle().fill(theme.p.s200).frame(height: 1)
                Text(L.t("auth.or")).eyebrow(theme.p.s600).fixedSize()
                Rectangle().fill(theme.p.s200).frame(height: 1)
            }
            .padding(.vertical, 24)

            Button { run { try await OAuthService.shared.signInWithGoogle() } } label: {
                Text(L.t("auth.google"))
                    .font(F.sans(14, .semibold)).foregroundStyle(theme.p.s900)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(theme.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(theme.ringBorder, lineWidth: 1))
            }
            .disabled(busy)
            Button { run { try await OAuthService.shared.signInWithApple() } } label: {
                Text(L.t("auth.apple"))
                    .font(F.sans(14, .semibold)).foregroundStyle(theme.p.s50)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(theme.p.s950, in: Capsule())
            }
            .disabled(busy)

            if let error {
                Text(error).font(F.sans(12, .medium)).foregroundStyle(.red)
                    .padding(.top, 8)
            }
        }
    }

    private func run(_ op: @escaping () async throws -> Void) {
        guard !busy else { return }
        busy = true
        error = nil
        Task { @MainActor in
            do { try await op() }
            catch is CancellationError {}
            catch let err as ASWebAuthenticationSessionError where err.code == .canceledLogin {}
            catch let err as NSError where err.domain == ASAuthorizationError.errorDomain
                && err.code == ASAuthorizationError.canceled.rawValue {}
            catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}

