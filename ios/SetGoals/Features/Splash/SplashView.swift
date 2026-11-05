import SwiftUI

/// A flat reveal: the screen settles into one theme fill, the mark rests
/// centered and a thin bar tracks the wait. Presentation only — this never
/// delays account loading or dismissal.
struct SplashView: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var settled = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion || settled)) { timeline in
            let elapsed = reduceMotion || settled ? 3.0 : max(0, timeline.date.timeIntervalSince(startedAt))
            let fill = progress(elapsed, from: 0.0, duration: 0.55)
            let mark = progress(elapsed, from: 0.35, duration: 0.5)
            let track = progress(elapsed, from: 0.5, duration: 0.4)
            let load = progress(elapsed, from: 0.6, duration: 1.6)

            ZStack {
                // The whole screen eases into a single sage fill.
                theme.p.s500
                    .ignoresSafeArea()
                    .opacity(fill)

                Image(uiImage: SplashView.logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 172)
                    .opacity(mark)
                    .scaleEffect(0.94 + 0.06 * mark)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.28 * track))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, 132 * load))
                    }
                    .frame(width: 132, height: 3.5)
                    .opacity(track)
                    .padding(.bottom, 108)
                }
            }
        }
        .task(id: reduceMotion) {
            startedAt = Date()
            settled = false
            guard !reduceMotion else { return }
            do {
                try await Task.sleep(for: .seconds(2.4))
                settled = true
            } catch {
                // SwiftUI cancels the sequence when the splash is dismissed.
            }
        }
    }

    private static let logo = UIImage(named: "SplashLogo") ?? UIImage()

    private func progress(_ elapsed: Double, from start: Double, duration: Double) -> Double {
        let value = min(1, max(0, (elapsed - start) / duration))
        return value * value * (3 - 2 * value)
    }
}
