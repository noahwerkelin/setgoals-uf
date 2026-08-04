import SwiftUI

/// Port of `src/components/Splash.tsx` — sage gradient + animated logo,
/// shown once per session for 2.5s.
struct SplashView: View {
    @EnvironmentObject var theme: Theme
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.p.s100, theme.p.s50, theme.p.s200],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(theme.p.s600)
                    Image(systemName: "figure.walk")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(theme.primaryForeground)
                }
                .frame(width: 88, height: 88)
                .scaleEffect(appeared ? 1 : 0.86)
                .shadow(color: theme.p.s600.opacity(0.25), radius: 24, y: 12)

                Text("SetGoals")
                    .font(F.sans(28, .semibold)).tracking(-0.5)
                    .foregroundStyle(theme.p.s950)
                Text(L.t("splash.tagline"))
                    .font(F.sm).foregroundStyle(theme.p.s700)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
        }
        .onAppear {
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.6)) { appeared = true }
        }
    }
}
