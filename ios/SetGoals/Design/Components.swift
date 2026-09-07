import SwiftUI

/// `rounded-3xl bg-card p-5 shadow-sm ring-1 ring-black/5`
struct CardSurface<Content: View>: View {
    @EnvironmentObject var theme: Theme
    var radius: CGFloat = R.xl3
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(theme.ringBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1) // shadow-sm
    }
}

/// `rounded-full bg-sage-600 py-3.5 text-sm font-semibold text-primary-foreground`
struct PrimaryButton: View {
    @EnvironmentObject var theme: Theme
    let title: String
    var busy: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(F.sans(14, .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(theme.primaryForeground)
                .background(theme.primary, in: Capsule())
        }
        .disabled(busy)
        .opacity(busy ? 0.5 : 1)
    }
}

/// `w-full rounded-2xl bg-card px-4 py-3.5 text-sm ring-1 ring-black/5`
struct FieldStyle: ViewModifier {
    @EnvironmentObject var theme: Theme
    func body(content: Content) -> some View {
        content
            .font(F.sm)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(theme.card, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: R.xl2, style: .continuous)
                    .strokeBorder(theme.ringBorder, lineWidth: 1)
            )
    }
}

extension View {
    func fieldStyle() -> some View { modifier(FieldStyle()) }

    /// `animate-rise` — 0.5s cubic-bezier(0.16, 1, 0.3, 1), 8px translate + fade.
    func rise(delay: Double = 0) -> some View { modifier(RiseModifier(delay: delay)) }
}

struct RiseModifier: ViewModifier {
    let delay: Double
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 8)
            .onAppear {
                withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.5).delay(delay)) { shown = true }
            }
    }
}

/// Home stat tile — `rounded-3xl bg-card p-5 ring-1 ring-black/5`
/// with a size-7 rounded-lg sage-100 icon chip, xs label and xl value.
struct StatTile: View {
    @EnvironmentObject var theme: Theme
    let systemImage: String
    let label: String
    let value: String
    let unit: String

    var body: some View {
        CardSurface(radius: R.xl3, padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: R.lg, style: .continuous).fill(theme.p.s100)
                        Image(systemName: systemImage)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(theme.p.s700)
                    }
                    .frame(width: 28, height: 28)
                    Text(label).font(F.sans(12, .medium)).foregroundStyle(theme.p.s600)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value).font(F.sans(20, .medium)).tabularNums()
                        .foregroundStyle(theme.foreground)
                    Text(unit).font(F.sans(12, .regular)).foregroundStyle(theme.p.s600.opacity(0.6))
                }
            }
        }
    }
}

