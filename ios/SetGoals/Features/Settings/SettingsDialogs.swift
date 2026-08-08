import SwiftUI
import UIKit
import Supabase

/// Port of the shadcn `Dialog` used across the web app:
/// centered card, `rounded-3xl`, title + description + body + footer.
struct AppDialog<Content: View, Footer: View>: View {
    @EnvironmentObject var theme: Theme
    let title: String
    var titleColor: Color? = nil
    var description: String? = nil
    var centered: Bool = false
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 16) {
            VStack(alignment: centered ? .center : .leading, spacing: 6) {
                Text(title)
                    .font(F.sans(18, .semibold))
                    .foregroundStyle(titleColor ?? theme.p.s950)
                    .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                if let description {
                    Text(description).font(F.sm).foregroundStyle(theme.p.s600)
                        .multilineTextAlignment(centered ? .center : .leading)
                        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                }
            }
            content
            footer
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.card)
        .presentationCornerRadius(R.xl3)
        .presentationBackground(theme.card)
    }
}

/// `Button variant="ghost"` — the cancel action in every dialog footer.
struct GhostButton: View {
    @EnvironmentObject var theme: Theme
    let title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(F.sans(14, .semibold)).foregroundStyle(theme.p.s700)
                .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }
}

/// Footer with the ghost/primary pair the web dialogs use.
struct DialogFooterButtons: View {
    let cancelTitle: String
    let confirmTitle: String
    var destructive = false
    var disabled = false
    var busy = false
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @EnvironmentObject var theme: Theme

    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            GhostButton(title: cancelTitle, action: onCancel)
            Button(action: onConfirm) {
                Text(confirmTitle)
                    .font(F.sans(14, .semibold))
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .foregroundStyle(theme.primaryForeground)
                    .background(destructive ? theme.destructive : theme.primary, in: Capsule())
            }
            .disabled(disabled || busy)
            .opacity(disabled || busy ? 0.5 : 1)
        }
    }
}

// MARK: - Slider dialog (steps per 30 min, daily cap, daily goal)

struct SliderDialog: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let title: String
    let initial: Int
    let min: Int
    let max: Int
    let step: Int
    var unit: String = ""
    /// `unlimited` mirrors the web "no cap" sentinel (24 h).
    var unlimited: (sentinel: Int, label: String)? = nil
    let onSave: (Int) -> Void

    @State private var local: Double = 0

    private var sliderMax: Double { Double(unlimited == nil ? max : max + step) }
    private var isUnlimited: Bool {
        if let u = unlimited { return Int(local.rounded()) >= u.sentinel }
        return false
    }

    var body: some View {
        AppDialog(title: title) {
            VStack(spacing: 24) {
                Group {
                    if isUnlimited, let u = unlimited {
                        Text(u.label).font(F.sans(36, .semibold))
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(Int(local.rounded()).formatted(.number.grouping(.automatic)))
                                .font(F.sans(36, .semibold)).tabularNums()
                            if !unit.isEmpty {
                                Text(unit).font(F.sans(16, .medium)).foregroundStyle(theme.p.s600)
                            }
                        }
                    }
                }
                .foregroundStyle(theme.p.s700)
                .frame(maxWidth: .infinity)

                Slider(value: $local, in: Double(min)...sliderMax, step: Double(step))
                    .tint(theme.primary)

                HStack {
                    Text("\(min.formatted())\(unit)")
                    Spacer()
                    Text(unlimited?.label ?? "\(max.formatted())\(unit)")
                }
                .font(F.text11).tabularNums().foregroundStyle(theme.p.s600)
            }
            .padding(.vertical, 4)
        } footer: {
            DialogFooterButtons(cancelTitle: L.t("settings.cancel"),
                                confirmTitle: L.t("settings.save")) {
                dismiss()
            } onConfirm: {
                var v = Int(local.rounded())
                if let u = unlimited, v >= Int(sliderMax) { v = u.sentinel }
                onSave(v)
                dismiss()
            }
        }
        .onAppear {
            if let u = unlimited, initial >= u.sentinel { local = sliderMax }
            else { local = Double(initial) }
        }
        .presentationDetents([.height(360)])
    }
}

// MARK: - Theme picker

struct ThemePickerDialog: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    private let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        AppDialog(title: L.t("theme.title"), description: L.t("theme.desc")) {
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(ThemeColor.allCases) { c in
                    let active = settings.themeColor == c
                    Button {
                        settings.themeColor = c
                        theme.color = c
                        Task { try? await SupabaseAPI.updateSettings(["theme_color": .string(c.rawValue)]) }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle().fill(SagePalette.table[c]!.s600)
                                Circle().strokeBorder(.white, lineWidth: 2)
                                if active {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 40, height: 40)
                            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                            Text(L.t("theme.\(c.rawValue)")).font(F.sans(12, .medium))
                                .foregroundStyle(theme.p.s900)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(active ? theme.p.s50 : theme.card,
                                    in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                            .strokeBorder(active ? theme.p.s700.opacity(0.4) : Color.black.opacity(0.1),
                                          lineWidth: 1))
                    }
                }
            }
            .padding(.vertical, 4)
        } footer: { EmptyView() }
        .presentationDetents([.height(420)])
    }
}

