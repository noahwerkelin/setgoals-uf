import SwiftUI

/// Port of the shadcn `Tabs` pill list used across the app:
/// `grid grid-cols-N rounded-2xl bg-sage-100 p-1`, active pill = white card.
struct SegmentedTabs<T: Hashable>: View {
    @EnvironmentObject var theme: Theme
    @Binding var selection: T
    let items: [(value: T, label: String)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.value) { item in
                Button { withAnimation(.easeOut(duration: 0.2)) { selection = item.value } } label: {
                    Text(item.label)
                        .font(F.sans(13, selection == item.value ? .semibold : .medium))
                        .foregroundStyle(selection == item.value ? theme.p.s900 : theme.p.s600)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Group {
                                if selection == item.value {
                                    RoundedRectangle(cornerRadius: R.md, style: .continuous)
                                        .fill(theme.card)
                                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(theme.p.s100, in: RoundedRectangle(cornerRadius: R.xl2, style: .continuous))
    }
}

/// `rounded-full bg-sage-100 p-1` two-state pill used by screen-time
/// category permissions ("Always allow" / "Only with screen time").
struct PermissionPills: View {
    @EnvironmentObject var theme: Theme
    @Binding var alwaysAllow: Bool

    var body: some View {
        HStack(spacing: 2) {
            pill(L.t("st.always"), active: alwaysAllow) { alwaysAllow = true }
            pill(L.t("st.earned_only"), active: !alwaysAllow) { alwaysAllow = false }
        }
        .padding(3)
        .background(theme.p.s100, in: Capsule())
    }

    private func pill(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(F.sans(11, .semibold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .foregroundStyle(active ? theme.primaryForeground : theme.p.s600)
                .background(active ? theme.primary : .clear, in: Capsule())
        }
    }
}

/// Simple labelled row used by the settings list.
struct SettingsRow<Trailing: View>: View {
    @EnvironmentObject var theme: Theme
    let icon: String
    let title: String
    var subtitle: String? = nil
    var destructive: Bool = false
    @ViewBuilder var trailing: Trailing
    var action: (() -> Void)? = nil

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 20)
                    .foregroundStyle(destructive ? theme.destructive : theme.p.s700)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(F.sm)
                        .foregroundStyle(destructive ? theme.destructive : theme.p.s900)
                    if let subtitle {
                        Text(subtitle).font(F.xs).foregroundStyle(theme.p.s600)
                    }
                }
                Spacer()
                trailing
            }
            .padding(.horizontal, 12).padding(.vertical, 14)
        }
        .disabled(action == nil)
    }
}

extension SettingsRow where Trailing == Image {
    init(icon: String, title: String, subtitle: String? = nil, destructive: Bool = false,
         action: @escaping () -> Void) {
        self.init(icon: icon, title: title, subtitle: subtitle, destructive: destructive,
                  trailing: { Image(systemName: "chevron.right") }, action: action)
    }
}

/// Slider row (`daily goal`, `steps per 30 min`, `daily cap`).
struct SliderRow: View {
    @EnvironmentObject var theme: Theme
    let title: String
    let valueLabel: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(F.sm).foregroundStyle(theme.p.s900)
                Spacer()
                Text(valueLabel).font(F.sans(14, .semibold)).tabularNums()
                    .foregroundStyle(theme.p.s700)
            }
            Slider(value: $value, in: range, step: step)
                .tint(theme.primary)
        }
    }
}
