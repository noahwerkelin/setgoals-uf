import SwiftUI

/// Port of `src/components/ProgressRing.tsx`.
/// size 224, stroke 14, track sage-100, ring sage-600, rotated -90°,
/// animated with the same 1.2s cubic-bezier(0.16, 1, 0.3, 1) curve.
struct ProgressRing<Content: View>: View {
    @EnvironmentObject var theme: Theme
    let progress: Double
    var size: CGFloat = 224
    var stroke: CGFloat = 14
    @ViewBuilder var content: Content

    @State private var animated: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.p.s100, lineWidth: stroke)
            Circle()
                .trim(from: 0, to: max(0, min(1, animated)))
                .stroke(theme.p.s600, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
            content
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 1.2)) { animated = progress }
        }
        .onChange(of: progress) { _, new in
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 1.2)) { animated = new }
        }
    }
}
