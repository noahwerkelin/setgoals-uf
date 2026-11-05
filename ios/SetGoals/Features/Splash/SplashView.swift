import SwiftUI

/// A lightweight brand animation; account loading and dismissal remain owned
/// by SetGoalsApp. All surfaces follow the user's theme and appearance.
struct SplashView: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var revolving = false
    @State private var stepping = false

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .strokeBorder(theme.accent.opacity(0.6), lineWidth: 3)

                    Circle()
                        .trim(from: 0, to: appeared ? 0.78 : 0)
                        .stroke(theme.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90 + (revolving ? 360 : 0)))
                        .animation(reduceMotion ? nil : .easeOut(duration: 1.0), value: appeared)

                    ZStack {
                        RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                            .fill(theme.secondary)
                        RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                            .strokeBorder(theme.border, lineWidth: 1)
                        Image(systemName: "shoeprints.fill")
                            .font(.system(size: 42, weight: .regular))
                            .foregroundStyle(theme.primary)
                            .rotationEffect(.degrees(stepping ? 4 : -4))
                            .offset(y: stepping ? -2 : 2)
                    }
                    .frame(width: 96, height: 96)
                }
                .frame(width: 140, height: 140)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.88)
                .modifier(SplashRise(appeared: appeared, reduceMotion: reduceMotion, delay: 0))

                Text("SetGoals")
                    .font(F.xl4)
                    .foregroundStyle(theme.foreground)
                    .padding(.top, 28)
                    .modifier(SplashRise(appeared: appeared, reduceMotion: reduceMotion, delay: 0.12))

                Text(L.t("splash.tagline"))
                    .font(F.sm).foregroundStyle(theme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .modifier(SplashRise(appeared: appeared, reduceMotion: reduceMotion, delay: 0.24))
            }
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .combine)
        .onAppear {
            appeared = true
            updateMotion()
        }
        .onChange(of: reduceMotion) { _, _ in updateMotion() }
    }

    private func updateMotion() {
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            revolving = false
            stepping = false
        }
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
            revolving = true
        }
        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
            stepping = true
        }
    }
}

private struct SplashRise: ViewModifier {
    let appeared: Bool
    let reduceMotion: Bool
    let delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 10)
            .animation(reduceMotion ? nil : .timingCurve(0.16, 1, 0.3, 1, duration: 0.7).delay(delay), value: appeared)
    }
}
