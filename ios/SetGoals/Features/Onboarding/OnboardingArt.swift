import SwiftUI

// MARK: - Signature walker + progress path

/// The walking character that travels along the top path as the user moves
/// through onboarding. Footprints are left behind it at every completed step.
struct WalkerPath: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let progress: Double   // 0...1
    let steps: Int

    @State private var bob = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width - 28
            ZStack(alignment: .leading) {
                Capsule().fill(theme.p.s200).frame(height: 6)
                Capsule()
                    .fill(LinearGradient(colors: [theme.p.s500, theme.p.s700],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, w * progress + 14), height: 6)
                ForEach(0..<steps, id: \.self) { i in
                    let x = w * Double(i) / Double(max(1, steps - 1))
                    Circle()
                        .fill(Double(i) / Double(max(1, steps - 1)) <= progress + 0.001 ? theme.p.s700 : theme.p.s300)
                        .frame(width: 8, height: 8)
                        .offset(x: x + 10)
                }
                Image(systemName: "figure.walk")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.p.s700)
                    .frame(width: 28, height: 28)
                    .background(theme.card, in: Circle())
                    .shadow(color: theme.p.s700.opacity(0.25), radius: 6, y: 3)
                    .offset(x: w * progress, y: bob ? -3 : 0)
            }
            .frame(height: 28)
            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: progress)
        }
        .frame(height: 28)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { bob = true }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(Int(progress * 100))%"))
    }
}

// MARK: - Background

/// Soft gradient with drifting blobs that shift position per slide.
struct OnboardingBackdrop: View {
    @EnvironmentObject var theme: Theme
    let index: Int

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.p.s50, theme.p.s100], startPoint: .top, endPoint: .bottom)
            Circle().fill(theme.p.s200.opacity(0.55)).frame(width: 340).blur(radius: 60)
                .offset(x: index.isMultiple(of: 2) ? -120 : 130, y: -260 + CGFloat(index) * 18)
            Circle().fill(theme.p.s300.opacity(0.35)).frame(width: 280).blur(radius: 70)
                .offset(x: index.isMultiple(of: 2) ? 140 : -110, y: 260 - CGFloat(index) * 14)
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.9, dampingFraction: 0.85), value: index)
    }
}

// MARK: - Illustration frame

struct ArtCard<Content: View>: View {
    @EnvironmentObject var theme: Theme
    @ViewBuilder var content: Content
    var body: some View {
        ZStack { content }
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(LinearGradient(colors: [theme.card, theme.p.s100],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(theme.ringBorder, lineWidth: 1))
            .shadow(color: theme.p.s700.opacity(0.12), radius: 24, y: 14)
            .accessibilityHidden(true)
    }
}

// MARK: - Slide 1: steps → minutes → unlocked phone

struct WelcomeArt: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var steps = 0
    @State private var showMin = false
    @State private var unlocked = false

    var body: some View {
        ArtCard {
            HStack(spacing: 18) {
                VStack(spacing: 6) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 34)).foregroundStyle(theme.p.s700)
                        .symbolEffect(.bounce, options: .repeating, value: reduceMotion ? 0 : steps)
                    Text("\(steps)")
                        .font(F.sans(24, .bold)).monospacedDigit()
                        .contentTransition(.numericText(value: Double(steps)))
                        .foregroundStyle(theme.p.s950)
                    Text(L.t("ob.welcome.steps")).font(F.xs).foregroundStyle(theme.p.s600)
                }
                .frame(width: 92)

                Image(systemName: "arrow.right").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.p.s500)

                Text(L.t("ob.welcome.min"))
                    .font(F.sans(18, .bold)).foregroundStyle(theme.primaryForeground)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(theme.primary, in: Capsule())
                    .scaleEffect(showMin ? 1 : 0.4).opacity(showMin ? 1 : 0)

                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.p.s900).frame(width: 52, height: 92)
                    Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 20)).foregroundStyle(theme.p.s100)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .task { await loop() }
    }

    private func loop() async {
        if reduceMotion { steps = 1000; showMin = true; unlocked = true; return }
        while !Task.isCancelled {
            steps = 0; showMin = false; unlocked = false
            for v in stride(from: 100, through: 1000, by: 100) {
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.snappy) { steps = v }
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { showMin = true }
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation { unlocked = true }
            try? await Task.sleep(for: .seconds(2.2))
        }
    }
}

// MARK: - Slide 2

struct LanguageArt: View {
    @EnvironmentObject var theme: Theme
    let lang: String
    var body: some View {
        ArtCard {
            ZStack {
                bubble(lang == "sv" ? "Hej!" : "Hi!", big: true).offset(x: -46, y: -20)
                bubble(lang == "sv" ? "Hi!" : "Hej!", big: false).offset(x: 62, y: 34)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: lang)
        }
    }
    private func bubble(_ t: String, big: Bool) -> some View {
        Text(t).font(F.sans(big ? 40 : 24, .bold))
            .foregroundStyle(big ? theme.primaryForeground : theme.p.s700)
            .padding(.horizontal, big ? 28 : 18).padding(.vertical, big ? 18 : 12)
            .background(big ? theme.primary : theme.card,
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: theme.p.s700.opacity(0.18), radius: 12, y: 6)
    }
}