// MARK: - Health connect dialog

struct HealthConnectDialog: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    /// "hk" or "gf"
    let kind: String
    let onConnected: () -> Void

    @State private var busy = false
    @State private var note: String?

    var body: some View {
        AppDialog(title: L.t(kind == "hk" ? "hk.title" : "gf.title"),
                  description: L.t(kind == "hk" ? "hk.desc" : "gf.desc")) {
            VStack(alignment: .leading, spacing: 8) {
                scope("settings.scope.steps")
                scope("settings.scope.distance")
                scope("settings.scope.energy")
                if let note {
                    Text(note).font(F.xs).foregroundStyle(theme.mutedForeground)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.muted, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                }
            }
        } footer: {
            DialogFooterButtons(cancelTitle: L.t("settings.cancel"),
                                confirmTitle: busy ? L.t("health.waiting") : L.t("hk.allow"),
                                busy: busy) {
                dismiss()
            } onConfirm: {
                Task { await connect() }
            }
        }
        .onAppear {
            if kind == "gf" { note = L.t("health.android_only") }
            else if !HealthKitService.shared.isAvailable { note = L.t("health.needs_ios_app") }
        }
        .presentationDetents([.height(340)])
    }

    private func scope(_ key: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark").font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.p.s600)
            Text(L.t(key)).font(F.sm).foregroundStyle(theme.p.s700)
        }
    }

    private func connect() async {
        guard kind == "hk" else { note = L.t("health.android_only"); return }
        busy = true
        await HealthKitService.shared.requestAuthorization()
        busy = false
        if HealthKitService.shared.authorized {
            onConnected()
            dismiss()
        } else {
            note = L.t("health.denied")
        }
    }
}

// MARK: - Report a problem

struct ReportProblemDialog: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        AppDialog(title: L.t("report.title"), description: L.t("report.desc")) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(L.t("report.placeholder")).font(F.sm)
                        .foregroundStyle(theme.p.s600).padding(12)
                }
                TextEditor(text: $text)
                    .font(F.sm).frame(height: 120).scrollContentBackground(.hidden).padding(6)
            }
            .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                .strokeBorder(theme.ringBorder, lineWidth: 1))
        } footer: {
            DialogFooterButtons(cancelTitle: L.t("settings.cancel"),
                                confirmTitle: L.t("report.send"),
                                disabled: text.trimmingCharacters(in: .whitespaces).isEmpty) {
                dismiss()
            } onConfirm: {
                let body = text.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
                if let url = URL(string: "mailto:support@setgoals.app?subject=Problem%20report&body=\(body)") {
                    UIApplication.shared.open(url)
                }
                Task { await SupabaseAPI.awardBadge("problem_solver") }
                dismiss()
            }
        }
        .presentationDetents([.height(360)])
    }
}

// MARK: - Delete account

struct DeleteAccountDialog: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        AppDialog(title: L.t("delete.title"), titleColor: theme.destructive,
                  description: L.t("delete.desc")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("delete.password")).font(F.xs).foregroundStyle(theme.p.s600)
                SecureField("", text: $password).textContentType(.password).fieldStyle()
                if let error {
                    Text(error).font(F.xs).foregroundStyle(theme.destructive)
                }
            }
        } footer: {
            DialogFooterButtons(cancelTitle: L.t("settings.cancel"),
                                confirmTitle: L.t("delete.confirm"),
                                destructive: true,
                                disabled: password.isEmpty, busy: busy) {
                dismiss()
            } onConfirm: {
                Task { await deleteAccount() }
            }
        }
        .presentationDetents([.height(330)])
    }

    private func deleteAccount() async {
        busy = true
        error = nil
        defer { busy = false }
        guard let email = try? await supabase.auth.user().email else { return }
        do {
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            self.error = L.t("delete.wrong_password")
            return
        }
        if let uid = await SupabaseAPI.currentUserID() {
            try? await supabase.from("account_deletion_requests")
                .insert(["user_id": AnyJSON.string(uid.uuidString)]).execute()
            try? await supabase.from("profiles").delete().eq("id", value: uid).execute()
        }
        await AuthStore.shared.signOut()
        dismiss()
    }
}

// MARK: - Account field dialogs

