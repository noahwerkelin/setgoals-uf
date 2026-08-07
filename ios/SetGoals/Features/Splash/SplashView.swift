import SwiftUI

/// Port of `src/components/Splash.tsx` — radial sage gradient, two pulsing
/// rings, gradient logo tile, title, tagline and the 1.1s progress bar.
struct SplashView: View {
    @EnvironmentObject var theme: Theme
    @State private var appeared = false
    @State private var pulse = false
    @State private var bar: CGFloat = 0

    var body: some View {
        ZStack {
            RadialGradient(colors: [theme.p.s100, theme.p.s50, theme.p.s200],
                           center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 520)
                .ignoresSafeArea()

            ZStack {
                ring(460, delay: 0)
                ring(320, delay: 0.12)
            }

            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(LinearGradient(colors: [theme.p.s500, theme.p.s700],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "shoeprints.fill")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(theme.primaryForeground)
                }
                .frame(width: 96, height: 96)
                .shadow(color: theme.p.s700.opacity(0.55), radius: 30, y: 20)
                .modifier(SplashRise(appeared: appeared, delay: 0))

                Text("SetGoals")
                    .font(F.sans(30, .semibold)).tracking(-0.5)
                    .foregroundStyle(theme.p.s950)
                    .padding(.top, 28)
                    .modifier(SplashRise(appeared: appeared, delay: 0.12))

                Text(L.t("splash.tagline"))
                    .font(F.sm).foregroundStyle(theme.p.s700)
                    .padding(.top, 8)
                    .modifier(SplashRise(appeared: appeared, delay: 0.24))

                ZStack(alignment: .leading) {
                    Capsule().fill(theme.p.s200)
                    Capsule().fill(theme.p.s600).frame(width: 96 * bar)
                }
                .frame(width: 96, height: 3)
                .padding(.top, 40)
                .modifier(SplashRise(appeared: appeared, delay: 0.36))
            }
        }
        .onAppear {
            appeared = true
            pulse = true
            withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 1.1).delay(0.36)) { bar = 1 }
        }
    }

    private func ring(_ size: CGFloat, delay: Double) -> some View {
        Circle()
            .strokeBorder(theme.p.s600.opacity(size > 400 ? 0.18 : 0.28), lineWidth: 1)
            .frame(width: size, height: size)
            .scaleEffect(pulse ? 1.15 : 0.7)
            .opacity(pulse ? 0 : 1)
            .animation(.easeOut(duration: 2.4).delay(delay), value: pulse)
    }
}

private struct SplashRise: ViewModifier {
    let appeared: Bool
    let delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.7).delay(delay), value: appeared)
    }
}
