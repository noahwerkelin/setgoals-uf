import SwiftUI

/// Port of `src/components/FriendsCard.tsx` — friends list with a
/// username search dialog. `rounded-3xl bg-card p-5 ring-1 ring-black/5`.
struct FriendsCard: View {
    @EnvironmentObject var theme: Theme
    @State private var friends: [FriendRow] = []
    @State private var showAdd = false

    var body: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: R.xl, style: .continuous).fill(theme.p.s100)
                        Image(systemName: "person.2.fill").font(.system(size: 14))
                            .foregroundStyle(theme.p.s700)
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(L.t("friends.title")).font(F.sans(14, .semibold))
                            .foregroundStyle(theme.foreground)
                        Text(L.t("friends.count", ["n": "\(friends.count)"]))
                            .font(F.text11).foregroundStyle(theme.p.s600)
                    }
                    Spacer()
                    Button { showAdd = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.plus").font(.system(size: 11, weight: .semibold))
                            Text(L.t("friends.add")).font(F.sans(11, .semibold))
                        }
                        .foregroundStyle(theme.primaryForeground)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(theme.p.s600, in: Capsule())
                    }
                }

                if friends.isEmpty {
                    Text(L.t("friends.empty"))
                        .font(F.xs).foregroundStyle(theme.p.s600)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(theme.p.s50, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                        .padding(.top, 16)
                } else {
                    VStack(spacing: 8) {
                        ForEach(friends.prefix(5)) { f in
                            HStack(spacing: 12) {
                                Text(String(f.name.prefix(1)).uppercased())
                                    .font(F.sans(12, .semibold)).foregroundStyle(theme.p.s700)
                                    .frame(width: 36, height: 36)
                                    .background(theme.p.s200, in: Circle())
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(f.name).font(F.sans(14, .medium)).lineLimit(1)
                                        .foregroundStyle(theme.foreground)
                                    Text("@\(f.username)").font(F.text11).lineLimit(1)
                                        .foregroundStyle(theme.p.s600)
                                }
                                Spacer()
                                Button {
                                    Task {
                                        try? await SupabaseAPI.removeFriend(friendshipID: f.friendshipID)
                                        await load()
                                    }
                                } label: {
                                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(theme.p.s600)
                                        .frame(width: 32, height: 32)
                                }
                                .accessibilityLabel(L.t("friends.remove"))
                            }
                            .padding(10)
                            .padding(.leading, 2)
                            .background(theme.p.s50.opacity(0.6),
                                        in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                        }
                    }
                    .padding(.top, 16)
                }
            }
        }
        .rise(delay: 0.15)
        .task { await load() }
        .sheet(isPresented: $showAdd) {
            AddFriendSheet(existing: friends) { Task { await load() } }
                .environmentObject(theme)
        }
    }

    private func load() async { friends = (try? await SupabaseAPI.friends()) ?? [] }
}

private struct AddFriendSheet: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.dismiss) private var dismiss
    let existing: [FriendRow]
    var onAdded: () -> Void

    @State private var q = ""
    @State private var results: [PublicUser] = []

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(L.t("friends.search.desc")).font(F.xs).foregroundStyle(theme.p.s600)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 14))
                        .foregroundStyle(theme.p.s600)
                    TextField(L.t("friends.search.placeholder"), text: $q)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .font(F.sm)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                    .strokeBorder(theme.ringBorder, lineWidth: 1))

                ScrollView {
                    VStack(spacing: 8) {
                        if q.trimmingCharacters(in: .whitespaces).count < 2 {
                            hint(L.t("friends.search.hint"))
                        } else if visible.isEmpty {
                            hint(L.t("friends.search.no_results"))
                        } else {
                            ForEach(visible) { u in
                                Button {
                                    Task {
                                        try? await SupabaseAPI.addFriend(u.id)
                                        q = ""; results = []
                                        onAdded()
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(String(u.name.prefix(1)).uppercased())
                                            .font(F.sans(12, .semibold)).foregroundStyle(theme.p.s700)
                                            .frame(width: 36, height: 36)
                                            .background(theme.p.s200, in: Circle())
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(u.name).font(F.sans(14, .medium)).lineLimit(1)
                                                .foregroundStyle(theme.foreground)
                                            Text("@\(u.username)").font(F.text11).lineLimit(1)
                                                .foregroundStyle(theme.p.s600)
                                        }
                                        Spacer()
                                        Image(systemName: "person.badge.plus").font(.system(size: 14))
                                            .foregroundStyle(theme.p.s600)
                                    }
                                    .padding(10).padding(.leading, 2)
                                    .background(theme.p.s50.opacity(0.6),
                                                in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 288)
                Spacer(minLength: 0)
            }
            .padding(20)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(L.t("friends.search.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("common.close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task(id: q) {
            let query = q.trimmingCharacters(in: .whitespaces)
            guard query.count >= 2 else { results = []; return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            results = (try? await SupabaseAPI.searchUsers(query)) ?? []
        }
    }

    private var visible: [PublicUser] {
        let taken = Set(existing.map { $0.username.lowercased() })
        return results.filter { !taken.contains($0.username.lowercased()) }
    }

    private func hint(_ s: String) -> some View {
        Text(s).font(F.xs).foregroundStyle(theme.p.s600)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
    }
}
