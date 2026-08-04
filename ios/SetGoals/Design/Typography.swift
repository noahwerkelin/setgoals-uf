import SwiftUI

/// Tailwind's type scale as used by the web app. Font family is
/// "Albert Sans" (see README for adding the .ttf files to the bundle);
/// falls back to the system font if not present.
enum F {
    static func sans(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        if UIFont(name: "AlbertSans-Regular", size: size) != nil {
            let name: String
            switch weight {
            case .semibold: name = "AlbertSans-SemiBold"
            case .bold: name = "AlbertSans-Bold"
            case .medium: name = "AlbertSans-Medium"
            default: name = "AlbertSans-Regular"
            }
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    static var text10 = sans(10, .medium)          // text-[10px]
    static var text11 = sans(11, .regular)         // text-[11px]
    static var xs = sans(12, .regular)             // text-xs
    static var sm = sans(14, .regular)             // text-sm
    static var base = sans(16, .regular)
    static var lg = sans(18, .regular)             // text-lg
    static var xl2 = sans(24, .semibold)           // text-2xl font-semibold
    static var xl3 = sans(30, .semibold)           // text-3xl
    static var xl4 = sans(36, .semibold)           // text-4xl
}

extension View {
    /// `uppercase tracking-widest text-[10px] font-medium`
    func eyebrow(_ color: Color) -> some View {
        self.font(F.sans(10, .medium))
            .textCase(.uppercase)
            .tracking(1.0)
            .foregroundStyle(color)
    }

    func tabularNums() -> some View { self.monospacedDigit() }
}
