import SwiftUI

/// One selection drives both the circle and the inline child management panel.
struct FamilyCircleView: View {
    @EnvironmentObject var theme: Theme
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dynamicTypeSize) private var typeSize
    let children: [ChildRow]
    @Binding var selectedID: UUID?
    let onSelect: (UUID) -> Void

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize || children.count > 5 {
                VStack(spacing: 20) {
                    parentAvatar
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                        ForEach(children) { child in childAvatar(child) }
                    }
                }
            } else {
                GeometryReader { geo in
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    let radius = min(geo.size.width / 2 - 48, 112)
                    ZStack {
                        ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                            let angle = -Double.pi / 2 + Double(index) * 2 * Double.pi / Double(children.count)
                            let point = CGPoint(x: center.x + radius * cos(angle),
                                                y: center.y + radius * sin(angle))
                            Path { path in
                                path.move(to: center)
                                path.addLine(to: point)
                            }
                            .stroke(theme.p.s300, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                            .accessibilityHidden(true)
                            childAvatar(child).position(point)
                        }
                        parentAvatar.position(center)
                    }
                }
                .frame(height: 340)
            }
        }
    }

    private var parentAvatar: some View {
        VStack(spacing: 6) {
            AvatarBubble(avatar: settings.avatar, name: settings.displayName, size: 64)
                .padding(4)
                .overlay(Circle().strokeBorder(theme.primary, lineWidth: 2))
            Text(settings.displayName.isEmpty ? L.t("dashboard.you") : settings.displayName)
                .font(F.sans(12, .semibold)).foregroundStyle(theme.foreground)
                .lineLimit(2).multilineTextAlignment(.center)
        }
        .frame(width: 92)
    }

    private func childAvatar(_ child: ChildRow) -> some View {
        Button { onSelect(child.id) } label: {
            VStack(spacing: 6) {
                AvatarBubble(avatar: child.avatar, name: child.name, size: 52)
                    .padding(4)
                    .overlay(Circle().strokeBorder(selectedID == child.id ? theme.primary : theme.p.s200,
                                                   lineWidth: 2))
                Text(child.name).font(F.sans(12, .medium)).foregroundStyle(theme.foreground)
                    .lineLimit(2).multilineTextAlignment(.center)
            }
            .frame(width: 88)
        }
        .buttonStyle(FlatPress())
        .accessibilityLabel(L.t("dashboard.manage", ["name": child.name]))
        .accessibilityAddTraits(selectedID == child.id ? .isSelected : [])
    }
}