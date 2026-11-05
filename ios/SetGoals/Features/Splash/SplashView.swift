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
                // Stay opaque from the first frame: never reveal Home under the fade.
                theme.splashOpeningBackground
                    .ignoresSafeArea()

                ZStack {
                    theme.splashFill
                    Image(uiImage: SplashView.grain)
                        .resizable(resizingMode: .tile)
                        .blendMode(.softLight)
                        .opacity(0.16)
                }
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
                            .fill(theme.splashForeground.opacity(0.28 * track))
                        Capsule()
                            .fill(theme.splashForeground)
                            .frame(width: max(0, 132 * load))
                    }
                    .frame(width: 132, height: 3.5)
                    .opacity(track)
                    .padding(.bottom, 108)
                }
            }
        }
        .allowsHitTesting(false)
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

    /// A small, stable monochrome tile, generated once rather than every frame.
    /// Soft-light blending adds paper-like grain without changing the sage hue.
    private static let grain: UIImage = {
        let size = 192
        var seed: UInt32 = 42
        var pixels = [UInt8]()
        pixels.reserveCapacity(size * size)
        for _ in 0..<(size * size) {
            seed = 1664525 &* seed &+ 1013904223
            pixels.append(UInt8(truncatingIfNeeded: seed >> 24))
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: size, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false,
                intent: .defaultIntent
              ) else { return UIImage() }
        return UIImage(cgImage: image)
    }()

    private func progress(_ elapsed: Double, from start: Double, duration: Double) -> Double {
        let value = min(1, max(0, (elapsed - start) / duration))
        return value * value * (3 - 2 * value)
    }
}
