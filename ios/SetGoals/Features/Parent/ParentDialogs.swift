import SwiftUI
import PhotosUI
import UIKit
import Supabase

/// Emoji options for a child avatar — same list as `CHILD_EMOJIS` on web.
enum ChildEmojis {
    static let all = ["🌱", "🐻", "🦊", "🐼", "🦁", "🐸", "🦄", "⭐️", "🚀"]
}

// MARK: - Screen time rules dialog (`ScreenTimeDialog` on web)

struct ParentScreenTimeDialog: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pst = ProSTStore.shared
    let title: String
    let stepsPer30: Int
    let dailyCapHours: Int
    let onSave: (Int, Int) -> Void

    @State private var steps: Double = 1000
    @State private var cap: Double = 3

    private var capHours: Int { Int(cap.rounded()) >= 9 ? 24 : Int(cap.rounded()) }

    var body: some View {
        AppDialog(
            title: title,
            description: L.t("parent.rules_sub", [
                "steps": Int(steps.rounded()).formatted(),
                "cap": capHours >= 24 ? "∞" : "\(capHours)",
                "carry": L.t(pst.rollover ? "parent.rules_carry_on" : "parent.rules_carry_off"),
            ])
        ) {
            VStack(spacing: 24) {
                SliderRow(title: L.t("parent.steps_per_30"),
                          valueLabel: Int(steps.rounded()).formatted(),
                          value: $steps, range: 200...3000, step: 100)
                SliderRow(title: L.t("parent.daily_cap"),
                          valueLabel: capHours >= 24 ? L.t("parent.no_cap") : "\(capHours)\(L.t("settings.hours"))",
                          value: $cap, range: 1...9, step: 1)
                if pst.rollover {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles").font(.system(size: 13)).foregroundStyle(theme.p.s700)
                        Text(L.t("parent.rollover_on")).font(F.xs).foregroundStyle(theme.p.s700)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                        .stroke(theme.p.s200, lineWidth: 1))
                }
            }
        } footer: {
            DialogFooterButtons(cancelTitle: L.t("settings.cancel"),
                                confirmTitle: L.t("settings.save"),
                                onCancel: { dismiss() },
                                onConfirm: {
                                    onSave(Int(steps.rounded()), capHours)
                                    dismiss()
                                })
        }
        .onAppear {
            steps = Double(stepsPer30)
            cap = Double(dailyCapHours >= 24 ? 9 : dailyCapHours)
        }
        .presentationDetents([.height(pst.rollover ? 480 : 400)])
    }
}

// MARK: - Child create / edit dialog

