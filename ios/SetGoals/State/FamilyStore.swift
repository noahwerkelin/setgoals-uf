import Foundation
import SwiftUI

/// Account-scoped family snapshot shared by Home and Screen Time.
@MainActor
final class FamilyStore: ObservableObject {
    static let shared = FamilyStore()
    @Published private(set) var children: [ChildRow] = []
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var today: [UUID: ChildDayStats] = [:]
    @Published private(set) var week: [UUID: [String: (steps: Int, usedMin: Int)]] = [:]
    @Published private(set) var userID: UUID?
    @Published private(set) var loaded = false
    @Published private(set) var loading = false
    @Published private(set) var failed = false
    private var day = ""
    private var generation = UUID()

    func clear() {
        generation = UUID()
        children = []; members = []; today = [:]; week = [:]
        userID = nil; loaded = false; loading = false; failed = false; day = ""
    }

    func preload() async {
        let uid = await SupabaseAPI.currentUserID()
        if uid != userID { clear() }
        guard !loaded || day != SupabaseAPI.todayKey else { return }
        await refresh()
    }

    func refresh() async {
        guard let uid = await SupabaseAPI.currentUserID() else { clear(); return }
        if uid != userID { clear() }
        guard !loading else { return }
        userID = uid
        loading = true
        let request = generation
        let requestDay = SupabaseAPI.todayKey
        defer { if request == generation { loading = false } }
        do {
            async let rows = SupabaseAPI.children()
            async let family = SupabaseAPI.familyToday()
            let (newChildren, newMembers) = try await (rows, family)
            let activity = await SupabaseAPI.childActivity(newChildren.compactMap(\.auth_user_id))
            guard request == generation, await SupabaseAPI.currentUserID() == uid else { return }
            children = newChildren; members = newMembers
            today = activity.today; week = activity.week
            loaded = true; failed = false; day = requestDay
        } catch {
            if request == generation { failed = true }
            // Keep the last successful snapshot instead of showing a false empty family.
        }
    }
}