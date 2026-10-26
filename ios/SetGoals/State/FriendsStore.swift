import Foundation
import SwiftUI

/// Shared friends snapshot, preloaded at account entry rather than view visits.
@MainActor
final class FriendsStore: ObservableObject {
    static let shared = FriendsStore()
    @Published private(set) var requests: [FriendRequestRow] = []
    @Published private(set) var friends: [FriendRow] = []
    @Published private(set) var board: [LeaderboardEntry] = []
    @Published private(set) var userID: UUID?
    @Published private(set) var loaded = false
    private var loading = false
    private var day = ""
    private var generation = UUID()

    func clear() {
        generation = UUID()
        loading = false
        friends = []
        requests = []
        board = []
        userID = nil
        loaded = false
        day = ""
    }

    func preload() async {
        let uid = await SupabaseAPI.currentUserID()
        if uid != userID { clear() }
        guard !loaded || day != SupabaseAPI.todayKey else { return }
        await refresh()
    }

    func refresh() async {
        guard !loading else { return }
        guard let uid = await SupabaseAPI.currentUserID() else { clear(); return }
        if uid != userID { clear() }
        userID = uid
        loading = true
        let request = generation
        let requestDay = SupabaseAPI.todayKey
        defer { if request == generation { loading = false } }
        do {
            async let list = SupabaseAPI.friends()
            async let pending = SupabaseAPI.friendRequests()
            async let ranks = SupabaseAPI.leaderboard(scope: "friends")
            let (newFriends, newBoard, newRequests) = try await (list, ranks, pending)
            guard request == generation,
                  await SupabaseAPI.currentUserID() == uid else { return }
            requests = newRequests
            friends = newFriends
            board = newBoard
            loaded = true
            day = requestDay
        } catch {
            // Retain the last successful snapshot, never replace it with a false empty state.
        }
    }
}