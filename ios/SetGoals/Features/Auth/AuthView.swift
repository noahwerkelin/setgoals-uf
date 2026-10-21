import SwiftUI

/// Shown when an onboarded user is signed out. Reuses the redesigned
/// onboarding account flows (sign in, kid code, sign up) without the slides;
/// RootView switches to the app as soon as a session exists.
struct AuthView: View {
    var body: some View {
        OnboardingView(authOnly: true) {}
    }
}