struct ChildEditDialog: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let child: ChildRow?
    let isNew: Bool
    let existing: [ChildRow]
    let onDone: () async -> Void

    @State private var name = ""
    @State private var username = ""
    @State private var birthday = ""
    @State private var avatar = ChildEmojis.all[0]
    @State private var dailyGoal: Double = 8000
    @State private var stepsPer30: Double = 1000
    @State private var capHours: Double = 3
    @State private var code = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var uploading = false
    @State private var saving = false
    @State private var error: String?
    @State private var showEmojis = false
    @State private var usernameAvailable = false
    @State private var checkedUsername = ""
    @State private var checkingUsername = false
    @State private var usernameError: String?

    private var unchangedUsername: Bool {
        guard let child else { return false }
        return UsernameRules.normalize(username) == UsernameRules.normalize(child.username ?? "")
    }

    private var canSave: Bool {
        !uploading && !saving && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (unchangedUsername || (UsernameRules.isValid(username) && usernameAvailable
                && checkedUsername == UsernameRules.normalize(username)))
    }

    var body: some View {
        ScrollView {
            AppDialog(title: isNew ? L.t("parent.child.new") : L.t("parent.child.edit"),
                      description: L.t(isNew ? "dashboard.child_create_sub" : "dashboard.child_edit_sub")) {
                VStack(alignment: .leading, spacing: 24) {
                    formHeading(L.t("dashboard.child_profile"), icon: "person.crop.circle")
                    avatarPicker

                    field(L.t("auth.name")) {
                        TextField("", text: $name).textContentType(.name).textInputAutocapitalization(.words).fieldStyle()
                    }

                    field(L.t("settings.username")) {
                        HStack(spacing: 6) {
                            Text("@").font(F.sm).foregroundStyle(theme.p.s600)
                            TextField(L.t("dashboard.username_placeholder"), text: $username)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(F.sm)
                        }
                        .fieldStyle()
                        if checkingUsername {
                            Text(L.t("ob.signup.checking")).font(F.xs).foregroundStyle(theme.mutedForeground)
                        } else if let usernameError {
                            Text(usernameError).font(F.xs).foregroundStyle(theme.destructive)
                        }
                    }

                    field(L.t("auth.birthday")) {
                        DatePicker("", selection: birthdayBinding, displayedComponents: .date)
                            .labelsHidden()
                            .font(F.sm).tint(theme.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider().overlay(theme.border)
                    formHeading(L.t("dashboard.child_rules"), icon: "slider.horizontal.3")
                    SliderRow(title: L.t("parent.child.daily_goal"),
                              valueLabel: Int(dailyGoal).formatted(),
                              value: $dailyGoal, range: 2000...20000, step: 500)
                    SliderRow(title: L.t("parent.steps_per_30"),
                              valueLabel: Int(stepsPer30).formatted(),
                              value: $stepsPer30, range: 200...3000, step: 100)
                    SliderRow(title: L.t("parent.daily_cap"),
                              valueLabel: "\(Int(capHours))\(L.t("settings.hours"))",
                              value: $capHours, range: 1...8, step: 1)

                    if !isNew && !code.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.t("parent.child.code"))
                                .font(F.xs).foregroundStyle(theme.mutedForeground)
                            Text(code).font(F.sans(24, .semibold)).monospacedDigit()
                                .foregroundStyle(theme.foreground)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(theme.secondary, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                    }

                    if let error {
                        Text(error).font(F.xs).foregroundStyle(theme.destructive)
                    }
                }
            } footer: { EmptyView() }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                PrimaryButton(title: saving ? L.t("parent.child.saving") : L.t(isNew ? "parent.add_child" : "parent.child.save"),
                              busy: saving, enabled: canSave) { Task { await save() } }
                GhostButton(title: L.t("settings.cancel")) { dismiss() }.buttonStyle(FlatPress())
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            .background(theme.card)
            .overlay(alignment: .top) { Divider().overlay(theme.border) }
        }
        .background(theme.card)
        .presentationCornerRadius(R.xl3)
        .presentationDetents([.large])
        .onAppear(perform: seed)
        .task(id: username) { await checkUsername() }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await pick(item) }
        }
    }

    private var avatarPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t("parent.child.avatar")).font(F.sm).foregroundStyle(theme.foreground)
            HStack(alignment: .top, spacing: 12) {
                AvatarBubble(avatar: avatar, name: name, size: 56)
                VStack(alignment: .leading, spacing: 8) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(uploading ? L.t("parent.child.uploading") : L.t("parent.child.upload_photo"), systemImage: "photo")
                        .font(F.sans(14, .semibold)).foregroundStyle(theme.p.s900)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(theme.secondary, in: Capsule())
                        .overlay(Capsule().strokeBorder(theme.p.s200, lineWidth: 1))
                }
                .buttonStyle(FlatPress()).disabled(uploading)
                if avatar.hasPrefix("data:") || avatar.hasPrefix("http") {
                    Button { avatar = ChildEmojis.all[0] } label: {
                        Image(systemName: "trash").font(.system(size: 14))
                            .foregroundStyle(theme.mutedForeground).frame(width: 44, height: 44)
                    }
                    .buttonStyle(FlatPress()).accessibilityLabel(L.t("parent.child.remove_photo"))
                }
                }
                Spacer(minLength: 0)
            }
            DisclosureGroup(isExpanded: $showEmojis) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(ChildEmojis.all, id: \.self) { e in
                    Button { avatar = e } label: {
                        Text(e).font(.system(size: 22))
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(avatar == e ? theme.primary.opacity(0.15) : theme.p.s50,
                                        in: RoundedRectangle(cornerRadius: R.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: R.md, style: .continuous)
                                .stroke(avatar == e ? theme.primary : theme.p.s200, lineWidth: 1))
                    }
                    .buttonStyle(FlatPress())
                    .accessibilityLabel(e)
                    .accessibilityAddTraits(avatar == e ? .isSelected : [])
                }
            }
            .padding(.top, 8)
            } label: {
                Text(L.t("parent.child.or_emoji")).font(F.sm).foregroundStyle(theme.mutedForeground)
            }
            .tint(theme.primary)
        }
    }

    private func formHeading(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(F.sans(14, .semibold)).foregroundStyle(theme.foreground)
            .accessibilityAddTraits(.isHeader)
    }

    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(F.sm).foregroundStyle(theme.foreground)
            content()
        }
    }

    private var birthdayBinding: Binding<Date> {
        Binding(
            get: {
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
                return f.date(from: birthday) ?? (Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date())
            },
            set: { birthday = SupabaseAPI.dayKey($0) }
        )
    }

    private func seed() {
        if let c = child {
            name = c.name
            username = c.username ?? ""
            birthday = c.birthday ?? ""
            avatar = c.avatar ?? ChildEmojis.all[0]
            dailyGoal = Double(c.daily_goal)
            stepsPer30 = Double(c.steps_per_30)
            capHours = Double(min(8, max(1, c.daily_cap_hours)))
            code = c.code
        } else {
            code = SupabaseAPI.generateChildCode()
        }
    }

    private func pick(_ item: PhotosPickerItem) async {
        uploading = true
        defer { uploading = false; photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let url = ProfileView.squareDataURL(image) else { return }
        avatar = url
    }

    @MainActor
    private func checkUsername() async {
        let candidate = UsernameRules.normalize(username)
        usernameAvailable = false
        checkingUsername = false
        usernameError = nil
        if unchangedUsername { checkedUsername = candidate; usernameAvailable = true; return }
        if let key = UsernameRules.validationKey(candidate) {
            if !candidate.isEmpty { usernameError = L.t(key) }
            return
        }
        checkingUsername = true
        do {
            try await Task.sleep(for: .milliseconds(400))
            let available = try await SupabaseAPI.usernameAvailable(candidate, excludingChildID: child?.id)
            guard !Task.isCancelled, candidate == UsernameRules.normalize(username) else { return }
            checkedUsername = candidate
            usernameAvailable = available
            checkingUsername = false
            usernameError = available ? nil : L.t("account.username.taken")
        } catch {
            guard !Task.isCancelled, candidate == UsernameRules.normalize(username) else { return }
            checkingUsername = false
            usernameError = L.t("auth.username_check_failed")
        }
    }

    @MainActor
    private func save() async {
        guard !saving else { return }
        error = nil
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { error = L.t("parent.child.name_required"); return }
        let candidate = UsernameRules.normalize(username)
        if !unchangedUsername, let key = UsernameRules.validationKey(candidate) { error = L.t(key); return }
        saving = true
        defer { saving = false }
        do {
            if !unchangedUsername {
                guard try await SupabaseAPI.usernameAvailable(candidate, excludingChildID: child?.id) else {
                    usernameAvailable = false
                    error = L.t("account.username.taken"); return
                }
            }
            if let c = child {
                var patch: [String: AnyJSON] = [
                    "name": .string(trimmedName),
                    "avatar": .string(avatar),
                    "birthday": birthday.isEmpty ? .null : .string(birthday),
                    "daily_goal": .integer(Int(dailyGoal)),
                    "steps_per_30": .integer(Int(stepsPer30)),
                    "daily_cap_hours": .integer(Int(capHours)),
                ]
                if !unchangedUsername { patch["username"] = .string(candidate) }
                try await SupabaseAPI.updateChild(c.id, patch)
            } else {
                try await SupabaseAPI.createChild(name: trimmedName, username: candidate, avatar: avatar,
                                                  birthday: birthday, dailyGoal: Int(dailyGoal),
                                                  stepsPer30: Int(stepsPer30), dailyCapHours: Int(capHours))
            }
            await onDone()
            dismiss()
        } catch {
            self.error = UsernameRules.errorMessage(error)
        }
    }
}

