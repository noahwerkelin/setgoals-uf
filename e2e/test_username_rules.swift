import Foundation

// Compile alongside the real UsernameRules.swift; only the localization dependency is stubbed.
enum L { static func t(_ key: String) -> String { key } }
@main struct UsernameRuleTests {
    static func main() {
        precondition(!UsernameRules.isValid("ab"))
        precondition(UsernameRules.isValid("abc"))
        precondition(UsernameRules.isValid(String(repeating: "a", count: 20)))
        precondition(!UsernameRules.isValid(String(repeating: "a", count: 21)))
        precondition(UsernameRules.isValid("USER_123"))
        for name in ["åke", "user١", "no-name", "a b"] { precondition(!UsernameRules.isValid(name)) }
        precondition(UsernameRules.normalize(" User_123 ") == "user_123")
        precondition(UsernameRules.validationKey("ab") == "username.too_short")
        precondition(UsernameRules.validationKey(String(repeating: "a", count: 21)) == "username.too_long")
        precondition(UsernameRules.validationKey("åke") == "username.characters")
        print("Native username rules passed")
    }
}