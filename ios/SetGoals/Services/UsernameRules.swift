import Foundation

/// One native rule set for signup, personal edits and parent-managed usernames.
enum UsernameRules {
    static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isValid(_ value: String) -> Bool {
        let value = normalize(value)
        return value.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil
    }

    static func validationKey(_ value: String) -> String? {
        let value = normalize(value)
        if value.count < 3 { return "username.too_short" }
        if value.count > 20 { return "username.too_long" }
        return isValid(value) ? nil : "username.characters"
    }

    static func errorMessage(_ error: Error) -> String {
        let message = String(describing: error).lowercased()
        if message.contains("username_taken") || message.contains("username_lower_key") || message.contains("profiles_username_key") {
            return L.t("account.username.taken")
        }
        if message.contains("username_invalid") { return L.t("auth.username_invalid") }
        return error.localizedDescription
    }
}