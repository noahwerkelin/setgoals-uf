import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI
import Supabase

/// Native sign-in with Apple / Google.
///
/// The previous code called `supabase.auth.signInWithOAuth(provider:)` with no
/// redirect URL and no presentation anchor, which traps at runtime on iOS
/// (`ASWebAuthenticationSession` has no window to attach to and Supabase falls
/// back to the site URL, which never returns to the app).
///
/// Apple uses the native `ASAuthorizationAppleIDProvider` + `signInWithIdToken`.
/// Google uses `ASWebAuthenticationSession` with the app's custom URL scheme.
@MainActor
final class OAuthService: NSObject, ObservableObject {
    static let shared = OAuthService()

    /// Must match a `CFBundleURLSchemes` entry in Info.plist and the redirect
    /// URL allow-list of the backend auth settings.
    static let callbackScheme = "app.setgoals"
    static var redirectURL: URL { URL(string: "\(callbackScheme)://auth-callback")! }

    private var currentNonce: String?
    private var webSession: ASWebAuthenticationSession?

    // MARK: - Apple

    func signInWithApple() async throws {
        let nonce = Self.randomNonce()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let credential = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleDelegate(continuation: cont)
            self.appleDelegate = delegate
            controller.delegate = delegate
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.missingToken
        }

        try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        appleDelegate = nil
    }

    private var appleDelegate: AppleDelegate?

    // MARK: - Google

    func signInWithGoogle() async throws {
        let url = try await supabase.auth.getOAuthSignInURL(
            provider: .google,
            redirectTo: Self.redirectURL
        )

        let callback = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                if let error { cont.resume(throwing: error); return }
                guard let callbackURL else { cont.resume(throwing: AuthError.cancelled); return }
                cont.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webSession = session
            if !session.start() { cont.resume(throwing: AuthError.cancelled) }
        }

        try await supabase.auth.session(from: callback)
        webSession = nil
    }

    // MARK: - Helpers

    enum AuthError: LocalizedError {
        case missingToken, cancelled

        var errorDescription: String? {
            switch self {
            case .missingToken: return "Apple did not return an identity token."
            case .cancelled: return "Sign-in was cancelled."
            }
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension OAuthService: ASAuthorizationControllerPresentationContextProviding,
                        ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        Self.keyWindow()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        Self.keyWindow()
    }

    private static func keyWindow() -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

private final class AppleDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>
    private var finished = false

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard !finished else { return }
        finished = true
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation.resume(returning: credential)
        } else {
            continuation.resume(throwing: OAuthService.AuthError.missingToken)
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        guard !finished else { return }
        finished = true
        continuation.resume(throwing: error)
    }
}
