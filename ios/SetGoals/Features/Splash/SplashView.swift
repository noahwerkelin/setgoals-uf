import SwiftUI

/// Footsteps trace a journey, gather into the mark, then reveal the wordmark.
/// Presentation only: this sequence never delays account loading or dismissal.
struct SplashView: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var settled = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion || settled)) { timeline in
            let elapsed = reduceMotion || settled ? 3.0 : max(0, timeline.date.timeIntervalSince(startedAt))
            ZStack {
                theme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    journey(elapsed)
                        .frame(width: 260, height: 190)
                        .accessibilityHidden(true)

                    let title = progress(elapsed, from: 1.5, duration: 0.6)
                    Text("SetGoals")
                        .font(F.xl4)
                        .foregroundStyle(theme.foreground)
                        .mask(alignment: .leading) {
                            GeometryReader { geometry in
                                Rectangle().frame(width: geometry.size.width * title)
                            }
                        }
                        .offset(y: 8 * (1 - title))

                    let caption = progress(elapsed, from: 2.0, duration: 0.4)
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
        let gather = progress(elapsed, from: 1.05, duration: 0.65)
        let logo = progress(elapsed, from: 1.24, duration: 0.58)
        let sweep = progress(elapsed, from: 1.72, duration: 0.55)
        return ZStack {
            SplashTrail()
                .trim(from: progress(elapsed, from: 0.95, duration: 0.5),
                      to: progress(elapsed, from: 0.02, duration: 1.0))
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 1.25, lineCap: .round))
                .opacity(0.7 * (1 - gather))

            RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                .fill(theme.secondary)
                .overlay {
                    RoundedRectangle(cornerRadius: R.xl3, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1)
                }
                .frame(width: 96, height: 96)
                .overlay {
                    // One subtle light pass, clipped to the tile — no glow or heavy shadow.
                    Rectangle()
                        .fill(theme.primary.opacity(0.08))
                        .frame(width: 24, height: 160)
                        .rotationEffect(.degrees(24))
                        .offset(x: -90 + 180 * sweep)
                        .opacity(sin(sweep * .pi))
                        .mask(RoundedRectangle(cornerRadius: R.xl3, style: .continuous))
                }
                .scaleEffect(0.8 + 0.2 * logo + 0.05 * sin(logo * .pi))
                .opacity(logo)

            ForEach(0..<8, id: \.self) { index in
                footfall(index, elapsed: elapsed)
            }
        }
    }

    private func footfall(_ index: Int, elapsed: Double) -> some View {
        let left = index.isMultiple(of: 2)
        let landing = progress(elapsed, from: Double(index) * 0.115, duration: 0.22)
        let gather = progress(elapsed, from: 1.04 + Double(index) * 0.035, duration: 0.54)
        let point = SplashTrail.point(Double(index) / 7)
        let side = left ? -1.0 : 1.0
        let originX = point.x + side * 8
        let originY = point.y
        let targetX = side * 13
        let targetY = left ? -5.0 : 5.0
        let lift = sin(gather * .pi)
        let fade = index < 6 ? 1 - progress(elapsed, from: 1.35 + Double(index) * 0.035, duration: 0.28) : 1

        return SplashFootprint()
            .fill(theme.primary)
            .frame(width: 13 + 4 * gather, height: 29 + 9 * gather)
            .scaleEffect(x: left ? -1 : 1, y: 1)
            .rotationEffect(.degrees(32 * (1 - gather) + side * 10 * gather))
            .scaleEffect(0.72 + 0.28 * landing + 0.08 * sin(landing * .pi))
            .offset(x: originX * (1 - gather) + targetX * gather + side * 14 * lift,
                    y: originY * (1 - gather) + targetY * gather - 18 * lift - 10 * (1 - landing))
            .opacity(landing * fade)
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
        path.move(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.6))
        path.addCurve(to: CGPoint(x: rect.width * 0.5, y: 0),
                      control1: CGPoint(x: -rect.width * 0.12, y: rect.height * 0.28),
                      control2: CGPoint(x: rect.width * 0.06, y: 0))
        path.addCurve(to: CGPoint(x: rect.width * 0.83, y: rect.height * 0.6),
                      control1: CGPoint(x: rect.width * 1.06, y: 0),
                      control2: CGPoint(x: rect.width * 1.05, y: rect.height * 0.4))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.6),
                          control: CGPoint(x: rect.width * 0.5, y: rect.height * 0.76))
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: rect.width * 0.16, y: rect.height * 0.75,
                                  width: rect.width * 0.68, height: rect.height * 0.25))
        return path
    }
}

private struct SplashTrail: Shape {
    /// Shared curve positions keep every footfall aligned with the drawn route.
    static func point(_ t: Double) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * u * -108 + 3 * u * u * t * -58 + 3 * u * t * t * 44 + t * t * t * 100,
                       y: u * u * u * 58 + 3 * u * u * t * 50 + 3 * u * t * t * -62 + t * t * t * -52)
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - 108, y: rect.midY + 58))
        path.addCurve(to: CGPoint(x: rect.midX + 100, y: rect.midY - 52),
                      control1: CGPoint(x: rect.midX - 58, y: rect.midY + 50),
                      control2: CGPoint(x: rect.midX + 44, y: rect.midY - 62))
        return path
    }
}
