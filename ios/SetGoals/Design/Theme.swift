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
        s50 = Color(hex: hex[0]); s100 = Color(hex: hex[1]); s200 = Color(hex: hex[2])
        s300 = Color(hex: hex[3]); s500 = Color(hex: hex[4]); s600 = Color(hex: hex[5])
        s700 = Color(hex: hex[6]); s900 = Color(hex: hex[7]); s950 = Color(hex: hex[8])
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
    var p: SagePalette { SagePalette.table[color] ?? SagePalette.table[.sage]! }

    // Semantic tokens
    var background: Color { p.s50 }
    var foreground: Color { p.s950 }
    var card: Color { .white }
    var cardForeground: Color { p.s950 }
    var primary: Color { p.s600 }
    var primaryForeground: Color { Color(hex: "#FCFCFC") }
    var secondary: Color { p.s100 }
    var muted: Color { p.s100 }
    var mutedForeground: Color { p.s600 }
    var accent: Color { p.s200 }
    var destructive: Color { Color(hex: "#DC2626") }
    /// `--border: oklch(0.18 0.018 145 / 0.06)` == sage-950 @ 6%
    var border: Color { p.s950.opacity(0.06) }
    var ringBorder: Color { Color.black.opacity(0.05) } // ring-1 ring-black/5
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
