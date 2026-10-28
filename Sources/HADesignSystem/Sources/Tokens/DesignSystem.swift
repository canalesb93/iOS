import Foundation
import SwiftUI

/// The design tokens every component measures itself in: type, spacing, radius, borders.
///
/// Frontend counterpart: the `--ha-space-*`, `--ha-border-radius-*` and typography custom properties
/// the frontend's stylesheets read. Spacing follows the same 4pt scale, so a value transcribed from
/// a frontend rule lands on the same token here.
public enum DesignSystem {
    // TODO: Use HA design system font sizes when ready
    public enum Font {
        /// Large Title (34pt)
        public static let largeTitle: SwiftUICore.Font = .largeTitle
        /// Title (28pt)
        public static let title: SwiftUICore.Font = .title
        /// Title2 (22pt)
        public static let title2: SwiftUICore.Font = .title2
        /// Title3 (20pt)
        public static let title3: SwiftUICore.Font = .title3
        /// Headline (17pt, semibold)
        public static let headline: SwiftUICore.Font = .headline
        /// Body (17pt)
        public static let body: SwiftUICore.Font = .body
        /// Callout (16pt)
        public static let callout: SwiftUICore.Font = .callout
        /// Subheadline (15pt)
        public static let subheadline: SwiftUICore.Font = .subheadline
        /// Footnote (13pt)
        public static let footnote: SwiftUICore.Font = .footnote
        /// Caption (12pt)
        public static let caption: SwiftUICore.Font = .caption
        /// Caption2 (11pt)
        public static let caption2: SwiftUICore.Font = .caption2
        /// Caption3 (10pt)
        public static let caption3: SwiftUICore.Font = .system(size: 10)
    }

    public enum Spaces {
        public static let micro: CGFloat = 2
        public static let half: CGFloat = 4
        public static let one: CGFloat = 8
        /// 10pt. Out of the 4pt scale, like `CornerRadius.oneAndMicro`: the frontend's tile pads and
        /// gaps its icon-and-text row by 10px, and rounding it to 8 or 12 shifts the row height.
        public static let oneAndMicro: CGFloat = 10
        public static let oneAndHalf: CGFloat = 12
        public static let two: CGFloat = 16
        public static let three: CGFloat = 24
        public static let four: CGFloat = 32
        public static let five: CGFloat = 40
        public static let six: CGFloat = 48
        public static let seven: CGFloat = 56
        public static let eight: CGFloat = 64
        public static let nine: CGFloat = 72
        public static let ten: CGFloat = 80
        public static let eleven: CGFloat = 88
        public static let twelve: CGFloat = 96
        public static let thirteen: CGFloat = 104
        public static let fourteen: CGFloat = 112
        public static let fifteen: CGFloat = 120
        public static let sixteen: CGFloat = 128
        public static let seventeen: CGFloat = 136
        public static let eighteen: CGFloat = 144
    }

    public enum CornerRadius {
        public static var half: CGFloat = 4
        public static var one: CGFloat = 8
        public static var two: CGFloat = 16
        public static var three: CGFloat = 24
        public static var four: CGFloat = 32
        public static var five: CGFloat = 40
        public static var six: CGFloat = 48

        // Out of system points
        /// 2pt
        public static var micro: CGFloat = 2
        /// 10pt
        public static var oneAndMicro: CGFloat = 10
        /// 12pt
        public static var oneAndHalf: CGFloat = 12
        /// 18pt
        public static var twoAndMicro: CGFloat = 18
        /// 20pt
        public static var twoAndHalf: CGFloat = 20
    }

    public enum Border {
        public enum Width {
            public static var `default`: CGFloat = 1
        }
    }

    public enum Button {
        public static let minHeight: CGFloat = 48
        public static let maxWidth: CGFloat = 380
    }

    public enum List {
        public static let rowMaxWidth: CGFloat = 380
    }

    /// Metrics of the large controls a more-info dialog leads with, from the frontend's
    /// `state-control-styles.ts` and `state-control-circular-slider-style.ts`.
    public enum StateControl {
        public static let thickness: CGFloat = 130
        public static let length: CGFloat = 320
        public static let cornerRadius: CGFloat = 36
        public static let padding: CGFloat = 6
        public static let iconSize: CGFloat = 24
        public static let dialDiameter: CGFloat = 300
        public static let buttonGroupSpacing: CGFloat = 10
    }

    public enum Animation {
        public static let `default`: SwiftUICore.Animation = .easeInOut(duration: 0.3)
        public static let easeInOutFaster: SwiftUICore.Animation = .easeInOut(duration: 0.1)
        public static let easeInOutSlower: SwiftUICore.Animation = .easeInOut(duration: 0.8)
        public static let easeInOutSlowest: SwiftUICore.Animation = .easeInOut(duration: 1.5)
    }

    /// Physical motion for navigation chrome. Springs are tuned in perceptual terms (duration + bounce)
    /// so they read the same at 60 and 120 Hz, and every one of them can be retargeted mid-flight.
    public enum Motion {
        /// Settle time of the drawer and other large, edge-driven surfaces.
        public static let drawerDuration: TimeInterval = 0.42
        /// Slight overshoot so a flicked drawer feels like it has mass, never so much that it wobbles.
        public static let drawerBounce: Double = 0.12
        public static let drawer: SwiftUICore.Animation = spring(duration: drawerDuration, bounce: drawerBounce)
        /// Small selection changes: a highlight sliding between rows, a badge appearing.
        public static let snappy: SwiftUICore.Animation = spring(duration: 0.3, bounce: 0.18)
        /// Content swaps inside a surface that is already on screen.
        public static let smooth: SwiftUICore.Animation = spring(duration: 0.35, bounce: 0)
        /// Press feedback on custom controls.
        public static let press: SwiftUICore.Animation = spring(duration: 0.2, bounce: 0.3)

        /// A drawer spring that continues the finger's speed. `relativeVelocity` is in "distances per
        /// second": the remaining travel divided into the gesture's velocity.
        public static func drawer(relativeVelocity: Double) -> SwiftUICore.Animation {
            spring(duration: drawerDuration, bounce: drawerBounce, initialVelocity: relativeVelocity)
        }

        /// `Animation.spring(duration:bounce:)` expressed with the iOS 16 stiffness/damping API: a unit-mass
        /// spring whose period is `duration` and whose damping ratio is `1 - bounce`.
        public static func spring(
            duration: TimeInterval,
            bounce: Double,
            initialVelocity: Double = 0
        ) -> SwiftUICore.Animation {
            let stiffness = pow(2 * .pi / duration, 2)
            let damping = 4 * .pi * (1 - bounce) / duration
            return .interpolatingSpring(mass: 1, stiffness: stiffness, damping: damping, initialVelocity: initialVelocity)
        }

        /// Where a flick would come to rest if it decelerated naturally, the way `UIScrollView` projects
        /// a fling. Used to decide which side of a threshold a released drag belongs to.
        public static func project(velocity: CGFloat, decelerationRate: CGFloat = 0.998) -> CGFloat {
            (velocity / 1000) * decelerationRate / (1 - decelerationRate)
        }

        /// iOS-style resistance past a limit: the further you pull, the less it moves.
        public static func rubberBand(_ offset: CGFloat, dimension: CGFloat, coefficient: CGFloat = 0.55) -> CGFloat {
            guard dimension > 0 else { return 0 }
            return (1 - (1 / (offset * coefficient / dimension + 1))) * dimension
        }
    }
}