// MARK: - Delete child (password confirmation)

struct DeleteChildDialog: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let child: ChildRow
    let onDone: () async -> Void

    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        AppDialog(title: L.t("parent.child.delete_title", ["n": child.name.isEmpty ? "—" : child.name]),
                  description: L.t("parent.child.delete_desc", ["n": child.name.isEmpty ? "—" : child.name])) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L.t("parent.child.delete_pw")).eyebrow(theme.p.s600)
                SecureField("", text: $password).textContentType(.password).fieldStyle()
                if let error { Text(error).font(F.xs).foregroundStyle(theme.destructive) }
            }
        } footer: {
            DialogFooterButtons(cancelTitle: L.t("settings.cancel"),
                                confirmTitle: busy ? L.t("parent.child.deleting") : L.t("parent.child.delete_confirm"),
                                destructive: true,
                                disabled: password.isEmpty || busy,
                                onCancel: { dismiss() },
                                onConfirm: {
                                    busy = true
                                    Task {
                                        do {
                                            try await SupabaseAPI.deleteChild(child.id, password: password)
                                            await onDone()
                                            dismiss()
                                        } catch {
                                            self.error = error.localizedDescription
                                            busy = false
                                        }
                                    }
                                })
        }
        .presentationDetents([.height(340)])
    }
}