// MARK: - Slide 3: ring + footprints

struct HealthArt: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fill: CGFloat = 0

    var body: some View {
        ArtCard {
            ZStack {
                Circle().stroke(theme.p.s200, lineWidth: 16).frame(width: 150)
                Circle().trim(from: 0, to: fill)
                    .stroke(theme.primary, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 150)
                VStack(spacing: 2) {
                    Image(systemName: "heart.fill").font(.system(size: 22)).foregroundStyle(theme.destructive.opacity(0.85))
                    Text("\(Int(fill * 8000))").font(F.sans(22, .bold)).monospacedDigit()
                        .contentTransition(.numericText()).foregroundStyle(theme.p.s950)
                }
                ForEach(0..<4) { i in
                    Image(systemName: "shoeprints.fill").font(.system(size: 14))
                        .foregroundStyle(theme.p.s500.opacity(fill > CGFloat(i) * 0.2 ? 1 : 0.15))
                        .offset(x: -130 + CGFloat(i) * 18, y: 70 - CGFloat(i) * 22)
                }
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 1.6)) { fill = 0.78 }
        }
    }
}

// MARK: - Slide 4: map with moving pin

struct MapArt: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moved = false

    var body: some View {
        ArtCard {
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 30, y: 170))
                    p.addCurve(to: CGPoint(x: 300, y: 60), control1: CGPoint(x: 120, y: 40), control2: CGPoint(x: 200, y: 210))
                }
                .stroke(theme.p.s300, style: StrokeStyle(lineWidth: 10, lineCap: .round, dash: [1, 16]))
                .frame(width: 330, height: 230)
                ForEach([(CGPoint(x: -110, y: -60), "tree.fill"), (CGPoint(x: 100, y: 50), "leaf.fill"),
                         (CGPoint(x: 120, y: -70), "mountain.2.fill"), (CGPoint(x: -60, y: 70), "figure.hiking")],
                        id: \.1) { pos, icon in
                    Image(systemName: icon).font(.system(size: 22)).foregroundStyle(theme.p.s600)
                        .frame(width: 46, height: 46)
                        .background(theme.card, in: Circle())
                        .offset(x: pos.x, y: pos.y)
                }
                ZStack {
                    Circle().fill(theme.primary.opacity(0.2)).frame(width: 54)
                        .scaleEffect(moved ? 1.3 : 0.8)
                    Image(systemName: "mappin.circle.fill").font(.system(size: 34))
                        .foregroundStyle(theme.primary)
                }
                .offset(x: moved ? 40 : -20, y: moved ? -10 : 20)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { moved = true }
        }
    }
}

// MARK: - Slide 5: locked app → minutes → unlocked

struct ScreenTimeArt: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var minutes = 0

    var body: some View {
        ArtCard {
            HStack(spacing: 24) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(colors: [theme.p.s500, theme.p.s700], startPoint: .top, endPoint: .bottom))
                        .frame(width: 84, height: 84)
                        .overlay(Image(systemName: "play.fill").font(.system(size: 28)).foregroundStyle(theme.primaryForeground))
                        .saturation(minutes > 0 ? 1 : 0.1)
                    Image(systemName: minutes > 0 ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(theme.primaryForeground)
                        .frame(width: 28, height: 28)
                        .background(minutes > 0 ? theme.primary : theme.p.s900, in: Circle())
                        .offset(x: 8, y: -8)
                        .contentTransition(.symbolEffect(.replace))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "figure.walk").font(.system(size: 26)).foregroundStyle(theme.p.s700)
                    Text("+\(minutes) min").font(F.sans(26, .bold)).monospacedDigit()
                        .contentTransition(.numericText(value: Double(minutes)))
                        .foregroundStyle(theme.p.s950)
                }
            }
        }
        .task {
            if reduceMotion { minutes = 30; return }
            while !Task.isCancelled {
                minutes = 0
                try? await Task.sleep(for: .milliseconds(900))
                for v in stride(from: 5, through: 30, by: 5) {
                    withAnimation(.snappy) { minutes = v }
                    try? await Task.sleep(for: .milliseconds(220))
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}

// MARK: - Slide 7: finish flag

struct FinishArt: View {
    @EnvironmentObject var theme: Theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pop = false

    var body: some View {
        ArtCard {
            ZStack {
                ForEach(0..<14, id: \.self) { i in
                    let angle = Double(i) / 14 * 2 * .pi
                    Circle().fill(i.isMultiple(of: 2) ? theme.p.s500 : theme.p.s300)
                        .frame(width: 8, height: 8)
                        .offset(x: pop ? cos(angle) * 110 : 0, y: pop ? sin(angle) * 80 : 0)
                        .opacity(pop ? 1 : 0)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    Image(systemName: "figure.walk").font(.system(size: 44)).foregroundStyle(theme.p.s700)
                    Image(systemName: "flag.checkered").font(.system(size: 54)).foregroundStyle(theme.primary)
                }
                .scaleEffect(pop ? 1 : 0.6)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.55)) { pop = true }
        }
    }
}
