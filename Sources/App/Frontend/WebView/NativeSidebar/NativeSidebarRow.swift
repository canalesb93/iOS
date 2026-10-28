import Shared
import SwiftUI

/// One destination in the sidebar: icon, title and an optional badge, with the selection pill drawn behind it
/// by `NativeSidebarView` so it can slide between rows.
struct NativeSidebarRow: View {
    private enum Constants {
        static let iconSize: CGFloat = 22
        static let height: CGFloat = 48
        static let badgeMinWidth: CGFloat = 22
    }

    let item: MacSidebarItem
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spaces.oneAndHalf) {
                Image(uiImage: item.icon.image(
                    ofSize: .init(width: Constants.iconSize, height: Constants.iconSize),
                    color: .label
                ))
                .renderingMode(.template)
                .foregroundStyle(isSelected ? accentColor : Color.secondary)
                .frame(width: Constants.iconSize + DesignSystem.Spaces.one)
                Text(item.title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.88))
                    .lineLimit(1)
                Spacer(minLength: DesignSystem.Spaces.one)
                if item.badge > 0 {
                    Text(item.badge, format: .number)
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignSystem.Spaces.one)
                        .frame(minWidth: Constants.badgeMinWidth, minHeight: Constants.badgeMinWidth)
                        .background(Capsule().fill(accentColor))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, DesignSystem.Spaces.two)
            .frame(height: Constants.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(NativeSidebarRowButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(DesignSystem.Motion.snappy, value: item.badge)
    }
}

#Preview {
    VStack(spacing: 0) {
        NativeSidebarRow(
            item: .init(id: "home", kind: .panel(path: "/home"), title: "Overview", icon: .material(.viewDashboardIcon)),
            isSelected: true,
            accentColor: .haPrimary,
            action: {}
        )
        NativeSidebarRow(
            item: .init(id: "notifications", kind: .notifications, title: "Notifications", icon: .material(.bellIcon), badge: 3),
            isSelected: false,
            accentColor: .haPrimary,
            action: {}
        )
    }
    .padding()
}