// MARK: - Gift screen time

struct GiftScreenTimeDialog: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let child: ChildRow
    let onDone: () async -> Void

    @State private var minutes = 30
    @State private var note = ""
    @State private var busy = false
    @State private var error: String?

    private let presets = [15, 30, 45, 60, 90, 120]

    var body: some View {
        AppDialog(title: L.t("parent.gift.dialog_title", ["n": child.name.isEmpty ? "—" : child.name]),
                  description: L.t("parent.gift.dialog_desc")) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { m in
                        Button { minutes = m } label: {
                            Text("\(m)m").font(F.sans(12, .semibold))
                                .foregroundStyle(minutes == m ? theme.primaryForeground : theme.p.s700)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(minutes == m ? theme.primary : theme.p.s50, in: Capsule())
                                .overlay(Capsule().stroke(minutes == m ? .clear : theme.p.s200, lineWidth: 1))
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.t("parent.gift.minutes")).eyebrow(theme.p.s600)
                    Stepper("\(minutes) min", value: $minutes, in: 1...600, step: 5)
                        .font(F.sm).foregroundStyle(theme.p.s900)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.t("parent.gift.note")).eyebrow(theme.p.s600)
                    TextField("", text: $note).fieldStyle()
                }
                if let error { Text(error).font(F.xs).foregroundStyle(theme.destructive) }
            }
        } footer: {
            DialogFooterButtons(cancelTitle: L.t("settings.cancel"),
                                confirmTitle: busy ? L.t("parent.gift.sending") : L.t("parent.gift.confirm"),
                                disabled: busy || minutes < 1,
                                onCancel: { dismiss() },
                                onConfirm: {
                                    busy = true
                                    Task {
                                        guard let uid = child.auth_user_id else { busy = false; return }
                                        do {
                                            try await SupabaseAPI.giftScreenTime(
                                                childID: child.id, childUserID: uid, minutes: minutes,
                                                note: note.trimmingCharacters(in: .whitespaces).isEmpty
                                                    ? nil : note)
                                            await onDone()
                                            dismiss()
                                        } catch {
                                            self.error = error.localizedDescription
                                            busy = false
                                        }
                                    }
                                })
        }
        .presentationDetents([.height(420)])
    }
}
