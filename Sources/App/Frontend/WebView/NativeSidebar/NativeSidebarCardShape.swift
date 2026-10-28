import SwiftUI

/// A continuous rounded rectangle grown past its frame by `outsets`: the content card is laid out inside the
/// safe area while the web view in it bleeds under the status bar and home indicator, so the card's outline
/// has to follow the bleed rather than the frame.
struct NativeSidebarCardShape: Shape {
    var outsets: EdgeInsets
    var cornerRadius: CGFloat

    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let expanded = CGRect(
            x: rect.minX - outsets.leading,
            y: rect.minY - outsets.top,
            width: rect.width + outsets.leading + outsets.trailing,
            height: rect.height + outsets.top + outsets.bottom
        )
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: expanded)
    }
}

#Preview {
    NativeSidebarCardShape(outsets: .init(top: 20, leading: 0, bottom: 20, trailing: 0), cornerRadius: 40)
        .fill(.blue)
        .padding(60)
}
