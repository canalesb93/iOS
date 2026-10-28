import Shared
import SwiftUI

/// What the sidebar sits on: the grouped background with a soft wash of the frontend's primary colour bleeding
/// in from the top-leading corner, so the drawer picks up the user's theme.
struct NativeSidebarBackdrop: View {
    let accentColor: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            RadialGradient(
                colors: [accentColor.opacity(colorScheme == .dark ? 0.32 : 0.18), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            LinearGradient(
                colors: [.clear, accentColor.opacity(colorScheme == .dark ? 0.08 : 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

#Preview {
    NativeSidebarBackdrop(accentColor: .haPrimary)
        .ignoresSafeArea()
}
