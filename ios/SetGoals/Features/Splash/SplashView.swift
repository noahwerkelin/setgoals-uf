import SwiftUI

/// Footsteps trace a journey, gather into the mark, then reveal the wordmark.
/// Presentation only: this sequence never delays account loading or dismissal.
struct SplashView: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var settled = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || settled)) { timeline in
            let elapsed = reduceMotion || settled ? 3.0 : max(0, timeline.date.timeIntervalSince(startedAt))
            ZStack {
                theme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    journey(elapsed)
                        .frame(width: 260, height: 190)
                        .accessibilityHidden(true)

                    HStack(spacing: 0) {
                        ForEach(Array("SetGoals".enumerated()), id: \.offset) { index, letter in
                            let reveal = progress(elapsed, from: 1.25 + Double(index) * 0.065, duration: 0.42)
                            Text(String(letter))
                                .font(F.xl4)
                                .foregroundStyle(theme.foreground)
                                .opacity(reveal)
                                .offset(y: 16 * (1 - reveal))
                                .blur(radius: 3 * (1 - reveal))
                        }
                    }
                    .accessibilityLabel("SetGoals")

                    let caption = progress(elapsed, from: 1.9, duration: 0.4)
                    Text(L.t("splash.tagline"))
                        .font(F.sm)
                        .foregroundStyle(theme.mutedForeground)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .opacity(caption)
                        .offset(y: 6 * (1 - caption))
                }
                .padding(.horizontal, 24)
            }
            .accessibilityElement(children: .combine)
        }
        .task(id: reduceMotion) {
            startedAt = Date()
            settled = false
            guard !reduceMotion else { return }
            do {
                try await Task.sleep(for: .seconds(2.6))
                settled = true
            } catch {
                // SwiftUI cancels the sequence when the splash is dismissed.
            }
        }
    }

    private func journey(_ elapsed: Double) -> some View {
        let gather = progress(elapsed, from: 1.02, duration: 0.55)
        let logo = progress(elapsed, from: 1.22, duration: 0.48)
        return ZStack {
            SplashTrail()
                .trim(from: 0, to: progress(elapsed, from: 0.05, duration: 0.95))
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 7]))
                .opacity(0.65 * (1 - gather))

            ForEach(0..<6, id: \.self) { index in
                let landing = progress(elapsed, from: Double(index) * 0.14, duration: 0.24)
                let x = -100.0 + Double(index) * 36.0
                let y = 46.0 - Double(index) * 17.0 + (index.isMultiple(of: 2) ? -9.0 : 9.0)
                SplashFootprint()
                    .fill(theme.primary)
                    .frame(width: 12, height: 27)
                    .scaleEffect(x: index.isMultiple(of: 2) ? -1 : 1, y: 1)
                    .rotationEffect(.degrees(28 * (1 - gather)))
                    .scaleEffect(0.55 + 0.45 * landing)
                    .offset(x: x * (1 - gather), y: y * (1 - gather) - 12 * (1 - landing))
                    .opacity(landing * (1 - gather))
            }

            RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                .fill(theme.secondary)
                .overlay {
                    RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1)
                }
                .frame(width: 96, height: 96)
                .scaleEffect(0.76 + 0.24 * logo + 0.04 * sin(logo * .pi))
                .opacity(logo)

            Image(systemName: "shoeprints.fill")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(theme.primary)
                .scaleEffect(0.65 + 0.35 * logo)
                .rotationEffect(.degrees(-12 * (1 - logo)))
                .opacity(logo)
        }
    }

    private func progress(_ elapsed: Double, from start: Double, duration: Double) -> Double {
        let value = min(1, max(0, (elapsed - start) / duration))
        return value * value * (3 - 2 * value)
    }
}

/// A single sole allows alternate left/right footfalls instead of paired icons.
private struct SplashFootprint: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: CGRect(x: rect.width * 0.08, y: 0,
                                      width: rect.width * 0.84, height: rect.height * 0.66),
                            cornerSize: CGSize(width: rect.width * 0.42, height: rect.width * 0.42))
        path.addEllipse(in: CGRect(x: rect.width * 0.16, y: rect.height * 0.75,
                                  width: rect.width * 0.68, height: rect.height * 0.25))
        return path
    }
}

private struct SplashTrail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - 106, y: rect.midY + 48))
        path.addCurve(to: CGPoint(x: rect.midX + 84, y: rect.midY - 45),
                      control1: CGPoint(x: rect.midX - 40, y: rect.midY + 28),
                      control2: CGPoint(x: rect.midX + 18, y: rect.midY - 44))
        return path
    }
}