struct NicknameDialog: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let current: String
    let onSave: (String) -> Void
    @State private var val = ""

    var body: some View {
        AppDialog(title: L.t("account.nickname.title"), description: L.t("account.nickname.desc")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("settings.nickname")).font(F.xs).foregroundStyle(theme.p.s600)
                TextField(L.t("account.nickname.placeholder"), text: $val).fieldStyle()
            }
        } footer: {
            DialogFooterButtons(cancelTitle: L.t("settings.cancel"),
                                confirmTitle: L.t("settings.save"),
                                disabled: val.trimmingCharacters(in: .whitespaces).isEmpty) {
                dismiss()
            } onConfirm: {
                onSave(String(val.trimmingCharacters(in: .whitespaces).prefix(40)))
                dismiss()
            }
        }
        .onAppear { val = current }
        .presentationDetents([.height(280)])
    }
}

struct UsernameDialog: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let current: String
    let onSave: (String) -> Void
    @State private var val = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        AppDialog(title: L.t("account.username.title"), description: L.t("account.username.desc")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("settings.username")).font(F.xs).foregroundStyle(theme.p.s600)
                TextField(L.t("account.username.placeholder"), text: $val)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .onChange(of: val) { _, new in
                        val = String(new.filter { $0.isLetter || $0.isNumber || $0 == "_" }.prefix(20))
                        error = nil
                    }
                    .fieldStyle()
                if let error { Text(error).font(F.xs).foregroundStyle(theme.destructive) }
            }
        } footer: {
            DialogFooterButtons(cancelTitle: L.t("settings.cancel"),
                                confirmTitle: L.t("settings.save"),
                                disabled: val.isEmpty, busy: busy) {
                dismiss()
            } onConfirm: {
                Task { await submit() }
            }
        }
        .onAppear { val = current }
        .presentationDetents([.height(300)])
    }

    private func submit() async {
        let v = val.trimmingCharacters(in: .whitespaces).lowercased()
        guard v.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil else {
            error = L.t("account.username.invalid"); return
        }
        if v == current.lowercased() { dismiss(); return }
        busy = true
        let free = (try? await SupabaseAPI.usernameAvailable(v)) ?? false
        busy = false
        guard free else { error = L.t("account.username.taken"); return }
        onSave(v)
        dismiss()
    }
}

struct EmailDialog: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let current: String
    let onSave: (String) async -> String?
    @State private var val = ""
    @State private var error: String?
    @State private var busy = false

    private var isEmail: Bool {
        val.trimmingCharacters(in: .whitespaces)
            .range(of: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", options: .regularExpression) != nil
    }

    var body: some View {
        AppDialog(title: L.t("account.email.title"), description: L.t("account.email.desc")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("settings.email")).font(F.xs).foregroundStyle(theme.p.s600)
                TextField(L.t("account.email.placeholder"), text: $val)
                    .keyboardType(.emailAddress).textContentType(.emailAddress)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .onChange(of: val) { _, _ in error = nil }
                    .fieldStyle()
                if let error { Text(error).font(F.xs).foregroundStyle(theme.destructive) }
            }
        } footer: {
            DialogFooterButtons(cancelTitle: L.t("settings.cancel"),
                                confirmTitle: L.t("settings.save"),
                                disabled: !isEmail, busy: busy) {
                dismiss()
            } onConfirm: {
                busy = true
                Task {
                    let err = await onSave(val.trimmingCharacters(in: .whitespaces))
                    busy = false
                    if let err { error = err } else { dismiss() }
                }
            }
        }
        .onAppear { val = current }
        .presentationDetents([.height(300)])
    }
}

struct PasswordDialog: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let onSave: (String) async -> String?
    @State private var cur = ""
    @State private var next = ""
    @State private var confirm = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        AppDialog(title: L.t("account.password.title"), description: L.t("account.password.desc")) {
            VStack(alignment: .leading, spacing: 12) {
                field(L.t("account.password.current"), $cur)
                field(L.t("account.password.new"), $next)
                field(L.t("account.password.confirm"), $confirm)
                if let error { Text(error).font(F.xs).foregroundStyle(theme.destructive) }
            }
        } footer: {
            DialogFooterButtons(cancelTitle: L.t("settings.cancel"),
                                confirmTitle: L.t("settings.save"),
                                disabled: cur.isEmpty || next.isEmpty || confirm.isEmpty,
                                busy: busy) {
                dismiss()
            } onConfirm: {
                Task { await submit() }
            }
        }
        .presentationDetents([.height(440)])
    }

    private func field(_ label: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(F.xs).foregroundStyle(theme.p.s600)
            SecureField("", text: binding)
                .onChange(of: binding.wrappedValue) { _, _ in error = nil }
                .fieldStyle()
        }
    }

    private func submit() async {
        if next.count < 8 { error = L.t("account.password.short"); return }
        if next != confirm { error = L.t("account.password.mismatch"); return }
        busy = true
        // Re-authenticate first so a wrong current password is caught, exactly
        // like the web dialog does before calling updateUser.
        if let email = try? await supabase.auth.user().email {
            do { try await supabase.auth.signIn(email: email, password: cur) }
            catch { busy = false; error = L.t("account.password.wrong"); return }
        }
        let err = await onSave(next)
        busy = false
        if let err { error = err } else { dismiss() }
    }
}
