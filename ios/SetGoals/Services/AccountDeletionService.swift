import Foundation

/// Permanently deletes accounts through the app backend
/// (`/api/public/delete-account`), which re-checks the password, removes every
/// row the account owns and deletes the auth user itself. Deleting a parent
/// account also deletes all of their children's accounts.
enum AccountDeletionService {
    static let endpoint = URL(string: "https://step-wise-life.lovable.app/api/public/delete-account")!

    enum Failure: LocalizedError {
        case wrongPassword
        case message(String)
        var errorDescription: String? {
            switch self {
            case .wrongPassword: return L.t("delete.wrong_password")
            case let .message(m): return m
            }
        }
    }

    /// - Parameter childId: pass `nil` to delete the signed-in account (and all
    ///   of its children), or a child profile id to delete just that child.
    static func delete(password: String, childId: UUID? = nil) async throws {
        let token = try await supabase.auth.session.accessToken
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: String] = ["password": password]
        if let childId { body["childId"] = childId.uuidString.lowercased() }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let err = payload?["error"] as? String ?? "Deletion failed"
            throw err == "wrong_password" ? Failure.wrongPassword : Failure.message(err)
        }
    }
}
