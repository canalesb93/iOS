import UIKit

/// Proportions of the native sidebar's drawer and docked column.
enum NativeSidebarLayout {
    static let drawerWidthFraction: CGFloat = 0.8
    static let maximumDrawerWidth: CGFloat = 320
    static let dockedWidth: CGFloat = 320
    /// How much smaller the content card gets when fully open.
    static let contentScaleReduction: CGFloat = 0.1
    /// Matches the screen's own curve, so the card reads as the display shrinking away.
    static let cardCornerRadius: CGFloat = {
        let radius = UIScreen.main.displayCornerRadius
        return radius > 0 ? radius : 44
    }()
    /// Fraction of its width the sidebar trails behind the card while revealing.
    static let sidebarParallax: CGFloat = 0.28
    static let sidebarScaleReduction: CGFloat = 0.06
    static let contentDimming: Double = 0.1
    static let shadowOpacity: Double = 0.28
    static let shadowRadius: CGFloat = 32
}
