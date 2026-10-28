import Shared
import SwiftUI

/// Presses sink slightly and dim, springing back on release — immediate feedback without a highlight that
/// would fight the sliding selection pill.
struct NativeSidebarRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(DesignSystem.Motion.press, value: configuration.isPressed)
    }
}

#Preview {
    Button("Press me") {}
        .buttonStyle(NativeSidebarRowButtonStyle())
}
