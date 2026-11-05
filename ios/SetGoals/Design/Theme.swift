import SwiftUI

/// 1:1 port of the web design tokens in `src/styles.css`.
/// The web app defines the palette in oklch; these are the exact sRGB
/// conversions of those same values, so colors match pixel for pixel.
enum ThemeColor: String, CaseIterable, Identifiable {
    case sage, rose, blue, pink, lavender, amber, slate
    var id: String { rawValue }
}

struct SagePalette {
    let s50, s100, s200, s300, s500, s600, s700, s900, s950: Color
    let card, mutedFg, primary: Color

    static let table: [ThemeColor: SagePalette] = [
        .sage: SagePalette(hex: ["#F9FBF7", "#F2F5EF", "#E1E7DD", "#C8D1C2", "#879884", "#6E806C", "#566955", "#263126", "#0D140D"]),
        .rose: SagePalette(hex: ["#FEF9F8", "#FCF0F0", "#F3DFDE", "#E3C6C4", "#B48482", "#A06A66", "#88534E", "#402623", "#1C0D0B"]),
        .blue: SagePalette(hex: ["#F7FBFE", "#EDF5FB", "#D7E7F3", "#B9D1E5", "#7397B5", "#597EA2", "#43668A", "#1E2F41", "#08121D"]),
        .pink: SagePalette(hex: ["#FEF8FB", "#FAF0F4", "#F2DEE7", "#E1C5D1", "#AF8397", "#9A6980", "#825269", "#3D2531", "#1B0C13"]),
        .lavender: SagePalette(hex: ["#FAF9FE", "#F4F2FB", "#E5E2F3", "#CFCAE3", "#948BB4", "#7D729F", "#665B87", "#2F2A40", "#120F1D"]),
        .amber: SagePalette(hex: ["#FCFAF6", "#F8F3E9", "#EFE3D0", "#DECBB0", "#AC8C61", "#977344", "#805B2E", "#3C2A13", "#1A0F03"]),
        .slate: SagePalette(hex: ["#F9FAFC", "#F0F4F7", "#E0E5EB", "#C7CFD7", "#8894A0", "#6F7C89", "#576573", "#262F38", "#0D1218"]),
    ]

    init(hex: [String]) {
        func u(_ i: Int) -> UIColor { UIColor(Color(hex: hex[i])) }
        func mix(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1); b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: 1)
        }
        // Dark mode mirrors the web `.dark` tokens: tinted near-black background,
        // slightly lifted tinted cards, light text, brighter brand primary.
        s50 = .adaptive(light: u(0), dark: u(8))
        s100 = .adaptive(light: u(1), dark: mix(u(8), u(7), 0.75))
        s200 = .adaptive(light: u(2), dark: mix(u(7), u(6), 0.3))
        s300 = .adaptive(light: u(3), dark: mix(u(7), u(6), 0.6))
        card = .adaptive(light: .white, dark: mix(u(8), u(7), 0.55))
        mutedFg = .adaptive(light: u(5), dark: mix(u(4), u(3), 0.5))
        primary = .adaptive(light: u(5), dark: u(4))
        s500 = Color(hex: hex[4]); s600 = Color(hex: hex[5])
        s700 = .adaptive(light: u(6), dark: u(3))
        s900 = .adaptive(light: u(7), dark: u(1))
        s950 = .adaptive(light: u(8), dark: u(0))
    }
}

/// Mirrors the semantic tokens (`--background`, `--card`, `--primary`, ...).
@MainActor
final class Theme: ObservableObject {
    @AppStorage("themeColor") private var stored: String = ThemeColor.sage.rawValue

    var color: ThemeColor {
        get { ThemeColor(rawValue: stored) ?? .sage }
        set { stored = newValue.rawValue; objectWillChange.send() }
    }
    @AppStorage("appearance") private var storedAppearance: String = Appearance.system.rawValue
    var appearance: Appearance {
        get { Appearance(rawValue: storedAppearance) ?? .system }
        set { storedAppearance = newValue.rawValue; objectWillChange.send(); applyAppearance() }
    }
    /// Applies the choice to every window so sheets and dialogs follow too.
    func applyAppearance() {
        let style: UIUserInterfaceStyle = appearance == .light ? .light : appearance == .dark ? .dark : .unspecified
        for scene in UIApplication.shared.connectedScenes {
            (scene as? UIWindowScene)?.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
    }
    var colorScheme: ColorScheme? {
        switch appearance { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }

    var p: SagePalette { SagePalette.table[color] ?? SagePalette.table[.sage]! }

    // Semantic tokens
    var background: Color { p.s50 }
    var foreground: Color { p.s950 }
    var card: Color { p.card }
    var cardForeground: Color { p.s950 }
    var primary: Color { p.primary }
    var primaryForeground: Color { Color(hex: "#FCFCFC") }
    var secondary: Color { p.s100 }
    var muted: Color { p.s100 }
    var mutedForeground: Color { p.mutedFg }
    var accent: Color { p.s200 }
    var destructive: Color { Color(hex: "#DC2626") }
    /// `--border: oklch(0.18 0.018 145 / 0.06)` == sage-950 @ 6%
    var border: Color { Color.adaptive(light: UIColor(red: 0.05, green: 0.08, blue: 0.05, alpha: 0.06), dark: UIColor(white: 1, alpha: 0.08)) }
    var ringBorder: Color { Color.adaptive(light: UIColor(white: 0, alpha: 0.05), dark: UIColor(white: 1, alpha: 0.08)) }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
}

extension Color {
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

extension Color {
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Tailwind radius scale from `--radius: 1rem` (16px).
enum R {
    static let sm: CGFloat = 12
    static let md: CGFloat = 14
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xl2: CGFloat = 24
    static let xl3: CGFloat = 28
    static let full: CGFloat = 9999
}
